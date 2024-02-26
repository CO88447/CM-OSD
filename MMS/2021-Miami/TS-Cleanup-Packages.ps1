function Confirm-TSProgressUISetup(){
    if ($Script:TaskSequenceProgressUi -eq $null){
        try{$Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI}
        catch{throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_"}
        }
    }

function Confirm-TSEnvironmentSetup(){
    if ($Script:TaskSequenceEnvironment -eq $null){
        try{$Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment}
        catch{throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_"}
        }
    }

function Show-TSActionProgress()
{

    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [long] $Step,
        [Parameter(Mandatory=$true)]
        [long] $MaxStep
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    $Script:TaskSequenceProgressUi.ShowActionProgress(`
        $Script:TaskSequenceEnvironment.Value("_SMSTSOrgName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCustomProgressDialogMessage"),`
        $Script:TaskSequenceEnvironment.Value("_SMSTSCurrentActionName"),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSNextInstructionPointer")),`
        [Convert]::ToUInt32($Script:TaskSequenceEnvironment.Value("_SMSTSInstructionTableSize")),`
        $Message,`
        $Step,`
        $MaxStep)
}

Function Get-CCMCachePackages {


$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet

#$CCMUpdatePackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -match "-"}
$CCMPackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -notmatch "-"}
#$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}

return $CCMPackages
}
$TSEnv = New-Object -ComObject "Microsoft.SMS.TSEnvironment"  
$TaskSequenceProgressUi = New-Object -ComObject "Microsoft.SMS.TSProgressUI"

$Packages = Get-CCMCachePackages
$CounterMax = $Packages.Count

$TaskSequenceProgressUi.CloseProgressDialog() 
$TaskSequenceProgressUi.ShowTSProgress($TSEnv.Value("_SMSTSOrgName"),$TSEnv.Value("_SMSTSPackageName"),"Removing $CounterMax Packages from Cache","$($TSEnv.Value("_SMSTSCurrentActionName")) - $CounterMax Items"  ,[Convert]::ToUInt32($TSEnv.Value("_SMSTSNextInstructionPointer")),[Convert]::ToUInt32($TSEnv.Value("_SMSTSInstructionTableSize")))


$Counter = 0
ForEach ($Update in $Packages)
    {
    Write-Output "Removing PackageID: $($Update.ContentId) From: $($Update.Location) with Size: $([math]::Round(($Update.ContentSize /1MB) , 2))"
    $ContentID = $Update.ContentId
    #$CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -in $ContentID} | ForEach-Object {$CMCacheObjects.DeleteCacheElementEx($_.CacheElementID,$True)}
    Show-TSActionProgress -Message "Removing PackageID: $($Update.ContentId) From: $($Update.Location) with Size: $([math]::Round(($Update.ContentSize /1MB) , 2))" -Step $Counter -MaxStep $CounterMax -ErrorAction SilentlyContinue
    Start-Sleep -s 2
    $Counter ++
    }
$TaskSequenceProgressUi.CloseProgressDialog() 
