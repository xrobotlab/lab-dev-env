param([Parameter(Mandatory = $true)][string]$TemporaryRoot)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if (-not [IO.Path]::IsPathRooted($TemporaryRoot) -or -not (Test-Path -LiteralPath $TemporaryRoot)) {
    throw '既存の絶対パスの一時ルートを指定してください。'
}
$repositoryRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$utf8 = [Text.UTF8Encoding]::new($false)
$entryPath = Join-Path $repositoryRoot 'scripts/bootstrap-entry.ps1'
$consolePath = Join-Path $repositoryRoot 'scripts/bootstrap-console.ps1'
$entryText = [IO.File]::ReadAllText($entryPath, $utf8)
$consoleText = [IO.File]::ReadAllText($consolePath, $utf8)
$tokens = $null; $errors = $null
foreach ($file in @($entryPath, $consolePath, (Join-Path $repositoryRoot 'scripts/bootstrap.ps1'))) {
    $text = [IO.File]::ReadAllText($file, $utf8)
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors -join [Environment]::NewLine) }
    # 関数定義だけをロードする。実ユーザー領域の配置・導入本体・画面は実行しない。
    $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
        ForEach-Object { . ([ScriptBlock]::Create($_.Extent.Text)) }
}
function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Assert-Rejected {
    param([scriptblock]$Action, [string]$Pattern)
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True ($message -match $Pattern) "必要な拒否を確認できません: $Pattern / $message"
}
function New-Fixture {
    param([string]$Name)
    $case = Join-Path $TemporaryRoot $Name
    $profileRoot = Join-Path $case "User Profile 日本語's & (測定) [1]!"
    $source = Join-Path $case 'Downloads/outer ZIP/lab-dev-env-main'
    [IO.Directory]::CreateDirectory($profileRoot) | Out-Null
    [IO.Directory]::CreateDirectory($source) | Out-Null
    $paths = [IO.File]::ReadAllLines((Join-Path $repositoryRoot 'config/windows-source-files.txt'), $utf8) |
        Where-Object { $_ -and -not $_.StartsWith('#') }
    foreach ($relative in $paths) {
        $copy = Join-Path $source $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $copy)) | Out-Null
        Microsoft.PowerShell.Management\Copy-Item -LiteralPath (Join-Path $repositoryRoot $relative) -Destination $copy
    }
    # redirected hostのRead-Hostはpromptを出さないため、fixtureだけ対話待機を置き換える。
    $pauseDouble = "function Read-Host { param([string]"+'$Prompt'+") Write-Host "+'$Prompt'+"; return '' }"+[Environment]::NewLine
    [IO.File]::WriteAllText((Join-Path $source 'scripts/bootstrap-console.ps1'), $pauseDouble + $consoleText, $utf8)
    # 導入本体を無害なプローブに置き換える。PATH/レジストリ/ネットワークは変更しない。
    $probe = @'
