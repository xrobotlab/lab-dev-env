param([Parameter(Mandatory = $true)][string]$RequestBase64)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Read-LabShortcut {
    param([string]$Path)
    $shell = $link = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($Path)
        return [pscustomobject]@{ Target = $link.TargetPath; Arguments = $link.Arguments;
            WorkingDirectory = $link.WorkingDirectory; Description = $link.Description }
    }
    finally {
        if ($link) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) | Out-Null }
        if ($shell) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null }
    }
}

function Write-LabShortcut {
    param([string]$Path, [string]$Target, [string]$Description)
    $shell = $link = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($Path)
        $link.TargetPath = $Target
        $link.Arguments = ''
        $link.WorkingDirectory = [IO.Path]::GetDirectoryName($Target)
        $link.IconLocation = $Target + ',0'
        $link.Description = $Description
        $link.Save()
    }
    finally {
        if ($link) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) | Out-Null }
        if ($shell) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null }
    }
}

function Resolve-LabShortcutTarget {
    param([string]$Path)
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { return '' }
    $current = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
    if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { return '' }
    # Resolve the opened file, including junctions in ancestor folders.
    # https://learn.microsoft.com/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew
    if (-not ('LabDevEnv.ShortcutNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace LabDevEnv {
    public static class ShortcutNative {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle file, StringBuilder path, uint size, uint flags);
    }
}
'@
    }
    $stream = $null
    try {
        $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
        $stream = [IO.File]::Open($current, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
        $buffer = [Text.StringBuilder]::new(1024)
        $size = [LabDevEnv.ShortcutNative]::GetFinalPathNameByHandleW($stream.SafeFileHandle, $buffer, $buffer.Capacity, 0)
        if ($size -ge $buffer.Capacity) {
            $buffer = [Text.StringBuilder]::new([int]$size + 1)
            $size = [LabDevEnv.ShortcutNative]::GetFinalPathNameByHandleW($stream.SafeFileHandle, $buffer, $buffer.Capacity, 0)
        }
        if (-not $size -or $size -ge $buffer.Capacity) { return '' }
        $resolved = $buffer.ToString()
        if ($resolved.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
            return '\\' + $resolved.Substring(8)
        }
        if ($resolved.StartsWith('\\?\')) { return $resolved.Substring(4) }
        return $resolved
    }
    catch { return '' }
    finally { if ($stream) { $stream.Dispose() } }
}

function Test-LabShortcutTarget {
    param($Link, [string]$Target)
    if ($Link.Arguments) { return $false }
    $resolved = Resolve-LabShortcutTarget $Link.Target
    return [string]::Equals($resolved, $Target, [StringComparison]::OrdinalIgnoreCase)
}

function Ensure-LabPortableShortcut {
    param([string]$ProgramsPath, [string]$CommonProgramsPath, [string]$Target,
          [string]$Name, [string]$PackageId)
    if (-not [IO.Path]::IsPathRooted($ProgramsPath) -or
        -not [IO.Path]::IsPathRooted($Target) -or
        -not (Test-Path -LiteralPath $Target -PathType Leaf) -or
        [IO.Path]::GetExtension($Target) -ne '.exe' -or
        -not $Name -or $Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $PackageId -notmatch '^[A-Za-z0-9_.-]+$') {
        throw 'ショートカットの配置先・実行ファイル・名前を確認できません。'
    }
    $targetPath = Resolve-LabShortcutTarget $Target
    if (-not $targetPath) { throw 'ショートカットの実行ファイルを解決できません。' }
    $directory = Join-Path $ProgramsPath 'lab-dev-env'
    $destination = Join-Path $directory ($Name + '.lnk')
    $description = 'lab-dev-env portable: ' + $PackageId
    # Existing user/vendor files are never overwritten, including damaged links.
    if (Test-Path -LiteralPath $destination) {
        try {
            $link = Read-LabShortcut $destination
            if (Test-LabShortcutTarget $link $targetPath) {
                Write-Host "[保持] $Name のスタートメニューショートカット: $destination"
                return 0
            }
        } catch {}
        Write-Host "[手動] 同名ファイルを保持しました。ショートカットの内容を確認してください: $destination"
        return 2
    }
    # Reuse existing user/vendor launchers so setup does not add duplicate entries.
    foreach ($root in @($ProgramsPath, $CommonProgramsPath)) {
        if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.lnk' -Recurse -File -ErrorAction SilentlyContinue)) {
            try {
                $link = Read-LabShortcut $file.FullName
                if (Test-LabShortcutTarget $link $targetPath) {
                    Write-Host "[保持] $Name の既存スタートメニューショートカット: $($file.FullName)"
                    return 0
                }
            } catch {}
        }
    }
    if (Test-Path -LiteralPath $directory) {
        $item = Get-Item -LiteralPath $directory -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Write-Host "[手動] 既存の配置先を保持しました: $directory"
            return 2
        }
    } else { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $temporary = Join-Path $directory ('.lab-dev-env-' + [guid]::NewGuid().ToString('N') + '.lnk')
    try {
        Write-LabShortcut $temporary $targetPath $description
        $link = Read-LabShortcut $temporary
        if (-not (Test-LabShortcutTarget $link $targetPath) -or
            -not [string]::Equals($link.WorkingDirectory, [IO.Path]::GetDirectoryName($targetPath), [StringComparison]::OrdinalIgnoreCase)) {
            throw '作成したショートカットの実行先・作業フォルダーを確認できません。'
        }
        # Publish without overwrite; preserve a competing user's file if one appeared.
        try { [IO.File]::Move($temporary, $destination) }
        catch [IO.IOException] {
            if (-not (Test-Path -LiteralPath $destination)) { throw }
            Write-Host "[手動] 同名ファイルが追加されたため保持しました: $destination"
            return 2
        }
        Write-Host "[追加] $Name のスタートメニューショートカット: $destination"
        return 0
    }
    finally {
        if ([IO.File]::Exists($temporary)) { Remove-Item -LiteralPath $temporary -Force }
    }
}

try {
    $request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($RequestBase64)) | ConvertFrom-Json
    $programs = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
    $common = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms)
    exit (Ensure-LabPortableShortcut $programs $common $request.target $request.name $request.packageId)
}
catch {
    Write-Host "[失敗] スタートメニューショートカット: $($_.Exception.Message)"
    exit 1
}
