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

Write-Host 'bootstrap関数検証: PASS（PortableGitのハッシュ、HTTPS、起動、終了コード）'
