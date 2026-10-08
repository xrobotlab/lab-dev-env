$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

function Invoke-BootstrapConsole {
    param([string]$RepositoryRoot)
    $code = 1
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($RepositoryRoot.TrimEnd('\').ToLowerInvariant())
        $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    }
    finally { $sha.Dispose() }
    # 入口の画面が閉じられても、実セットアップ側が排他を保持する。
    # 配置用mutexとは別名にし、親子間で取得待ちを循環させない。
    $mutex = [Threading.Mutex]::new($false, ('Local\lab-dev-env-setup-' + $hash))
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw '同じ配置先のセットアップが別の画面で実行中です。その画面の結果を確認してください。' }
        Set-Location -LiteralPath $RepositoryRoot
        $env:LAB_DEV_ENV_ROOT = $RepositoryRoot
        Write-Host "セットアップを開始します: $RepositoryRoot"
        Write-Host '別ウィンドウのインストールが終わるまで、このターミナルは閉じないでください。'
        $command = @'
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $env:LAB_DEV_ENV_ROOT
$p = Join-Path $env:LAB_DEV_ENV_ROOT 'scripts/bootstrap.ps1'
$c = [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
& ([ScriptBlock]::Create($c))
'@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        # 本体のexitでこの結果画面を閉じないよう、同じコンソール内の子プロセスで実行する。
        # WorkingDirectoryは[]を拒否するので標準パスで起動し、子内のLiteralPathで移動する。
        $process = Start-Process -FilePath $powershell -ArgumentList "-NoProfile -EncodedCommand $encoded" -WorkingDirectory $env:SystemRoot -NoNewWindow -Wait -PassThru
        $code = $process.ExitCode
    }
    catch { Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red }
    finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
    if ($code -eq 0) {
        Write-Host '完了。この画面を閉じて構いません。READMEの手動導入と完了確認へ進んでください。' -ForegroundColor Green
    }
    else {
        Write-Host "セットアップは未完了です（終了コード: $code）。このエラー表示を控えてください。" -ForegroundColor Red
        Write-Host "原因を解消したら、この場所の bootstrap.cmd を開いて再実行してください: $RepositoryRoot"
    }
    return $code
}

$code = Invoke-BootstrapConsole $env:LAB_DEV_ENV_ROOT
Read-Host 'Enterキーでこの画面を閉じます' | Out-Null
exit $code
