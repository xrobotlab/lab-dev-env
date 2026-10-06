param([Parameter(Mandatory = $true)][string]$TemporaryRoot)
$ErrorActionPreference = 'Stop'
if (-not [IO.Path]::IsPathRooted($TemporaryRoot) -or -not (Test-Path -LiteralPath $TemporaryRoot)) {
    throw '既存の絶対パスの一時ルートを指定してください。'
}
$repositoryRoot = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$source = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'scripts/bootstrap.ps1'), [Text.UTF8Encoding]::new($false))
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors -join "`n") }
# 関数だけを取り込み、bootstrap本体のインストーラー起動・PATH変更・mise実行を避ける。
$ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
    ForEach-Object { . ([ScriptBlock]::Create($_.Extent.Text)) }

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing)
    [IO.File]::WriteAllText($OutFile, 'verified payload')
}
$payload = Join-Path $TemporaryRoot 'expected.txt'
[IO.File]::WriteAllText($payload, 'verified payload')
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $payload).Hash.ToLowerInvariant()
$file = Get-VerifiedDownload 'https://example.invalid/payload' $hash 'download.exe'
Assert-True (Test-Path -LiteralPath $file) 'ハッシュが一致したファイルを返す必要があります。'
$rejected = $false
try { Get-VerifiedDownload 'https://example.invalid/payload' ('0' * 64) 'bad.exe' | Out-Null } catch { $rejected = $true }
Assert-True $rejected 'ハッシュ不一致は導入を停止する必要があります。'
$rejected = $false
try { Get-VerifiedDownload 'http://example.invalid/payload' $hash 'insecure.exe' | Out-Null } catch { $rejected = $true }
Assert-True $rejected 'HTTPのダウンロードは拒否する必要があります。'

function Start-Process {
    param($FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru, $WindowStyle)
    $script:ObservedArguments = $ArgumentList
    Assert-True ($WindowStyle -eq $script:ExpectedWindowStyle) '対話導入の画面表示方式が一致しません。'
    [pscustomobject]@{ ExitCode = $script:InstallerExitCode }
}
$script:InstallerExitCode = 0
$script:ExpectedWindowStyle = 'Hidden'
Invoke-Installer 'archive.exe' '-y -gm2'
Assert-True ($script:ObservedArguments -eq '-y -gm2') 'PortableGitは確認済みの無人展開引数だけを使用する必要があります。'
$script:ExpectedWindowStyle = 'Normal'
Invoke-Installer 'installer.exe' '/currentuser' -Interactive
Assert-True ($script:ObservedArguments -eq '/currentuser') '対話導入ではユーザー単位の引数だけを渡します。'
$script:InstallerExitCode = 1
$rejected = $false
try { Invoke-Installer 'installer.exe' '/currentuser' -Interactive } catch { $rejected = $true }
Assert-True $rejected 'インストーラーの失敗を伝える必要があります。'

$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = $TemporaryRoot
    $script:InstallerExitCode = 0
    $app = [pscustomobject]@{
        installMode = 'interactive'; installDirectory = 'Programs/GIMP 3'; executable = 'bin/gimp-3.2.exe'
        displayNamePattern = 'GIMP*'; version = '3.2.6'; url = 'https://example.invalid/gimp'; sha256 = $hash
        arguments = @('/CURRENTUSER')
    }
    function Get-InstalledApp { param($Pattern) }
    $rejected = $false
    try { Install-GuiApp 'gimp' $app } catch { $rejected = $true }
    Assert-True $rejected '終了コード0でも導入先が未検出なら完了と判定しません。'

    $bin = Join-Path $TemporaryRoot 'Programs/GIMP 3/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $bin 'gimp-3.2.exe'), '検出用の未実行ファイル')
    function Get-InstalledApp { param($Pattern) [pscustomobject]@{ DisplayVersion = '3.2.6.0' } }
    function Invoke-WebRequest { throw '導入済みのGIMPを再ダウンロードしてはいけません。' }
    Install-GuiApp 'gimp' $app
}
finally { $env:LOCALAPPDATA = $oldLocalAppData }
Write-Host 'bootstrap関数検証: PASS（ハッシュ、HTTPS、対話起動、終了コード、未導入、再実行）'