[IO.File]::AppendAllText((Join-Path $env:LAB_DEV_ENV_ROOT 'probe.txt'), "called" + [Environment]::NewLine)
[IO.File]::WriteAllText((Join-Path $env:LAB_DEV_ENV_ROOT 'location.txt'), (Get-Location).Path, [Text.UTF8Encoding]::new($false))
Write-Host 'fixture engine result'
exit __CODE__
'@
    [IO.File]::WriteAllText((Join-Path $source 'scripts/bootstrap.ps1'), $probe.Replace('__CODE__', '0'), $utf8)
    [IO.File]::WriteAllText((Join-Path $source '.env'), 'private user data', $utf8)
    [IO.File]::WriteAllText((Join-Path $source 'mise.local.toml'), 'private settings', $utf8)
    [IO.File]::WriteAllText((Join-Path $source 'README.md.bak'), 'backup', $utf8)
    [IO.Directory]::CreateDirectory((Join-Path $source 'b3/.venv')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $source 'b3/.venv/private.txt'), 'cache', $utf8)
    return [pscustomobject]@{ Source = $source; Profile = $profileRoot; Target = (Join-Path $profileRoot 'source/lab-dev-env'); Probe = $probe }
}
function Invoke-HiddenFixture {
    param([string]$Arguments, [string]$Directory)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $start.Arguments = $Arguments
    $start.WorkingDirectory = $Directory
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $utf8; $start.StandardErrorEncoding = $utf8
    $process = [Diagnostics.Process]::Start($start)
    $process.StandardInput.WriteLine('') # 完了確認のEnterだけ。インストーラーはfixtureで存在しない。
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw '隔離プローブのタイムアウト'
    }
    $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
    $process.Dispose()
    return $result
}
$script:LaunchCount = 0
function Start-Process {
    param($FilePath, $ArgumentList, $WorkingDirectory, $WindowStyle, [switch]$Wait, [switch]$PassThru)
    Assert-True ($WindowStyle -eq 'Normal' -and $Wait -and $PassThru) '通常の結果画面を待機する必要があります。'
    Assert-True ($ArgumentList -notmatch 'RunAs|ExecutionPolicy|bootstrap\.cmd') '昇格・ポリシー変更・入口再帰は禁止です。'
    $script:CapturedArguments = $ArgumentList
    if ($script:CaptureOnly) { return [pscustomobject]@{ ExitCode = 0 } }
    $script:LaunchCount++
    $script:LastConsole = Invoke-HiddenFixture $ArgumentList $originalLocation
    return $script:LastConsole
}
$originalLocation = (Get-Location).Path
$originalRoot = $env:LAB_DEV_ENV_ROOT
try {
    Assert-BootstrapStandardUser $false
    Assert-Rejected { Assert-BootstrapStandardUser $true } '管理者として実行しない'
    Write-Host 'PASS: elevated entry rejected; standard user accepted'
    $fixture = New-Fixture 'fresh'
    $snapshot = (Get-FileHash -LiteralPath (Join-Path $fixture.Source 'README.md')).Hash
    $status = Invoke-BootstrapEntry $fixture.Source $fixture.Profile
    Assert-True ($status -eq 0 -and $script:LaunchCount -eq 1) "初回は一度だけセットアップします。status=$status launches=$script:LaunchCount output=$($script:LastConsole.Output)"
    Assert-True (Test-Path -LiteralPath (Join-Path $fixture.Source '.env')) '展開元は残す必要があります。'
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $fixture.Source 'README.md')).Hash -eq $snapshot) '展開元を書き換えてはいけません。'
    foreach ($private in @('.env', 'mise.local.toml', 'README.md.bak', 'b3/.venv')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixture.Target $private))) "ユーザー状態をコピーしてはいけません: $private"
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $fixture.Target '.mise/locks/pypi-platformio/6.1.19/uv.lock')) '必要な隠しlockを残します。'
    Assert-True ([IO.File]::ReadAllText((Join-Path $fixture.Target 'location.txt'), $utf8) -eq $fixture.Target) '空白・日本語・特殊文字を含む配置先で実行します。'
    Assert-True ($script:LastConsole.Output.Contains('完了。この画面を閉じて構いません。')) '成功したときだけ閉じてよいと伝えます。'
    Assert-True ($script:LastConsole.Output.IndexOf('閉じないでください') -lt $script:LastConsole.Output.IndexOf('fixture engine result')) '待機案内は本体実行前に出します。'
    Assert-True (([IO.File]::ReadAllLines((Join-Path $fixture.Target 'probe.txt'))).Count -eq 1) '再帰起動は禁止です。'
    Write-Host 'PASS: fresh copy / source intact / exclusions / hidden locks / nested ZIP / Unicode quoting'

    $script:LaunchCount = 0
    Assert-Rejected { Invoke-BootstrapEntry $fixture.Source $fixture.Profile } '配置先は既に存在'
    Assert-True ($script:LaunchCount -eq 0) '既存配置先ではセットアップを開始しません。'
    $status = Invoke-BootstrapEntry $fixture.Target $fixture.Profile
    Assert-True ($status -eq 0 -and $script:LaunchCount -eq 1) '配置先の再実行ではコピーせず一度だけ実行します。'
    Assert-True (([IO.File]::ReadAllLines((Join-Path $fixture.Target 'probe.txt'))).Count -eq 2) '配置先からの再実行回数が不正です。'
    foreach ($kind in @('directory', 'file')) {
        $collision = New-Fixture ("collision-" + $kind)
        [IO.Directory]::CreateDirectory((Split-Path -Parent $collision.Target)) | Out-Null
        if ($kind -eq 'directory') { [IO.Directory]::CreateDirectory($collision.Target) | Out-Null }
        else { [IO.File]::WriteAllText($collision.Target, 'user data', $utf8) }
        Assert-Rejected { Invoke-BootstrapEntry $collision.Source $collision.Profile } '配置先は既に存在'
        if ($kind -eq 'file') { Assert-True ([IO.File]::ReadAllText($collision.Target) -eq 'user data') '衝突したファイルを保持します。' }
    }
    Write-Host 'PASS: collision fail closed / canonical rerun'

    foreach ($gitKind in @('directory', 'file')) {
        $git = New-Fixture ("git-" + $gitKind)
        $marker = Join-Path $git.Source '.git'
        if ($gitKind -eq 'directory') { [IO.Directory]::CreateDirectory($marker) | Out-Null }
        else { [IO.File]::WriteAllText($marker, 'gitdir: history', $utf8) }
        $status = Invoke-BootstrapEntry $git.Source $git.Profile
        Assert-True ($status -eq 0 -and (Test-Path -LiteralPath $marker)) 'Git作業コピーの履歴を保ちます。'
        Assert-True (-not (Test-Path -LiteralPath $git.Target)) 'Git作業コピーは複製・移動しません。'
    }
    Write-Host 'PASS: git checkout and worktree preserved'

    foreach ($failure in @('throw', 'corrupt', 'race')) {
        $broken = New-Fixture ("copy-" + $failure)
        $script:CopyNumber = 0; $script:CopyFailure = $failure; $script:RaceTarget = $broken.Target
        function Copy-Item {
            param($LiteralPath, $Destination, $ErrorAction)
            $script:CopyNumber++
            if ($script:CopyFailure -eq 'throw' -and $script:CopyNumber -eq 2) { throw 'fixture partial copy failure' }
            Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -ErrorAction Stop
            if ($script:CopyNumber -eq 1) {
                if ($script:CopyFailure -eq 'corrupt') { [IO.File]::AppendAllText($Destination, 'corrupt') }
                if ($script:CopyFailure -eq 'race') { [IO.Directory]::CreateDirectory($script:RaceTarget) | Out-Null; [IO.File]::WriteAllText((Join-Path $script:RaceTarget 'keep.txt'), 'user data') }
            }
        }
        try { Assert-Rejected { Copy-BootstrapSource $broken.Source $broken.Target } 'fixture|検証|存在|exist' }
        finally { Remove-Item Function:\Copy-Item }
        Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $broken.Target) -Force | Where-Object Name -like '.lab-dev-env-staging-*').Count -eq 0) '部分コピーだけを片付けます。'
        if ($failure -eq 'race') { Assert-True ([IO.File]::ReadAllText((Join-Path $broken.Target 'keep.txt')) -eq 'user data') '競合相手の配置先を保持します。' }
        else { Assert-True (-not (Test-Path -LiteralPath $broken.Target)) '部分コピーを配置先へ公開しません。' }
        Assert-True (Test-Path -LiteralPath $broken.Source) '失敗時も展開元を保持します。'
    }
    Write-Host 'PASS: partial failure / hash mismatch / publish race rollback'

    $missing = New-Fixture 'missing'
    Remove-Item -LiteralPath (Join-Path $missing.Source 'b3/uv.lock')
    Assert-Rejected { Copy-BootstrapSource $missing.Source $missing.Target } '必要なファイル'
    Assert-True (-not (Test-Path -LiteralPath (Split-Path -Parent $missing.Target))) '不完全ZIPは配置前に拒否します。'
    $unsafe = New-Fixture 'unsafe'
    [IO.File]::AppendAllText((Join-Path $unsafe.Source 'config/windows-source-files.txt'), '../private.txt' + [Environment]::NewLine)
    Assert-Rejected { Copy-BootstrapSource $unsafe.Source $unsafe.Target } 'パスが不正'
    Write-Host 'PASS: incomplete ZIP / traversal rejected before placement'

    foreach ($engineCode in @(2, 7, 23)) {
        $failed = New-Fixture ("exit-" + $engineCode)
        [IO.File]::WriteAllText((Join-Path $failed.Source 'scripts/bootstrap.ps1'), $failed.Probe.Replace('__CODE__', [string]$engineCode), $utf8)
        $status = Invoke-BootstrapEntry $failed.Source $failed.Profile
        Assert-True ($status -eq $engineCode) '導入本体の終了コードを保持します。'
        Assert-True ($script:LastConsole.Output.Contains('セットアップは未完了') -and -not $script:LastConsole.Output.Contains('完了。この画面を閉じて構いません。')) 'キャンセル・失敗を成功表示にしません。'
        Assert-True ($script:LastConsole.Output.Contains('Enterキーでこの画面を閉じます')) '失敗画面を即座に閉じません。'
    }
    Write-Host 'PASS: cancel and failure codes / readable result / retry guidance'


    # 本物のCMD入口を、無害なentryに差し替えたfixtureで実行する。
    $cmdCase = New-Fixture 'cmd 日本語 & [1]!'
    $cmdProbe = @'
