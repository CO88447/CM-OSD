﻿<#
.SYNOPSIS
    --.
.DESCRIPTION
Create a Process as Logged-On-User from PowerShell
Then Launch the PreInstall Notificaiton Script as the logged on user.

.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by @gwblok
.LINK
    https://garytown.com
.LINK
    https://www.recastsoftware.com
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)


Start-Transcript
Write-Output --------------------------------------
Write-Output $ScriptPath $ScriptName
Get-Date

#Registry Path that will get Tagged
$registryPath = "HKLM:\SOFTWARE\WaaS"
$TimeStamp = Get-Date -f s
$keynameStart = "CA_PreInstallNotificationLauncher"
New-ItemProperty -Path $registryPath -Name $keynameStart -Value $TimeStamp -Force


#Logfile generated by this script
$WaaSFolder = "$($env:ProgramData)\WaaS"
$logfile = "$WaaSFolder\CustomActions.log"

$whoami = whoami


# Load some required namespaces
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
$Null = [System.Security.AccessControl.FileSystemAccessRule]
Add-Type -Path "$PSScriptRoot\Microsoft.Toolkit.Uwp.Notifications.dll"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "NotificationLauncher",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

#Create a Process as Logged-On-User from PowerShell
#https://rzander.azurewebsites.net/create-a-process-as-loggedon-user/
#https://github.com/murrayju/CreateProcessAsUser

$Source = @"

using System;
using System.Runtime.InteropServices;

namespace murrayju.ProcessExtensions
{
    public static class ProcessExtensions
    {
        #region Win32 Constants

        private const int CREATE_UNICODE_ENVIRONMENT = 0x00000400;
        private const int CREATE_NO_WINDOW = 0x08000000;

        private const int CREATE_NEW_CONSOLE = 0x00000010;

        private const uint INVALID_SESSION_ID = 0xFFFFFFFF;
        private static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;

        #endregion

        #region DllImports

