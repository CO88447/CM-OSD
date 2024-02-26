﻿<#
.SYNOPSIS
    --.
.DESCRIPTION
    Success.ps1, triggered by Success.cmd
    Updates Customizations

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

#Registry Path that will get Tagged
$registryPath = "HKLM:\SOFTWARE\WaaS"
$TimeStamp = Get-Date -f s
$keyname = "CA_Success_Run"
New-ItemProperty -Path $registryPath -Name $keyname -Value $TimeStamp -Force


#Logfile generated by this script
$WaaSFolder = "$($env:ProgramData)\WaaS"
$logfile = "$WaaSFolder\CustomActions.log"
$lockscreen = "lockscreen.jpg"
$wallpaper = "wallpaper.jpg"
$systemlogo = "logo.bmp"



## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Success",
 
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
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

#Confirm LogFile Folder
if (!(Test-Path $WaaSFolder)){$NewFolder = new-item -Path $WaaSFolder -ItemType Directory -Force}
CMTraceLog -Message  "--------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting $ScriptName" -Type 1 -LogFile $LogFile

#Update Registry Settings

CMTraceLog -Message  "Regedit - Hide Music Folder in This PC" -Type 1 -LogFile $LogFile
Set-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" -Name "ThisPCPolicy" -Value "Hide"
Set-ItemProperty -Path "HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" -Name "ThisPCPolicy" -Value "Hide"

#Update Branding Items - Requires Files added to Package
if (Test-Path -Path "$WaaSFolder\Success")
    {
    CMTraceLog -Message  "Found Success Folder in $WaaSFolder" -Type 1 -LogFile $LogFile
    $SuccessFiles  = Get-ChildItem -Path "$WaaSFolder\Success" -Recurse  | Where-Object {$_.name -like "*.???" }
   
    #Update lockscreen Image
    $LockScreenImage = $SuccessFiles | Where-Object {$_.name -Match $lockscreen}   
    if ($LockScreenImage)
        {
        CMTraceLog -Message  "Copying $($LockScreenImage.FullName) to C:\Windows\Web\Screen\img100.jpg" -Type 1 -LogFile $LogFile
        Copy-Item -Path $LockScreenImage.FullName -Destination "C:\Windows\Web\Screen\img100.jpg" -Force
        CMTraceLog -Message  "Copying $($LockScreenImage.FullName) to C:\Windows\Web\Screen\img105.jpg" -Type 1 -LogFile $LogFile
        Copy-Item -Path $LockScreenImage.FullName -Destination "C:\Windows\Web\Screen\img105.jpg" -Force
        }
    
    #Update Wallpaper Image 
    $wallpaperImage = $SuccessFiles | Where-Object {$_.name -Match $wallpaper}
    IF ($wallpaperImage)
        {
        CMTraceLog -Message  "Copying $($wallpaperImage.FullName) to C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Type 1 -LogFile $LogFile
        Copy-Item -Path $wallpaperImage.FullName -Destination "C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Force
        }

    #Update User Icon to use Corporate Defaults
    if (Test-Path "$WaaSFolder\Success\UserPictures")
        {
        $UserPictures = Get-ChildItem -path "$WaaSFolder\Success\UserPictures"
        foreach ($UserPicture in $UserPictures)
            {
            CMTraceLog -Message  "Copying $($UserPicture.FullName) to $($env:ProgramData)\Microsoft\User Account Pictures" -Type 1 -LogFile $LogFile
            Copy-Item $UserPicture.FullName -Destination "$($env:ProgramData)\Microsoft\User Account Pictures" -Force
            }
        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name UseDefaultTile -Value 1 -Force -ErrorAction SilentlyContinue
        }
    }

<# 

#Running SetupDiag and capturing Results for Reporting
if (Test-Path -path 'c:\Windows.old\$WINDOWS.~BT\Sources\SetupDiag.exe'){$SetupDiagPath = 'c:\Windows.old\$WINDOWS.~BT\Sources\SetupDiag.exe'}
if (Test-Path -path 'c:\$WINDOWS.~BT\Sources\SetupDiag.exe'){$SetupDiagPath = 'c:\$WINDOWS.~BT\Sources\SetupDiag.exe'}


if (Test-Path -path $SetupDiagPath)
    {
    $LocalWaaSPathSetupDiag = "$env:ProgramData\WaaS\SetupDiag"
    if (!(Test-Path -Path $LocalWaaSPathSetupDiag)){New-Item -Path $LocalWaaSPathSetupDiag -ItemType Directory -Force}

    CMTraceLog -Message  "Found SetupDiag Here: $SetupDiagPath" -Type 1 -LogFile $LogFile
    $Process = "$SetupDiagPath"
    $RegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\WaaS\SetupDiag\LatestRun"
    $Arg = "/RegPath:$($RegPath) /Output:$($LocalWaaSPath)\Results.xml /Format:xml"
    
    CMTraceLog -Message  "Starting $Process  $Arg" -Type 1 -LogFile $LogFile
    Write-Output "Starting $Process  $Arg"
    Start-Process $Process -ArgumentList $Arg
    
    #Monitor SetupDiag
    $Seconds = 30
    

    Write-Output "Monitoring SetupDiag Process every $Seconds seconds"
    DO
        {
        if(Get-Process "SetupDiag" -ErrorAction SilentlyContinue)
            {
            Write-Output "    Setup Diag Running"
            $RuningSetupDiag = $true
            Start-Sleep -Seconds $Seconds
            }
        Else
            {
            Write-Output "  Setup Diag Finished"
            $RuningSetupDiag = $false
            }
        } Until ($RuningSetupDiag -eq $false)
    Write-Output "SetupDiag Process Complete"
    #Rename Setup Diag Key to Build Number for Historical Reasons.
    Write-Output "Rename Registry Export to Build Number"
    if (Test-Path -Path "HKLM:\Software\WaaS\SetupDiag\LatestRun")
        {
        $SetupDiagKey = get-item -Path "HKLM:\Software\WaaS\SetupDiag\LatestRun"
        $SetupElapsedTime = $SetupDiagKey.GetValue("UpgradeElapsedTime")
        [int]$SetupElapsedTimeHours = $SetupElapsedTime.Split(":")[0]
        [int]$SetupElapsedTimeMinutes = $SetupElapsedTime.Split(":")[1]
        $SetupElapsedTimeTotalMinutes = $SetupElapsedTimeHours * 60 + $SetupElapsedTimeMinutes
        $TargetOSVersion = $SetupDiagKey.GetValue("TargetOSVersion")
        $SetupDiagBuild = ($TargetOSVersion.Split(" ")[0]).split(".")[2]
        if (test-path "HKLM:\Software\WaaS\SetupDiag\$SetupDiagBuild"){Remove-Item -path "HKLM:\Software\WaaS\SetupDiag\$SetupDiagBuild"}
        Rename-Item -Path "HKLM:\Software\WaaS\SetupDiag\LatestRun" -NewName $SetupDiagBuild -Force
        Write-Output "Registry Path: HKLM:\Software\WaaS\SetupDiag\$SetupDiagBuild"
        CMTraceLog -Message  "SetupDiag Results Path: HKLM:\Software\WaaS\SetupDiag\$SetupDiagBuild" -Type 1 -LogFile $LogFile
        }
    }
else
    {
    CMTraceLog -Message  "SetupDiag.exe NOT FOUND" -Type 2 -LogFile $LogFile
    }
        
#>


CMTraceLog -Message  "Finished $ScriptName" -Type 1 -LogFile $LogFile
exit $exitcode
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================