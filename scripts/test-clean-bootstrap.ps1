param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-BootstrapProcess {
    param(
        [Parameter(Mandatory = $true)][string]$System32,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$LogPrefix
    )
    $stdout = Join-Path $temporaryRoot ($LogPrefix + '.stdout.log')
    $stderr = Join-Path $temporaryRoot ($LogPrefix + '.stderr.log')
    # 対話的な配置入口は隔離fixtureで別途検証し、ここでは従来どおり導入本体を試験する。
    $env:LAB_DEV_ENV_ROOT = $Source
    $command = '$p=Join-Path $env:LAB_DEV_ENV_ROOT ''scripts/bootstrap.ps1''; $c=[IO.File]::ReadAllText($p,[Text.UTF8Encoding]::new($false)); & ([ScriptBlock]::Create($c))'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $process = Start-Process -FilePath (Join-Path $System32 'WindowsPowerShell\v1.0\powershell.exe') `
        -ArgumentList @('-NoProfile', '-EncodedCommand', $encoded) `
        -WorkingDirectory $Source -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    foreach ($log in @($stdout, $stderr)) {
        if (Test-Path -LiteralPath $log) {
            Get-Content -LiteralPath $log -Encoding UTF8 -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Host $_ }
        }
    }
    return $process.ExitCode
}

$originalPath = $env:Path
$originalLocalAppData = $env:LOCALAPPDATA
$originalCleanBootstrap = $env:LAB_DEV_ENV_CLEAN_BOOTSTRAP_CI
$originalRepositoryRoot = $env:LAB_DEV_ENV_ROOT
$originalUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$temporaryBase = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$temporaryRoot = Join-Path $temporaryBase ('lab-dev-env-clean-bootstrap-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $temporaryRoot 'source'
$isolatedLocalAppData = Join-Path $temporaryRoot 'localappdata'

try {
    New-Item -ItemType Directory -Path $source, $isolatedLocalAppData | Out-Null

    # checkout済みの内容を、.gitを持たないDownload ZIP相当の作業ディレクトリへコピーする。
    Get-ChildItem -LiteralPath $RepositoryRoot -Force |
        Where-Object { $_.Name -ne '.git' } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $source -Recurse -Force }
    Remove-Item -LiteralPath (Join-Path $source 'b3\.venv') -Recurse -Force -ErrorAction SilentlyContinue

    Assert-True (-not (Test-Path -LiteralPath (Join-Path $source '.git'))) '.gitを持たない状態で試験する必要があります。'

    $system32 = Join-Path $env:SystemRoot 'System32'
    $powershell = Join-Path $system32 'WindowsPowerShell\v1.0'
    $wbem = Join-Path $system32 'Wbem'
    $minimalPath = @($system32, $powershell, $wbem, $env:SystemRoot) -join ';'

    $env:LOCALAPPDATA = $isolatedLocalAppData
    $env:LAB_DEV_ENV_CLEAN_BOOTSTRAP_CI = '1'
    $env:Path = $minimalPath

    foreach ($command in @('git', 'gh', 'mise', 'python', 'node', 'npm', 'uv', 'just', 'pio')) {
        Assert-True (-not (Get-Command $command -ErrorAction SilentlyContinue)) "試験開始時に $command がPATHから見えてはいけません。"
    }

    Write-Host '--- 1回目: Gitなし・CLIなし相当からbootstrap ---'
    $bootstrapExitCode = Invoke-BootstrapProcess -System32 $system32 -Source $source -LogPrefix 'bootstrap-first'
    if ($bootstrapExitCode -ne 0) { throw "1回目のbootstrapが失敗しました（終了コード: $bootstrapExitCode）。" }

    $portableGit = Join-Path $isolatedLocalAppData 'lab-dev-env\PortableGit\2.56.0.2\cmd'
    $miseBin = Join-Path $isolatedLocalAppData 'mise\bin'
    $miseShims = Join-Path $isolatedLocalAppData 'mise\shims'

    Assert-True (Test-Path -LiteralPath (Join-Path $portableGit 'git.exe')) 'PortableGitがテスト用領域へ導入されていません。'
    Assert-True (Test-Path -LiteralPath (Join-Path $miseBin 'mise.exe')) 'miseがテスト用領域へ導入されていません。'
    Assert-True (Test-Path -LiteralPath (Join-Path $miseShims 'just.exe')) 'mise shimsにjustが作成されていません。'

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $userParts = @($userPath -split ';' | Where-Object { $_ })
    foreach ($expected in @($miseBin, $miseShims, $portableGit)) {
        Assert-True ($userParts -contains $expected) "ユーザーPATHに追加されていません: $expected"
    }

    # 新しい通常ターミナルで見える状態を、Windows標準PATH + bootstrapが保存したユーザーPATHで再現する。
    $env:Path = $minimalPath + ';' + $userPath

    $expectedCommands = @{
        git = '2.56.0';
        gh = '2.102.0';
        mise = '2026.10.3';
        python = '3.13.16';
        node = '24.21.0';
        npm = '11.19.0';
        uv = '0.12.23';
        just = '1.58.0';
        pio = '6.1.19'
    }
    foreach ($entry in $expectedCommands.GetEnumerator()) {
        $resolved = Get-Command $entry.Key -ErrorAction Stop
        $output = & $resolved.Source --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "$($entry.Key) のバージョン取得に失敗しました。" }
        Assert-True ($output -match [regex]::Escape($entry.Value)) "$($entry.Key) が想定版ではありません: $output"
    }

    Push-Location $source
    try {
        Write-Host '--- 新規ターミナル相当でdoctor ---'
        & (Get-Command just -ErrorAction Stop).Source doctor
        if ($LASTEXITCODE -ne 0) { throw "新規ターミナル相当のjust doctorが失敗しました（終了コード: $LASTEXITCODE）。" }

        Write-Host '--- 2回目: 冪等性確認 ---'
        $bootstrapExitCode = Invoke-BootstrapProcess -System32 $system32 -Source $source -LogPrefix 'bootstrap-second'
        if ($bootstrapExitCode -ne 0) { throw "2回目のbootstrapが失敗しました（終了コード: $bootstrapExitCode）。" }

        & (Get-Command just -ErrorAction Stop).Source doctor
        if ($LASTEXITCODE -ne 0) { throw "2回目後のjust doctorが失敗しました（終了コード: $LASTEXITCODE）。" }
    }
    finally { Pop-Location }

    Write-Host 'Windowsクリーンbootstrap E2E: PASS'
}
finally {
    [Environment]::SetEnvironmentVariable('Path', $originalUserPath, 'User')
    $env:Path = $originalPath
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:LAB_DEV_ENV_CLEAN_BOOTSTRAP_CI = $originalCleanBootstrap
    $env:LAB_DEV_ENV_ROOT = $originalRepositoryRoot
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