[IO.File]::WriteAllText((Join-Path $env:LAB_DEV_ENV_ROOT 'cmd-root.txt'), $env:LAB_DEV_ENV_ROOT, [Text.UTF8Encoding]::new($false))
exit 23
'@
    [IO.File]::WriteAllText((Join-Path $cmdCase.Source 'scripts/bootstrap-entry.ps1'), $cmdProbe, $utf8)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $env:SystemRoot 'System32/cmd.exe'
    $start.Arguments = '/d /v:on /c bootstrap.cmd'
    $start.WorkingDirectory = $cmdCase.Source
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        Assert-True ($process.WaitForExit(20000) -and $process.ExitCode -eq 23) 'CMDはentryの終了コードを保持します。'
        Assert-True ([IO.File]::ReadAllText((Join-Path $cmdCase.Source 'cmd-root.txt'), $utf8).TrimEnd('\') -eq $cmdCase.Source) 'CMD遅延展開・Unicode・記号パスを保持します。'
    }
    finally { $process.Dispose() }
    Write-Host 'PASS: actual CMD / delayed expansion / special source path / exit status'

    # 配置先の親がjunctionなら、外部の既存フォルダーに書き込まない。
    $junctionCase = New-Fixture 'junction'
    $external = Join-Path $TemporaryRoot 'junction-target'
    [IO.Directory]::CreateDirectory($external) | Out-Null
    [IO.File]::WriteAllText((Join-Path $external 'keep.txt'), 'user data')
    $junction = Split-Path -Parent $junctionCase.Target
    New-Item -ItemType Junction -Path $junction -Target $external | Out-Null
    try {
        Assert-Rejected { Copy-BootstrapSource $junctionCase.Source $junctionCase.Target } 'リンク'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $external 'lab-dev-env'))) 'junction先へコピーしません。'
        Assert-True ([IO.File]::ReadAllText((Join-Path $external 'keep.txt')) -eq 'user data') '既存データを保持します。'
    }
    finally { [IO.Directory]::Delete($junction) }
    Write-Host 'PASS: junction destination rejected'

    # 結果画面を所有する子の排他は、入口の親が終了しても存続する。
    $mutexCase = New-Fixture 'parent-exit'
    Copy-BootstrapSource $mutexCase.Source $mutexCase.Target
    $eventId = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\lab-entry-ready-' + $eventId
    $releaseName = 'Local\lab-entry-release-' + $eventId
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $blockedProbe = @'
[IO.File]::AppendAllText((Join-Path $env:LAB_DEV_ENV_ROOT 'probe.txt'), "called" + [Environment]::NewLine)
$ready = [Threading.EventWaitHandle]::OpenExisting('__READY__')
$release = [Threading.EventWaitHandle]::OpenExisting('__RELEASE__')
$ready.Set() | Out-Null
if (-not $release.WaitOne(30000)) { exit 9 }
exit 0
'@.Replace('__READY__', $readyName).Replace('__RELEASE__', $releaseName)
    [IO.File]::WriteAllText((Join-Path $mutexCase.Target 'scripts/bootstrap.ps1'), $blockedProbe, $utf8)
    $script:CaptureOnly = $true
    try { Open-BootstrapConsole $mutexCase.Target | Out-Null }
    finally { $script:CaptureOnly = $false }
    $consoleEncoded = $script:CapturedArguments.Split(' ')[-1]
    $root64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($mutexCase.Target))
    $detachingParent = @'
