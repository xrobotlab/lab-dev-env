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

# Native fixtureのみを起動する。mise・GUI導入・ユーザー環境の変更は実行しない。
$nativeFixture = Join-Path $TemporaryRoot "native fixture 日本語's & [1]!.exe"
$compiledFixture = Join-Path $TemporaryRoot 'native-compiled.exe'
Add-Type -OutputAssembly $compiledFixture -OutputType ConsoleApplication -TypeDefinition @'
using System;
public static class BootstrapNativeFixture {
    public static int Main(string[] args) {
        Console.Out.WriteLine("mise 2026.10.3");
        if (args.Length > 1) Console.Out.WriteLine("argument: " + args[1]);
        Console.Error.WriteLine("mise WARN mise version 2026.10.4 available");
        Console.Error.WriteLine("stderr diagnostics retained");
        return Int32.Parse(args[0]);
    }
}
'@
[IO.File]::Move($compiledFixture, $nativeFixture)
$captured = @(Invoke-NativeOutput -FilePath $nativeFixture -Arguments @('0') 6>&1)
$exitCode = $LASTEXITCODE
$stdout = @($captured | Where-Object { $_ -is [string] })
$stderr = ($captured | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } |
    ForEach-Object { $_.ToString() }) -join "`n"
Assert-True ($exitCode -eq 0 -and $stdout.Count -eq 1 -and $stdout[0] -eq 'mise 2026.10.3') '通知があっても終了0のバージョンstdoutを返します。'
Assert-True ($stderr -match 'mise WARN mise version 2026.10.4 available' -and
    $stderr -match 'stderr diagnostics retained') 'stderr通知を消さずに表示します。'
Assert-True ($ErrorActionPreference -eq 'Stop') '呼び出し元のStopを変更しません。'

$captured = @(Invoke-Checked -FilePath $nativeFixture -Arguments @('0') 6>&1)
Assert-True ($LASTEXITCODE -eq 0) '通知+終了0の通常コマンドも完了します。'
Assert-True (($captured -join "`n") -match 'mise WARN') 'checked呼び出しでも通知を保持します。'
$checkedError = ''
try { Invoke-Checked -FilePath $nativeFixture -Arguments @('7') | Out-Null }
catch { $checkedError = $_.Exception.Message }
Assert-True ($checkedError -match '終了コード: 7') '通知+非0では実終了コードを伴って失敗します。'
Assert-True ($ErrorActionPreference -eq 'Stop') '失敗後も呼び出し元のStopを変更しません。'

$captured = @(Invoke-NativeOutput -FilePath $nativeFixture -Arguments @('2') 6>&1)
Assert-True ($LASTEXITCODE -eq 2) 'GUIの手動未完了コード2を0へ変更しません。'
$argument = "C:\repo path 日本語's & [1]!\mise.toml"
$captured = @(Invoke-NativeOutput -FilePath $nativeFixture -Arguments @('0', $argument) 6>&1)
Assert-True (@($captured | Where-Object { $_ -is [string] })[1] -eq ('argument: ' + $argument)) 'Unicode・空白・記号を含む引数を保持します。'
$launchRejected = $false
try { Invoke-NativeOutput -FilePath (Join-Path $TemporaryRoot 'missing-native.exe') -Arguments @('0') | Out-Null }
catch { $launchRejected = $true }
Assert-True $launchRejected '実行ファイルの起動失敗は通知扱いせず停止します。'
Assert-True ($ErrorActionPreference -eq 'Stop') '起動失敗後も呼び出し元のStopを保持します。'
Write-Host 'ネイティブ出力検証: PASS（通知+0、通知+非0、stderr表示、終了2、引数、起動失敗、Stop保持）'
