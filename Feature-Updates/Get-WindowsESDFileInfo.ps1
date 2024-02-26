$StagingFolder = "$env:TEMP\OSDStaging"
if (!(Test-Path -Path $StagingFolder)){
    new-item -Path $StagingFolder -ItemType Directory | Out-Null
}

#Windows 10 Latest Cab: https://go.microsoft.com/fwlink/?LinkId=841361
#Windows 11 Latest CAB: https://go.microsoft.com/fwlink/?LinkId=2156292


$WindowsMCTTable = @(
@{ Version = 'Win10';LocalCab = "Win10.Cab"; URL = "https://go.microsoft.com/fwlink/?LinkId=841361"}
@{ Version = 'Win11';LocalCab = "Win11.Cab"; URL = "https://go.microsoft.com/fwlink/?LinkId=2156292"}
)

$WindowsTable = @(
@{ Version = 'Win1022H2';LocalCab = "Win1022H2.Cab"; URL = "https://download.microsoft.com/download/7/9/c/79cbc22a-0eea-4a0d-89c0-054a1b3aa8e0/products.cab"}
@{ Version = 'Win1121H2';LocalCab = "Win1121H2.Cab"; URL = "https://download.microsoft.com/download/1/b/4/1b4e06e2-767a-4c9a-9899-230fe94ba530/products_Win11_20211115.cab"}
@{ Version = 'Win1122H2';LocalCab = "Win1122H2.Cab"; URL = "https://download.microsoft.com/download/b/1/9/b19bd7fd-78c4-4f88-8c40-3e52aee143c2/products_win11_20230510.cab.cab"}
@{ Version = 'Win1123H2';LocalCab = "Win1123H2.Cab"; URL = "https://download.microsoft.com/download/6/2/b/62b47bc5-1b28-4bfa-9422-e7a098d326d4/products_win11_20231208.cab"}
)

#$Win1022H2CabURL = "https://download.microsoft.com/download/7/9/c/79cbc22a-0eea-4a0d-89c0-054a1b3aa8e0/products.cab"
#$Win1121H2CabURL = "https://download.microsoft.com/download/1/b/4/1b4e06e2-767a-4c9a-9899-230fe94ba530/products_Win11_20211115.cab"
#$Win1122H2CabURL = "https://download.microsoft.com/download/b/1/9/b19bd7fd-78c4-4f88-8c40-3e52aee143c2/products_win11_20230510.cab.cab"
#$Win1123H2CabURL = "https://download.microsoft.com/download/6/2/b/62b47bc5-1b28-4bfa-9422-e7a098d326d4/products_win11_20231208.cab"



#region functions borrowed from HPCMSL
function Invoke-HPPrivateExpandCAB {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] $cab,
    [Parameter(Mandatory = $true)] $expectedFile
  )
  Write-Verbose "Expanding CAB $cab to $cab.dir"

  $target = "$cab.dir"
  Invoke-HPPrivateSafeRemove -Path $target -Recurse
  Write-Verbose "Expanding $cab to $target"
  $result = New-Item -Force $target -ItemType Directory
  Write-Verbose "Created folder $result"

  $shell = New-Object -ComObject "Shell.Application"
  $exception = $null
  try {
    if (!$?) { $(throw "unable to create $comObject object") }
    $sourceCab = $shell.Namespace($cab).items()
    $DestinationFolder = $shell.Namespace($target)
    $DestinationFolder.CopyHere($sourceCab)
  }
  catch {
    $exception = $_.Exception
  }
  finally {
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shell) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }

  if ($exception) {
    throw "Failed to decompress $cab. $($exception.Message)."
  }

  $downloadedOk = Test-Path $expectedFile
  if ($downloadedOk -eq $false) {
    throw "Invalid cab file, did not find $expectedFile in contents"
  }
  return $expectedFile
}

function Invoke-HPPrivateSafeRemove {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)] [string[]]$path,
    [Parameter(Mandatory = $false)] [switch]$recurse
  )
  foreach ($p in $path) {
    if (Test-Path $p) {
      Write-Verbose "Removing $p"
      Remove-Item $p -Recurse:$recurse
    }
  }
}
#endregion

#region functions
function Test-WebConnection{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        # Uri to test
        [System.Uri]
        $Uri = 'google.com'
    )
    $Params = @{
        Method = 'Head'
        Uri = $Uri
        UseBasicParsing = $true
        Headers = @{'Cache-Control'='no-cache'}
    }

    try {
        Write-Verbose "Test-WebConnection OK: $Uri"
        Invoke-WebRequest @Params | Out-Null
        $true
    }
    catch {
        Write-Verbose "Test-WebConnection FAIL: $Uri"
        $false
    }
    finally {
        $Error.Clear()
    }
}

#endregion

$ESDInfo  = @()
ForEach ($Option in $WindowsTable){
    Invoke-WebRequest -Uri $Option.URL -UseBasicParsing -OutFile "$StagingFolder\$($Option.LocalCab)" -ErrorAction SilentlyContinue
    $file = Invoke-HPPrivateExpandCAB -cab "$StagingFolder\$($Option.LocalCab)" -expectedFile "$StagingFolder\$($Option.LocalCab).dir\products.xml"
    [XML]$XML = Get-Content -Raw -Path "$StagingFolder\$($Option.LocalCab).dir\products.xml"
    $ESDInfo += $XML.MCT.Catalogs.Catalog.PublishedMedia.Files.File
}



ForEach ($MCT in $WindowsMCTTable){
    New-Variable -Name "$($MCT.Version)Change" -Value $true -Force
    Invoke-WebRequest -Uri $MCT.URL -UseBasicParsing -OutFile "$StagingFolder\$($MCT.LocalCab)" -ErrorAction SilentlyContinue
    $MD5HashMCT = Get-FileHash -Algorithm MD5 -Path "$StagingFolder\$($MCT.LocalCab)"
    ForEach ($Option in $WindowsTable){
        $MD5HashOption = Get-FileHash -Algorithm MD5 -Path "$StagingFolder\$($Option.LocalCab)"
        if ($MD5HashMCT.Hash -eq $MD5HashOption.Hash){
            Set-Variable -Name "$($MCT.Version)Change" -Value $false
            Write-Output "$($MCT.Version) Has not changed"
        }
    }
    if ("$($MCT.Version)Change" -eq $true){Write-Output "$($MCT.Version) has changed"}
}

#Clean Up Results
$x64ESDInfo = $ESDInfo | Where-Object {$_.Architecture -eq "x64"}
#$x64ESDInfo = $x64ESDInfo | Where-Object {$_.Edition -eq "Professional" -or $_.Edition -eq "Education" -or $_.Edition -eq "Enterprise" -or $_.Edition -eq "Professional" -or $_.Edition -eq "HomePremium"}
