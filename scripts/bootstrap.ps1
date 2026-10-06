$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$MiseVersion = "2026.10.3"
$RepoRoot = $env:LAB_DEV_ENV_ROOT.TrimEnd("\")
$MiseRoot = Join-Path $env:LOCALAPPDATA "mise"
$MiseBinDir = Join-Path $MiseRoot "bin"
$MiseExe = Join-Path $MiseBinDir "mise.exe"
$MiseShims = Join-Path $MiseRoot "shims"

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "コマンドの実行に失敗しました（終了コード: $LASTEXITCODE）: $FilePath $($Arguments -join ' ')"
    }
}

try {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "管理者として実行しないでください。通常権限のターミナルから bootstrap.cmd を実行してください。"
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Gitが見つかりません。このリポジトリの取得と実行にはGitが必要です。"
    }

    $arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    switch ($arch) {
        "x64" {
            $miseSha256 = "af5cad4d381c4e06e9c488af86ad3d3159474ffa7a18e061436a408f7262f23a"
        }
        "arm64" {
            $miseSha256 = "378cad931510d02a840ece40bde9c7a69fc8d59f6902a24579e75a55bd19f279"
        }
        default {
            throw "未対応のWindowsアーキテクチャです: $arch"
        }
    }

    $needMise = $true
    if (Test-Path $MiseExe) {
        $versionOutput = & $MiseExe --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $versionOutput -match [regex]::Escape($MiseVersion)) {
            $needMise = $false
        }
    }

    if ($needMise) {
        Write-Host "mise $MiseVersion をユーザー領域にインストールしています..."

        $asset = "mise-v$MiseVersion-windows-$arch.zip"
        $url = "https://github.com/jdx/mise/releases/download/v$MiseVersion/$asset"
        $zip = Join-Path $env:TEMP $asset
        $extract = Join-Path $env:TEMP "mise-bootstrap-$MiseVersion"

        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $url -OutFile $zip

        $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
        if ($actual -ne $miseSha256) {
            throw "miseアーカイブのSHA-256が一致しません: $actual"
        }

        Remove-Item -Recurse -Force $extract -ErrorAction SilentlyContinue
        Expand-Archive -Path $zip -DestinationPath $extract -Force
        New-Item -ItemType Directory -Force -Path $MiseBinDir | Out-Null
        Copy-Item -Force (Join-Path $extract "mise\bin\*") $MiseBinDir

        Remove-Item -Recurse -Force $extract
        Remove-Item -Force $zip
    }

    $env:Path = "$MiseBinDir;$MiseShims;$env:Path"

    Invoke-Checked -FilePath $MiseExe -Arguments @("trust", (Join-Path $RepoRoot "mise.toml"))

    # PlatformIOで使用するpypiバックエンドが依存するため、Pythonとuvを先に導入する。
    Invoke-Checked -FilePath $MiseExe -Arguments @("install", "--locked", "python", "uv")
    Invoke-Checked -FilePath $MiseExe -Arguments @("install", "--locked")
    Invoke-Checked -FilePath $MiseExe -Arguments @("exec", "--", "uv", "sync", "--locked", "--project", "b3")

    # mise本体とshimを現在のユーザーのPATHへ永続的に追加する。管理者権限は不要。
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($userPath -split ";" | Where-Object { $_ })
    $parts = @($parts | Where-Object { $_ -ne $MiseBinDir -and $_ -ne $MiseShims })
    [Environment]::SetEnvironmentVariable("Path", (($MiseBinDir, $MiseShims) + $parts -join ";"), "User")

    Invoke-Checked -FilePath $MiseExe -Arguments @("exec", "--", "just", "doctor")

    Write-Host ""
    Write-Host "セットアップが完了しました。ターミナルを再起動してから just doctor を実行してください。"
}
catch {
    Write-Host "エラー: セットアップに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