$root = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__ROOT__'))
$ps = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$child = Start-Process -FilePath $ps -ArgumentList '-NoProfile -EncodedCommand __CONSOLE__' -WorkingDirectory $env:SystemRoot -WindowStyle Hidden -PassThru
[IO.File]::WriteAllText((Join-Path $root 'child-pid.txt'), [string]$child.Id)
exit 0
'@.Replace('__ROOT__', $root64).Replace('__CONSOLE__', $consoleEncoded)
    $parentEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($detachingParent))
    $powershellExe = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $childProcess = $null
    try {
        # WaitForExitはこの親だけを待つ。子のfixtureはreleaseイベントまで実行中。
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $powershellExe; $start.Arguments = "-NoProfile -EncodedCommand $parentEncoded"
        $start.UseShellExecute = $false; $start.CreateNoWindow = $true
        $parentProcess = [Diagnostics.Process]::Start($start)
        Assert-True ($parentProcess.WaitForExit(20000) -and $parentProcess.ExitCode -eq 0) '入口の親を終了させます。'
        $parentProcess.Dispose()
        Assert-True ($ready.WaitOne(20000)) '子が実セットアップの排他を取得している必要があります。'
        $childProcess = [Diagnostics.Process]::GetProcessById([int][IO.File]::ReadAllText((Join-Path $mutexCase.Target 'child-pid.txt')))
        Assert-True (-not $childProcess.HasExited) '親終了後も子が実行中のfixtureです。'
        $status = Invoke-BootstrapEntry $mutexCase.Target $mutexCase.Profile
        Assert-True ($status -ne 0 -and $script:LastConsole.Output.Contains('実行中')) '親終了後も二重セットアップを拒否します。'
        Assert-True (([IO.File]::ReadAllLines((Join-Path $mutexCase.Target 'probe.txt'))).Count -eq 1) '二重起動では導入本体を実行しません。'
    }
    finally {
        $release.Set() | Out-Null
        if ($childProcess) { Assert-True ($childProcess.WaitForExit(20000)) '子fixtureを確実に終了します。'; $childProcess.Dispose() }
        $ready.Dispose(); $release.Dispose()
    }
    Write-Host 'PASS: worker mutex survives parent exit / duplicate engine rejected'

    # インストーラーが子を起動して先に終了する場合も、実際のStart-Process -Waitで待つ。
    $eventId = [guid]::NewGuid().ToString('N')
    $treeReadyName = 'Local\lab-tree-ready-' + $eventId
    $treeReleaseName = 'Local\lab-tree-release-' + $eventId
    $treeDoneName = 'Local\lab-tree-done-' + $eventId
    $treeReady = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $treeReadyName)
    $treeRelease = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $treeReleaseName)
    $treeDone = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $treeDoneName)
    $descendant = @'
