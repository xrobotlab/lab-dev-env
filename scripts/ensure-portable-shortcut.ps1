param([Parameter(Mandatory = $true)][string]$RequestBase64)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Initialize-LabShortcutNative {
    if ('LabDevEnv.ShortcutNative' -as [type]) { return }
    # IShellLinkW uses Unicode explicitly, independently of the OS ANSI code page.
    # https://learn.microsoft.com/windows/win32/api/shobjidl_core/nn-shobjidl_core-ishelllinkw
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using Microsoft.Win32.SafeHandles;
namespace LabDevEnv {
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink {}
    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int size, IntPtr data, uint flags);
        void GetIDList(out IntPtr list);
        void SetIDList(IntPtr list);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string value);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string value);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string value);
        void GetHotkey(out short key);
        void SetHotkey(short key);
        void GetShowCmd(out int command);
        void SetShowCmd(int command);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder value, int size, out int index);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string value, int index);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string value, uint reserved);
        void Resolve(IntPtr window, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string value);
    }
    public static class ShortcutNative {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle file, StringBuilder path, uint size, uint flags);
        public static string[] Read(string path) {
            object instance = new ShellLink();
            try {
                ((IPersistFile)instance).Load(path, 0); // STGM_READ; never Resolve or Save an existing link.
                IShellLinkW link = (IShellLinkW)instance;
                StringBuilder target = new StringBuilder(32768), args = new StringBuilder(32768);
                StringBuilder directory = new StringBuilder(32768), description = new StringBuilder(32768);
                link.GetPath(target, target.Capacity, IntPtr.Zero, 4); // SLGP_RAWPATH
                link.GetArguments(args, args.Capacity);
                link.GetWorkingDirectory(directory, directory.Capacity);
                link.GetDescription(description, description.Capacity);
                return new string[] {target.ToString(), args.ToString(), directory.ToString(), description.ToString()};
            }
            finally { Marshal.FinalReleaseComObject(instance); }
        }
        public static void Write(string path, string target, string description) {
            object instance = new ShellLink();
            try {
                IShellLinkW link = (IShellLinkW)instance;
                link.SetPath(target);
                link.SetArguments("");
                link.SetWorkingDirectory(Path.GetDirectoryName(target));
                link.SetIconLocation(target, 0);
                link.SetDescription(description);
                ((IPersistFile)instance).Save(path, true); // Caller owns this unique temporary path.
            }
            finally { Marshal.FinalReleaseComObject(instance); }
        }
    }
}
'@
}

function Read-LabShortcut {
    param([string]$Path)
    Initialize-LabShortcutNative
    $data = [LabDevEnv.ShortcutNative]::Read($Path)
    return [pscustomobject]@{ Target = $data[0]; Arguments = $data[1];
        WorkingDirectory = $data[2]; Description = $data[3] }
}

function Write-LabShortcut {
    param([string]$Path, [string]$Target, [string]$Description)
    Initialize-LabShortcutNative
    [LabDevEnv.ShortcutNative]::Write($Path, $Target, $Description)
}

function Resolve-LabShortcutTarget {
    param([string]$Path)
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { return '' }
    $current = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
    if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { return '' }
    # Resolve the opened file, including junctions in ancestor folders.
    # https://learn.microsoft.com/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew
    Initialize-LabShortcutNative
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
