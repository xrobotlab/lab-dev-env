$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

function Assert-BootstrapStandardUser {
    param([bool]$IsAdministrator)
    if ($IsAdministrator) {
        throw '管理者として実行しないでください。エクスプローラーで bootstrap.cmd を通常のダブルクリックで開いてください。'
    }
}

function Assert-NoReparsePoint {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "リンクされたパスには自動配置しません: $Path"
    }
}

function Get-BootstrapPlan {
    param([string]$SourceRoot, [string]$UserProfile)
    $source = (Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop).ProviderPath.TrimEnd('\')
    $profileRoot = (Resolve-Path -LiteralPath $UserProfile -ErrorAction Stop).ProviderPath.TrimEnd('\')
    Assert-NoReparsePoint $source
    $parent = Join-Path $profileRoot 'source'
    $target = Join-Path $parent 'lab-dev-env'
    if ($source.Equals($target, [StringComparison]::OrdinalIgnoreCase)) {
        Assert-NoReparsePoint $parent
        return [pscustomobject]@{ Source = $source; Target = $source; Copy = $false; Kind = 'canonical' }
    }
    # .gitはディレクトリだけでなく、worktree用のファイルの場合もある。
    if (Test-Path -LiteralPath (Join-Path $source '.git')) {
        return [pscustomobject]@{ Source = $source; Target = $source; Copy = $false; Kind = 'git' }
    }
    return [pscustomobject]@{ Source = $source; Target = $target; Copy = $true; Kind = 'zip' }
}

function Get-BootstrapInventory {
    param([string]$SourceRoot)
    $manifest = Join-Path $SourceRoot 'config/windows-source-files.txt'
    Assert-NoReparsePoint (Join-Path $SourceRoot 'config')
    Assert-NoReparsePoint $manifest
    $paths = @([IO.File]::ReadAllLines($manifest, [Text.UTF8Encoding]::new($false)) |
        Where-Object { $_ -and -not $_.StartsWith('#') })
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($relative in $paths) {
        # 明示的な配布ファイルだけをコピーする。ワイルドカード、ADS、親参照を拒否する。
        if ($relative -notmatch '^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$' -or
            @($relative.Split('/') | Where-Object { $_ -in @('.', '..', '.git', '.venv', '__pycache__') }).Count -or
            -not $seen.Add($relative)) {
            throw "配布ファイル一覧のパスが不正です: $relative"
        }
        $file = Join-Path $SourceRoot $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "ZIPをすべて展開してから実行してください。必要なファイルがありません: $relative"
        }
        $part = $SourceRoot
        foreach ($component in $relative.Split('/')) {
            $part = Join-Path $part $component
            Assert-NoReparsePoint $part
        }
        [pscustomobject]@{ Relative = $relative; Hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
    }
    foreach ($required in @('bootstrap.cmd', 'scripts/bootstrap-entry.ps1', 'scripts/bootstrap-console.ps1',
            'scripts/bootstrap.ps1', 'config/windows-source-files.txt', 'config/windows-apps.json',
            'mise.toml', 'mise.lock', 'justfile', 'b3/pyproject.toml', 'b3/uv.lock')) {
        if (-not $seen.Contains($required)) { throw "配布ファイル一覧に必要なファイルがありません: $required" }
    }
}

function Copy-BootstrapSource {
    param([string]$SourceRoot, [string]$Target)
    if (Test-Path -LiteralPath $Target) {
        throw "配置先は既に存在します: $Target。上書きしません。既存フォルダー内の bootstrap.cmd を使うか、研究室の担当者へ相談してください。"
    }
    $inventory = @(Get-BootstrapInventory $SourceRoot)
    $parent = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -ErrorAction Stop | Out-Null
    }
    Assert-NoReparsePoint $parent
    $stage = Join-Path $parent ('.lab-dev-env-staging-' + [guid]::NewGuid().ToString('N'))
    $created = $false
    try {
        New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
        $created = $true
        foreach ($entry in $inventory) {
            $copy = Join-Path $stage $entry.Relative
            [IO.Directory]::CreateDirectory((Split-Path -Parent $copy)) | Out-Null
            Copy-Item -LiteralPath (Join-Path $SourceRoot $entry.Relative) -Destination $copy -ErrorAction Stop
            if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ne $entry.Hash) {
                throw "コピーの検証に失敗しました: $($entry.Relative)"
            }
        }
        # 同じ親内で検証済みの一式を公開する。競合で配置先が作られても上書き・混合しない。
        [IO.Directory]::Move($stage, $Target)
        $created = $false
        Write-Host "配置しました: $Target（展開元はそのまま残しています）"
    }
    finally {
        if ($created -and (Test-Path -LiteralPath $stage)) {
            $absoluteStage = [IO.Path]::GetFullPath($stage)
            $absoluteParent = [IO.Path]::GetFullPath($parent).TrimEnd('\')
            if ((Split-Path -Parent $absoluteStage) -ne $absoluteParent -or
                (Split-Path -Leaf $absoluteStage) -notmatch '^\.lab-dev-env-staging-[a-f0-9]{32}$') {
                throw '一時コピーのパスを確認できないため削除を停止しました。'
            }
            Assert-NoReparsePoint $stage
            Remove-Item -LiteralPath $absoluteStage -Recurse -Force
        }
    }
}

function Get-BootstrapMutexName {
    param([string]$Target)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Target.ToLowerInvariant())
        $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
        return 'Local\lab-dev-env-bootstrap-' + $hash
    }
    finally { $sha.Dispose() }
}

