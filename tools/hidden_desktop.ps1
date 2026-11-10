# Runs a command on a hidden Windows desktop and waits for it: its windows render normally (GPU included) but can
# never show on the screen or take the keyboard focus. tools/regress.sh uses it for the windowed runs that take the
# image goldens.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/hidden_desktop.ps1 -CommandLine '<command line>' `
#       [-Output <file>] [-TimeoutSec 300]
#
# -CommandLine is a Windows command line (program path in quotes if it has spaces). -Output collects its stdout and
# stderr (through cmd /c). Exit code: the command's, or 124 when it was stopped after -TimeoutSec seconds.
param(
	[Parameter(Mandatory = $true)][string]$CommandLine,
	[string]$Output = "",
	[int]$TimeoutSec = 300
)
$src = @"
using System;
using System.Runtime.InteropServices;
public static class SdtHiddenDesktop {
	[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr mode, int flags, uint access, IntPtr sa);
	[DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr desktop);
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	struct StartupInfo {
		public int cb; public string reserved; public string desktop; public string title;
		public int x, y, width, height, columns, rows, fill, flags;
		public short show, reserved2size; public IntPtr reserved2, stdIn, stdOut, stdErr;
	}
	struct ProcessInfo { public IntPtr process, thread; public int processId, threadId; }
	[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	static extern bool CreateProcessW(string app, string commandLine, IntPtr pa, IntPtr ta, bool inherit, uint flags,
		IntPtr env, string cwd, ref StartupInfo si, out ProcessInfo pi);
	[DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint ms);
	[DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr process, out uint code);
	[DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr process, uint code);
	[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
	const uint GENERIC_ALL = 0x10000000;
	const uint CREATE_NO_WINDOW = 0x08000000;

	public static int Run(string commandLine, int timeoutMs) {
		// Opens the desktop when another run already made it; it goes away with its last handle.
		IntPtr desktop = CreateDesktopW("sdt_hidden", IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero);
		if (desktop == IntPtr.Zero)
			throw new Exception("CreateDesktop failed: error " + Marshal.GetLastWin32Error());
		try {
			StartupInfo si = new StartupInfo();
			si.cb = Marshal.SizeOf(typeof(StartupInfo));
			si.desktop = "sdt_hidden";
			ProcessInfo pi;
			if (!CreateProcessW(null, commandLine, IntPtr.Zero, IntPtr.Zero, false, CREATE_NO_WINDOW, IntPtr.Zero,
					null, ref si, out pi))
				throw new Exception("CreateProcess failed: error " + Marshal.GetLastWin32Error());
			uint code = 124;
			if (WaitForSingleObject(pi.process, (uint)timeoutMs) != 0) {
				// the whole tree: cmd /c leaves the program running otherwise
				System.Diagnostics.Process.Start("taskkill", "/T /F /PID " + pi.processId).WaitForExit();
				TerminateProcess(pi.process, 124);
			} else
				GetExitCodeProcess(pi.process, out code);
			CloseHandle(pi.thread);
			CloseHandle(pi.process);
			return (int)code;
		} finally {
			CloseDesktop(desktop);
		}
	}
}
"@
Add-Type -TypeDefinition $src
$line = $CommandLine
if ($Output -ne "") {
	$line = 'cmd /d /c "' + $CommandLine + ' > "' + $Output + '" 2>&1"'
}
exit [SdtHiddenDesktop]::Run($line, $TimeoutSec * 1000)
