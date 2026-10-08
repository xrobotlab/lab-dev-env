param([Parameter(Mandatory = $true)][string]$TemporaryRoot)
$ErrorActionPreference = 'Stop'
trap {
    Write-Host $_.Exception.ToString()
    Write-Host $_.ScriptStackTrace
    throw
}
if (-not [IO.Path]::IsPathRooted($TemporaryRoot) -or -not (Test-Path -LiteralPath $TemporaryRoot)) {
    throw '既存の絶対パスの一時ルートを指定してください。'
}
$repositoryRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$source = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'scripts/ensure-portable-shortcut.ps1'), [Text.UTF8Encoding]::new($false))
$tokens = $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors -join [Environment]::NewLine) }
# Load only functions. Never invoke the entry point that selects the real Start Menu.
$ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
    ForEach-Object { . ([ScriptBlock]::Create($_.Extent.Text)) }

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function New-ShortcutFixture {
    param([string]$Name)
    $root = Join-Path $TemporaryRoot ('shortcuts-' + $Name)
    $programs = Join-Path $root 'User Start Menu 日本語 & [1]!'
    $common = Join-Path $root 'Common Start Menu'
    $bin = Join-Path $root "portable package 日本語's & [1]!\nested folder\bin"
    [IO.Directory]::CreateDirectory($programs) | Out-Null
    [IO.Directory]::CreateDirectory($common) | Out-Null
    [IO.Directory]::CreateDirectory($bin) | Out-Null
    $target = Join-Path $bin 'bambu-studio.exe'
    [IO.File]::WriteAllText($target, 'fixture only, never execute')
    return [pscustomobject]@{ Programs = $programs; Common = $common; Target = $target;
        Destination = Join-Path $programs 'lab-dev-env/Bambu Studio.lnk' }
}

$fixture = New-ShortcutFixture 'create'
Write-Host ("fixture target: " + $fixture.Target)
Write-Host ("fixture resolved target: " + (Resolve-LabShortcutTarget $fixture.Target))
Write-Host ("fixture destination: " + $fixture.Destination)
$code = Ensure-LabPortableShortcut $fixture.Programs $fixture.Common $fixture.Target 'Bambu Studio' 'Bambulab.Bambustudio'
Assert-True ($code -eq 0 -and [IO.File]::Exists($fixture.Destination)) 'ユーザー用fixtureだけに作成します。'
$link = Read-LabShortcut $fixture.Destination
Assert-True (Test-LabShortcutTarget $link $fixture.Target) 'Unicode・空白を含む実行先を保持します。'
Assert-True ($link.WorkingDirectory -eq [IO.Path]::GetDirectoryName($fixture.Target)) '実行ファイルの親を作業フォルダーにします。'
Assert-True ($link.Description -eq 'lab-dev-env portable: Bambulab.Bambustudio') '管理元を説明へ記録します。'
$before = (Get-FileHash -Algorithm SHA256 -LiteralPath $fixture.Destination).Hash
$code = Ensure-LabPortableShortcut $fixture.Programs $fixture.Common $fixture.Target 'Bambu Studio' 'Bambulab.Bambustudio'
Assert-True ($code -eq 0 -and (Get-FileHash -Algorithm SHA256 -LiteralPath $fixture.Destination).Hash -eq $before) '再実行で既存リンクを変更しません。'
Assert-True (@(Get-ChildItem -LiteralPath $fixture.Programs -Recurse -Filter '*.lnk').Count -eq 1) '重複しません。'
Remove-Item -LiteralPath $fixture.Destination
$code = Ensure-LabPortableShortcut $fixture.Programs $fixture.Common $fixture.Target 'Bambu Studio' 'Bambulab.Bambustudio'
Assert-True ($code -eq 0 -and [IO.File]::Exists($fixture.Destination)) '消した管理リンクだけを補完します。'
Write-Host 'PASS: actual .lnk / Unicode + spaces / working directory / rerun / missing repair'

foreach ($scope in @('user', 'common')) {
    $vendor = New-ShortcutFixture ('vendor-' + $scope)
    $directory = if ($scope -eq 'user') { $vendor.Programs } else { $vendor.Common }
    $existing = Join-Path $directory 'Vendor launcher.lnk'
    Write-LabShortcut $existing $vendor.Target 'user-owned'
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $existing).Hash
    $code = Ensure-LabPortableShortcut $vendor.Programs $vendor.Common $vendor.Target 'Bambu Studio' 'Bambulab.Bambustudio'
    Assert-True ($code -eq 0 -and -not [IO.File]::Exists($vendor.Destination)) '既存user/vendorリンクを再利用し、新たな重複リンクを作りません。'
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $existing).Hash -eq $hash) '既存リンクを保持します。'
}
Write-Host 'PASS: existing user / common vendor launcher preserved without duplicates'