function Open-BootstrapConsole {
    param([string]$Target)
    # パスをコードやcmd引数へ直接埋め込まない。空白・日本語・引用符を保つ。
    $root64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Target))
    $command = @'
$ErrorActionPreference = 'Stop'
$env:LAB_DEV_ENV_ROOT = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__ROOT__'))
Set-Location -LiteralPath $env:LAB_DEV_ENV_ROOT
$p = Join-Path $env:LAB_DEV_ENV_ROOT 'scripts/bootstrap-console.ps1'
try {
    $c = [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
    & ([ScriptBlock]::Create($c))
}
catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'エラー表示を控えて担当者へ相談してください。Enterキーで閉じます' | Out-Null
    exit 1
}
'@.Replace('__ROOT__', $root64)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Write-Host 'セットアップ用の別ウィンドウを開きます。処理が終わるまで閉じず、完了またはエラー表示を確認してください。'
    # WorkingDirectoryは[]を拒否するので標準パスで起動し、子内のLiteralPathで移動する。
    $process = Start-Process -FilePath $powershell -ArgumentList "-NoProfile -EncodedCommand $encoded" -WorkingDirectory $env:SystemRoot -WindowStyle Normal -Wait -PassThru
    return $process.ExitCode
}

function Invoke-BootstrapEntry {
    param([string]$SourceRoot, [string]$UserProfile)
    $plan = Get-BootstrapPlan $SourceRoot $UserProfile
    $mutex = [Threading.Mutex]::new($false, (Get-BootstrapMutexName $plan.Target))
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw '同じ配置先のセットアップが別の画面で実行中です。その画面の結果を確認してください。' }
        if ($plan.Copy) { Copy-BootstrapSource $plan.Source $plan.Target }
        if ($plan.Kind -eq 'git') {
            Write-Host "Gitの履歴を保つため、この作業コピーをそのまま使います: $($plan.Target)"
        }
        return Open-BootstrapConsole $plan.Target
    }
    finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

try {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    Assert-BootstrapStandardUser ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    $profilePath = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $code = Invoke-BootstrapEntry $env:LAB_DEV_ENV_ROOT $profilePath
    exit $code
}
catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host '自動配置・セットアップを停止しました。表示を確認してからEnterキーで閉じます' | Out-Null
    exit 1
}