        [DllImport("advapi32.dll", EntryPoint = "CreateProcessAsUser", SetLastError = true, CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
        private static extern bool CreateProcessAsUser(
            IntPtr hToken,
            String lpApplicationName,
            String lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandle,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            String lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
        private static extern bool DuplicateTokenEx(
            IntPtr ExistingTokenHandle,
            uint dwDesiredAccess,
            IntPtr lpThreadAttributes,
            int TokenType,
            int ImpersonationLevel,
            ref IntPtr DuplicateTokenHandle);

        [DllImport("userenv.dll", SetLastError = true)]
        private static extern bool CreateEnvironmentBlock(ref IntPtr lpEnvironment, IntPtr hToken, bool bInherit);

        [DllImport("userenv.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hSnapshot);

        [DllImport("kernel32.dll")]
        private static extern uint WTSGetActiveConsoleSessionId();

        [DllImport("Wtsapi32.dll")]
        private static extern uint WTSQueryUserToken(uint SessionId, ref IntPtr phToken);

        [DllImport("wtsapi32.dll", SetLastError = true)]
        private static extern int WTSEnumerateSessions(
            IntPtr hServer,
            int Reserved,
            int Version,
            ref IntPtr ppSessionInfo,
            ref int pCount);

        #endregion

        #region Win32 Structs

        private enum SW
        {
            SW_HIDE = 0,
            SW_SHOWNORMAL = 1,
            SW_NORMAL = 1,
            SW_SHOWMINIMIZED = 2,
            SW_SHOWMAXIMIZED = 3,
            SW_MAXIMIZE = 3,
            SW_SHOWNOACTIVATE = 4,
            SW_SHOW = 5,
            SW_MINIMIZE = 6,
            SW_SHOWMINNOACTIVE = 7,
            SW_SHOWNA = 8,
            SW_RESTORE = 9,
            SW_SHOWDEFAULT = 10,
            SW_MAX = 10
        }

        private enum WTS_CONNECTSTATE_CLASS
        {
            WTSActive,
            WTSConnected,
            WTSConnectQuery,
            WTSShadow,
            WTSDisconnected,
            WTSIdle,
            WTSListen,
            WTSReset,
            WTSDown,
            WTSInit
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public uint dwProcessId;
            public uint dwThreadId;
        }

        private enum SECURITY_IMPERSONATION_LEVEL
        {
            SecurityAnonymous = 0,
            SecurityIdentification = 1,
            SecurityImpersonation = 2,
            SecurityDelegation = 3,
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct STARTUPINFO
        {
            public int cb;
            public String lpReserved;
            public String lpDesktop;
            public String lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        private enum TOKEN_TYPE
        {
            TokenPrimary = 1,
            TokenImpersonation = 2
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WTS_SESSION_INFO
        {
            public readonly UInt32 SessionID;

            [MarshalAs(UnmanagedType.LPStr)]
            public readonly String pWinStationName;

            public readonly WTS_CONNECTSTATE_CLASS State;
        }

        #endregion

        // Gets the user token from the currently active session
        private static bool GetSessionUserToken(ref IntPtr phUserToken)
        {
            var bResult = false;
            var hImpersonationToken = IntPtr.Zero;
            var activeSessionId = INVALID_SESSION_ID;
            var pSessionInfo = IntPtr.Zero;
            var sessionCount = 0;

            // Get a handle to the user access token for the current active session.
            if (WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, ref pSessionInfo, ref sessionCount) != 0)
            {
                var arrayElementSize = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                var current = pSessionInfo;

                for (var i = 0; i < sessionCount; i++)
                {
                    var si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)current, typeof(WTS_SESSION_INFO));
                    current += arrayElementSize;

                    if (si.State == WTS_CONNECTSTATE_CLASS.WTSActive)
                    {
                        activeSessionId = si.SessionID;
                    }
                }
            }

            // If enumerating did not work, fall back to the old method
            if (activeSessionId == INVALID_SESSION_ID)
            {
                activeSessionId = WTSGetActiveConsoleSessionId();
            }

            if (WTSQueryUserToken(activeSessionId, ref hImpersonationToken) != 0)
            {
                // Convert the impersonation token to a primary token
                bResult = DuplicateTokenEx(hImpersonationToken, 0, IntPtr.Zero,
                    (int)SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation, (int)TOKEN_TYPE.TokenPrimary,
                    ref phUserToken);

                CloseHandle(hImpersonationToken);
            }

            return bResult;
        }

        public static bool StartProcessAsCurrentUser(string appPath, string cmdLine = null, string workDir = null, bool visible = true)
        {
            var hUserToken = IntPtr.Zero;
            var startInfo = new STARTUPINFO();
            var procInfo = new PROCESS_INFORMATION();
            var pEnv = IntPtr.Zero;
            int iResultOfCreateProcessAsUser;

            startInfo.cb = Marshal.SizeOf(typeof(STARTUPINFO));

            try
            {
                if (!GetSessionUserToken(ref hUserToken))
                {
                    throw new Exception("StartProcessAsCurrentUser: GetSessionUserToken failed.");
                }

                uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint)(visible ? CREATE_NEW_CONSOLE : CREATE_NO_WINDOW);
                startInfo.wShowWindow = (short)(visible ? SW.SW_SHOW : SW.SW_HIDE);
                startInfo.lpDesktop = "winsta0\\default";

                if (!CreateEnvironmentBlock(ref pEnv, hUserToken, false))
                {
                    throw new Exception("StartProcessAsCurrentUser: CreateEnvironmentBlock failed.");
                }

                if (!CreateProcessAsUser(hUserToken,
                    appPath, // Application Name
                    cmdLine, // Command Line
                    IntPtr.Zero,
                    IntPtr.Zero,
                    false,
                    dwCreationFlags,
                    pEnv,
                    workDir, // Working directory
                    ref startInfo,
                    out procInfo))
                {
                    iResultOfCreateProcessAsUser = Marshal.GetLastWin32Error();
                    throw new Exception("StartProcessAsCurrentUser: CreateProcessAsUser failed.  Error Code -" + iResultOfCreateProcessAsUser);
                }

                iResultOfCreateProcessAsUser = Marshal.GetLastWin32Error();
            }
            finally
            {
                CloseHandle(hUserToken);
                if (pEnv != IntPtr.Zero)
                {
                    DestroyEnvironmentBlock(pEnv);
                }
                CloseHandle(procInfo.hThread);
                CloseHandle(procInfo.hProcess);
            }

            return true;
        }

    }
}

"@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $Source -Language CSharp 







##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody


CMTraceLog -Message  "--------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting $ScriptName" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as: $whoami" -Type 1 -LogFile $LogFile


#$EXE = "cmd.exe"
#$ARG = '/c start /MIN powershell.exe -ExecutionPolicy ByPass -File C:\ProgramData\WaaS\PreInstall\PreInstallNotification.ps1'
#[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($EXE, $ARG)

$EXE = "c:\windows\system32\cmd.exe"
$ARG = '/c start /MIN c:\windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -windowstyle hidden -File C:\ProgramData\WaaS\PreInstall\PreInstallNotification.ps1'
[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($EXE, $ARG)

#$EXE = "powershell.exe"
#$ARG = ' -ExecutionPolicy ByPass -File C:\ProgramData\WaaS\PreInstall\PreInstallNotification.ps1'
#[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser($EXE, $ARG)


#[murrayju.ProcessExtensions.ProcessExtensions]::StartProcessAsCurrentUser("cmd.exe /c start /MIN powershell.exe -ExecutionPolicy ByPass -File C:\ProgramData\WaaS\PreInstall\PreInstallNotification.ps1")



CMTraceLog -Message  "Finished $ScriptName" -Type 1 -LogFile $LogFile
exit $exitcode
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
