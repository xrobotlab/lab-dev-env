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

function Get-InstalledApp {
    param([string]$Pattern)
    foreach ($key in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Pattern }
    }
}

function Install-GuiApp {
    param([string]$Name, $App)
    if ($App.installMode -ne 'interactive') { throw "$Name の導入方式は対話式にしてください。" }
    $directory = Join-Path $env:LOCALAPPDATA $App.installDirectory
    $executable = Join-Path $directory $App.executable
    $installed = @(Get-InstalledApp $App.displayNamePattern)
    # GIMPのDisplayVersionは3.2.6.0のように末尾のrevision 0を含む。
    $versionPattern = '^' + [regex]::Escape($App.version) + '(?:\.0)?$'
    $matching = @($installed | Where-Object { $_.DisplayVersion -match $versionPattern })
    if ((Test-Path -LiteralPath $executable) -and $matching.Count -gt 0) {
        Write-Host "$Name $($App.version) は導入済みです。"
        return
    }
    if ($installed.Count -gt 0 -and -not (Test-Path -LiteralPath $executable)) {
        Write-Host "[手動] $Name は別の場所に導入されています。READMEの手順で既存環境を確認してください。"
        return
    }
    $installer = Get-VerifiedDownload $App.url $App.sha256 "$Name-setup.exe"
    Write-Host "$Name の対話インストーラーを起動します。ユーザー単位の導入を選び、画面の手順に従ってください。"
    Write-Host "管理者権限を要求された場合はキャンセルし、研究室の管理者に相談してください。"
    Invoke-Installer $installer ($App.arguments -join ' ') -Interactive
    # 対話画面で別の場所を選んだ場合も、登録されたインストール先から確認する。
    $candidates = @($executable)
    foreach ($entry in @(Get-InstalledApp $App.displayNamePattern)) {
        if ($entry.InstallLocation) { $candidates += Join-Path $entry.InstallLocation $App.executable }
        $icon = ($entry.DisplayIcon -replace ',\s*-?\d+$', '').Trim('"')
        if ($icon -and $icon.EndsWith('.exe') -and (Split-Path -Leaf $icon) -notmatch 'unins|setup') {
            $candidates += [Environment]::ExpandEnvironmentVariables($icon)
        }
    }
    if (-not @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count) {
        throw "$Name の実行ファイルを確認できません。導入のキャンセルや保存先を確認してください。"
    }
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
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "管理者として実行しないでください。通常権限のターミナルから bootstrap.cmd を実行してください。"
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
            $escapedDirectory = $gitDirectory.Replace('\', '\\')
            Invoke-Installer $archive ('-y -gm2 -InstallPath="' + $escapedDirectory + '"')
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
    Install-GuiApp 'gimp' $apps.gimp
    Install-GuiApp 'kicad' $apps.kicad

    Invoke-Checked -FilePath $MiseExe -Arguments @("exec", "--", "just", "doctor")

    Write-Host ""
    Write-Host "CLIと対話式GUIセットアップが完了しました。DYNAMIXEL Wizard 2 と必要なDocker/ドライバはREADMEの手動手順を確認してください。"
    Write-Host "ターミナルを再起動し、just doctor-full でGUIを含めた準備を確認してください。"
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