$junction = New-ShortcutFixture 'junction'
# New-Item -Target in Windows PowerShell treats brackets as wildcards.
$realDirectory = Join-Path $TemporaryRoot 'junction-real'
[IO.Directory]::CreateDirectory($realDirectory) | Out-Null
$junction.Target = Join-Path $realDirectory 'bambu-studio.exe'
[IO.File]::WriteAllText($junction.Target, 'fixture only, never execute')
$alias = Join-Path $TemporaryRoot 'junction alias 日本語'
New-Item -ItemType Junction -Path $alias -Target (Split-Path -Parent $junction.Target) | Out-Null
try {
    $existing = Join-Path $junction.Programs 'Vendor junction launcher.lnk'
    $aliasTarget = Join-Path $alias 'bambu-studio.exe'
    Write-LabShortcut $existing $aliasTarget 'user-owned'
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $existing).Hash
    $link = Read-LabShortcut $existing
    Write-Host ("junction fixture COM TargetPath: " + $link.Target)
    Assert-True (Test-LabShortcutTarget $link (Resolve-LabShortcutTarget $junction.Target)) '祖先junctionも実行先へ正規化します。'
    $code = Ensure-LabPortableShortcut $junction.Programs $junction.Common $junction.Target 'Bambu Studio' 'Bambulab.Bambustudio'
    Assert-True ($code -eq 0 -and -not [IO.File]::Exists($junction.Destination)) 'junction経由vendorリンクも再利用して重複を防ぎます。'
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $existing).Hash -eq $hash) 'junction経由の既存リンクを保持します。'
}
finally { [IO.Directory]::Delete($alias) }
Write-Host 'PASS: ancestor junction vendor launcher preserved without duplicates'

$collision = New-ShortcutFixture 'collision'
[IO.Directory]::CreateDirectory((Split-Path -Parent $collision.Destination)) | Out-Null
[IO.File]::WriteAllText($collision.Destination, 'unrelated user file')
$code = Ensure-LabPortableShortcut $collision.Programs $collision.Common $collision.Target 'Bambu Studio' 'Bambulab.Bambustudio'
Assert-True ($code -eq 2 -and [IO.File]::ReadAllText($collision.Destination) -eq 'unrelated user file') '同名ファイルを上書きしません。'
$folder = New-ShortcutFixture 'folder-collision'
[IO.File]::WriteAllText((Split-Path -Parent $folder.Destination), 'unrelated folder name')
$code = Ensure-LabPortableShortcut $folder.Programs $folder.Common $folder.Target 'Bambu Studio' 'Bambulab.Bambustudio'
Assert-True ($code -eq 2 -and [IO.File]::ReadAllText((Split-Path -Parent $folder.Destination)) -eq 'unrelated folder name') '同名配置先のファイルを保持します。'
Write-Host 'PASS: file / directory-name collision preserved'

# A competing file appearing after creation must not be overwritten.
$race = New-ShortcutFixture 'race'
$originalWriter = (Get-Command Write-LabShortcut).Definition
$originalWriterBlock = [ScriptBlock]::Create($originalWriter)
function Write-LabShortcut {
    param($Path, $Target, $Description)
    & $originalWriterBlock $Path $Target $Description
    [IO.File]::WriteAllText($race.Destination, 'competing user file')
}
try {
    $code = Ensure-LabPortableShortcut $race.Programs $race.Common $race.Target 'Bambu Studio' 'Bambulab.Bambustudio'
    Assert-True ($code -eq 2 -and [IO.File]::ReadAllText($race.Destination) -eq 'competing user file') '公開時の競合を上書きしません。'
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $race.Destination) -Filter '.lab-dev-env-*.lnk').Count -eq 0) '自分の一時リンクだけを片付けます。'
}
finally { . ([ScriptBlock]::Create('function Write-LabShortcut {' + $originalWriter + '}')) }
Write-Host 'PASS: publish race preserves competing user file; temporary link cleaned'

$arduino = New-ShortcutFixture 'arduino'
$arduinoTarget = Join-Path (Split-Path -Parent $arduino.Target) 'Arduino IDE.exe'
[IO.File]::WriteAllText($arduinoTarget, 'fixture only, never execute')
$code = Ensure-LabPortableShortcut $arduino.Programs $arduino.Common $arduinoTarget 'Arduino IDE 2' 'ArduinoSA.IDE.stable'
$arduinoLink = Join-Path $arduino.Programs 'lab-dev-env/Arduino IDE 2.lnk'
Assert-True ($code -eq 0 -and (Test-LabShortcutTarget (Read-LabShortcut $arduinoLink) $arduinoTarget)) 'Arduino IDE portableの空白入りexe名も保持します。'
Write-Host 'PASS: Arduino IDE 2 portable launcher'

Write-Host 'portableショートカット検証: PASS（指定fixtureのみ。実Start Menu・アプリ導入・GUI起動の変更なし）'
