$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$MiseVersion = "2026.10.3"
$RepoRoot = $env:LAB_DEV_ENV_ROOT.TrimEnd("\")
$MiseRoot = Join-Path $env:LOCALAPPDATA "mise"
$MiseBinDir = Join-Path $MiseRoot "bin"
$MiseExe = Join-Path $MiseBinDir "mise.exe"
$MiseShims = Join-Path $MiseRoot "shims"
$TemporaryRoot = $null
$OldLocation = Get-Location
$IsGitHubCleanBootstrapCi = (
    $env:GITHUB_ACTIONS -eq "true" -and
    $env:RUNNER_ENVIRONMENT -eq "github-hosted" -and
    $env:LAB_DEV_ENV_CLEAN_BOOTSTRAP_CI -eq "1"
)
$SkipGui = $IsGitHubCleanBootstrapCi
$GuiStatus = 0

function Get-VerifiedDownload {
    param([string]$Url, [string]$Sha256, [string]$Name)
    if (-not $Url.StartsWith('https://') -or $Sha256 -notmatch '^[a-f0-9]{64}$') {
        throw "配布URLまたはSHA-256が不正です: $Name"
    }
    $file = Join-Path $TemporaryRoot $Name
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $file
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
    if ($actual -ne $Sha256) { throw "SHA-256が一致しません: $Name ($actual)" }
    return $file
}

function Invoke-Installer {
    param([string]$FilePath, [string]$ArgumentLine, [switch]$Interactive)
    # PowerShell 5.1のArgumentListは連結されるので、引用符を含む完成済みの引数を渡す。
    $windowStyle = if ($Interactive) { 'Normal' } else { 'Hidden' }
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentLine -Wait -PassThru -WindowStyle $windowStyle
    if ($process.ExitCode -ne 0) { throw "インストーラーが失敗しました（終了コード: $($process.ExitCode)）: $FilePath" }
}

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
    $isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $allowCiAdministrator = $IsGitHubCleanBootstrapCi
    if ($isAdministrator -and -not $allowCiAdministrator) {
        throw "管理者として実行しないでください。通常権限のターミナルから bootstrap.cmd を実行してください。"
    }
    if ($isAdministrator -and $allowCiAdministrator) {
        Write-Host "GitHub Actionsのクリーンbootstrap試験として管理者ガードを通過します。"
    }

    $arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    switch ($arch) {
        "x64" {
            $miseSha256 = "af5cad4d381c4e06e9c488af86ad3d3159474ffa7a18e061436a408f7262f23a"
        }
        default {
            throw "Windowsの対応範囲はx64です（現在: $arch）。mise.lockとGUI配布物の対応範囲をREADMEで確認してください。"
        }
    }

    Set-Location -LiteralPath $RepoRoot
    $apps = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $RepoRoot 'config/windows-apps.json') | ConvertFrom-Json
    $TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('lab-dev-env-bootstrap-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $pathDirectories = @($MiseBinDir, $MiseShims)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitDirectory = Join-Path $env:LOCALAPPDATA "lab-dev-env\PortableGit\$($apps.git.version)"
        $gitCmd = Join-Path $gitDirectory 'cmd'
        $gitExe = Join-Path $gitCmd 'git.exe'
        if (-not (Test-Path -LiteralPath $gitExe)) {
            $archive = Get-VerifiedDownload $apps.git.url $apps.git.sha256 'PortableGit.7z.exe'
            $extractedGit = Join-Path $TemporaryRoot 'PortableGit'
            Invoke-Installer $archive '-y -gm2'
            $extractedGitExe = Join-Path $extractedGit 'cmd\git.exe'
            if (-not (Test-Path -LiteralPath $extractedGitExe)) {
                throw "PortableGitの展開結果を確認できません: $extractedGitExe"
            }
            if (Test-Path -LiteralPath $gitDirectory) {
                Remove-Item -LiteralPath $gitDirectory -Recurse -Force
            }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gitDirectory) | Out-Null
            Move-Item -LiteralPath $extractedGit -Destination $gitDirectory
        }
        Invoke-Checked -FilePath $gitExe -Arguments @('--version')
        $env:Path = "$gitCmd;$env:Path"
        $pathDirectories += $gitCmd
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
        $zip = Get-VerifiedDownload $url $miseSha256 $asset
        $extract = Join-Path $TemporaryRoot 'mise'
        Expand-Archive -LiteralPath $zip -DestinationPath $extract
        New-Item -ItemType Directory -Force -Path $MiseBinDir | Out-Null
        Copy-Item -Force (Join-Path $extract "mise\bin\*") $MiseBinDir

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
    $parts = @($parts | Where-Object { $_ -notin $pathDirectories })
    [Environment]::SetEnvironmentVariable("Path", (($pathDirectories + $parts) -join ";"), "User")

    # GUIのキャンセル後にも導入済みCLIを使えるよう、PATH保存後に対話導入する。
    # CIのクリーンbootstrap試験では、対話GUIだけを明示的に省略する。
    if ($SkipGui) {
        Write-Host "GitHub Actionsのクリーンbootstrap試験ではGUIアプリの導入を省略します。"
    } else {
        & $MiseExe exec -- python scripts/gui_tools.py --install-missing
        $GuiStatus = $LASTEXITCODE
        if ($GuiStatus -notin @(0, 2)) { throw "標準GUIの導入に失敗しました。上の表示を確認してください。" }
    }

    Invoke-Checked -FilePath $MiseExe -Arguments @("exec", "--", "just", "doctor")

    Write-Host ""
    if ($SkipGui) {
        Write-Host "CLIセットアップが完了しました。GUIアプリは導入していません。"
    } else {
        Write-Host "CLIセットアップが完了しました。標準GUIの結果は上の表示を確認してください。"
    }
    Write-Host "ターミナルを再起動し、just doctor-full でGUIを含めた準備を確認してください。"
    if ($GuiStatus -eq 2) { exit 2 }
}
catch {
    Write-Host "エラー: セットアップに失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Set-Location -LiteralPath $OldLocation.Path
    if ($TemporaryRoot -and (Test-Path -LiteralPath $TemporaryRoot)) {
        # この実行が作成した絶対パスだけを削除する。
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