$ready = [Threading.EventWaitHandle]::OpenExisting('__READY__')
$release = [Threading.EventWaitHandle]::OpenExisting('__RELEASE__')
$ready.Set() | Out-Null
if (-not $release.WaitOne(30000)) { exit 9 }
exit 0
'@.Replace('__READY__', $treeReadyName).Replace('__RELEASE__', $treeReleaseName)
    $descendant64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($descendant))
    $installer = @'
$ps = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
Start-Process -FilePath $ps -ArgumentList '-NoProfile -EncodedCommand __CHILD__' -WorkingDirectory $env:SystemRoot -WindowStyle Hidden | Out-Null
exit 0
'@.Replace('__CHILD__', $descendant64)
    $installer64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($installer))
    $driver = (Get-Command Invoke-Installer).Definition
    $driver = "function Invoke-Installer {" + $driver + "}" + [Environment]::NewLine +
        '$ErrorActionPreference = ''Stop''; $ps = Join-Path $env:SystemRoot ''System32/WindowsPowerShell/v1.0/powershell.exe'';' +
        " Invoke-Installer " + '$ps ' + "'-NoProfile -EncodedCommand $installer64'; " +
        "[Threading.EventWaitHandle]::OpenExisting('$treeDoneName').Set() | Out-Null; exit 0"
    $driver64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($driver))
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $powershellExe; $start.Arguments = "-NoProfile -EncodedCommand $driver64"
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $driverProcess = [Diagnostics.Process]::Start($start)
    try {
        Assert-True ($treeReady.WaitOne(20000)) 'インストーラーの子が待機するfixtureです。'
        Assert-True (-not $treeDone.WaitOne(0) -and -not $driverProcess.HasExited) '子が実行中ならインストーラー完了として先へ進みません。'
        $treeRelease.Set() | Out-Null
        Assert-True ($driverProcess.WaitForExit(20000) -and $driverProcess.ExitCode -eq 0 -and $treeDone.WaitOne(0)) '子が終了してからセットアップを続けます。'
    }
    finally {
        $treeRelease.Set() | Out-Null
        $driverProcess.WaitForExit(20000) | Out-Null; $driverProcess.Dispose()
        $treeReady.Dispose(); $treeRelease.Dispose(); $treeDone.Dispose()
    }
    Write-Host 'PASS: actual Start-Process -Wait includes installer descendants; no arbitrary sleep'


}
finally {
    Set-Location -LiteralPath $originalLocation
    $env:LAB_DEV_ENV_ROOT = $originalRoot
}
Write-Host 'Windows自動配置・結果画面検証: PASS（fixtureのみ、導入・実画面起動なし）'
