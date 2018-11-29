#Requires -Version 5.0
Set-StrictMode -Version Latest

<#
    .SYNOPSIS
    Updates openHAB to the latest version.
    .DESCRIPTION
    The Update-openHAB function performs the necessary tasks to update openHAB.
    .PARAMETER OHDirectory
    The directory where openHAB is installed (default: current directory).
    .PARAMETER OHVersion
    The version to upgrade to.
    .PARAMETER Snapshot
    Upgrade to a snapshot version ($true) or a release version ($false) (default: $false)
    .PARAMETER AutoConfirm
    Automatically confirm update (used for headless mode)
    .EXAMPLE
    Update the openHAB distribution in the current directory to the current stable version
    Update-openHAB
    .EXAMPLE
    Update the openHAB distribution in the C:\oh-snapshot directory to the next snapshot version
    Update-openHAB -OHDirectory C:\oh-snapshot -OHVersion 2.3.0 -Snapshot $true
#>

Function Update-openHAB() {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHDirectory = ".",
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHVersion,
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$Snapshot = $false,
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$AutoConfirm = $false,
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$SkipNew = $false,          # sssh - secret switch ;)
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$KeepUpdateScript = $false  # sssh - secret switch ;)
    )

    function OHVersionName() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $Version, 
            [Parameter(Mandatory = $True)]
            [string] $Snapshot
        ) 
        if ($Snapshot -eq $True) {
            return "$Version-SNAPSHOT"
        } else {
            return $Version
        }
    }

    function DownloadFiles() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $DownloadSource, 
            [Parameter(Mandatory = $True)]
            [string] $OutputFile
        ) 
    
        # $uri = New-Object "System.Uri" "$DownloadSource"

        # $request = [System.Net.HttpWebRequest]::Create($uri)
        # $request.set_Timeout(15000)

        # Invoke-WebRequest $uri -Outfile $Outputfile -ErrorAction Stop

        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $uri = New-Object "System.Uri" "$DownloadSource"
        $request = [System.Net.HttpWebRequest]::Create($uri)
        $request.set_Timeout(15000)
        $response = $request.GetResponse()
        $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
        try {
            $responseStream = $response.GetResponseStream()
            $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Outputfile, Create
            $buffer = new-object byte[] 10KB
            $count = $responseStream.Read($buffer,0,$buffer.length)
            $downloadedBytes = $count
            $startTop = [System.Console]::CursorTop
            $startVisibility = [System.Console]::CursorVisible
            $startColor = [System.Console]::ForegroundColor
            try {
                [System.Console]::CursorVisible = $False
                [System.Console]::ForegroundColor = "Blue"
                while ($count -gt 0)
                {
                    $bytes = [System.Math]::Floor($downloadedBytes/1024)
                    $perc = [System.Math]::Floor(($bytes / $totalLength) * 100)
                    [System.Console]::CursorLeft = 0
                    [System.Console]::CursorTop = $startTop
                    [System.Console]::Write("Downloaded {0}K of {1}K [{2}%]", $bytes, $totalLength, $perc)
                    $targetStream.Write($buffer, 0, $count)
                    $count = $responseStream.Read($buffer,0,$buffer.length)
                    $downloadedBytes = $downloadedBytes + $count
                }
                Write-Host "`nFinished Download"
            } finally {
                [System.Console]::CursorVisible = $startVisibility
                [System.Console]::ForegroundColor = $startColor
            }
        } finally {
            if ($targetStream) {
                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
            }
            if ($responseStream) {
                $responseStream.Dispose()
            }
        }
    }

    function NormalizeVersionNumber() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $VersionNumber
        )

        $parts = $VersionNumber.Split(".")
        if ($parts.Length -eq 2) {
            $parts += "0"
        }
        if ($parts.Length -ne 3) {
            throw "$VersionNumber is not formatted correctly (d.d.d)"
        }

        $rc = "";
        $parts | ForEach-Object {
            $rc += $_.PadLeft(5 - $_.Length, '0')
            $rc += "."
        }
        return $rc.Substring(0, $rc.Length - 1)
    }

    function ProcessCommand() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $Line
        )

        # Use of global variables (not passed in)
        $Line = $Line.Replace("`$OPENHAB_USERDATA", $OHUserData)
        $Line = $Line.Replace("`$OPENHAB_CONF", $OHConf)
        $Line = $Line.Replace("`$OPENHAB_HOME", $OHDirectory)
        $Line = $Line.Replace("`$OPENHAB_RUNTIME", $OHRuntime)
        
        $parts = $Line.Split(";")

        # blank line - simply return
        if ($parts.length -eq 0) {
            return;
        }

        if ($parts[0] -eq "DEFAULT") {
            if ($parts.length -le 1) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                try {
                    Rename-Item -Path $parts[1] "$parts[1].bak" -ErrorAction Stop
                    Write-Host -ForegroundColor Cyan "$($parts[1]) renamed to $($parts[1]).bak"
                }
                catch {
                    Write-Host -ForegroundColor Yellow "Could not rename $($parts[1]) to $($parts[1]).bak"
                }
            }
        }
        ElseIf ($parts[0] -eq "DELETEDIR" -or $parts[0] -eq "DELETE") {
            if ($parts.length -le 1) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                try {
                    if ($parts[0] -eq "DELETEDIR") {
                        DeleteIfExists $parts[1] $True
                    } else {
                        DeleteIfExists $parts[1]
                    }
                    Write-Host -ForegroundColor Cyan "Deleted $($parts[1])"
                }
                catch {
                    Write-Host -ForegroundColor Yellow "Could not delete $($parts[1])"

                }
            }
        }
        ElseIf ($parts[0] -eq "MOVE") {
            if ($parts.length -le 2) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                try {
                    Move-Item -Path $parts[1] -Destination $parts[2] -ErrorAction Stop
                    Write-Host -ForegroundColor Cyan "Moved $($parts[1]) to $($parts[2])"
                }
                catch {
                    Write-Host -ForegroundColor Yellow "Could not move $($parts[1]) to $($parts[2])"
                }
            }
        }
        ElseIf ($parts[0] -eq "NOTE") {
            if ($parts.length -le 1) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                Write-Host -ForegroundColor Green "Note: " -NoNewLine 
                Write-Host $parts[1]
            }
        }
        ElseIf ($parts[0] -eq "ALERT") {
            if ($parts.length -le 1) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                Write-Host -ForegroundColor Red "Warning: " -NoNewLine 
                Write-Host $parts[1]
            }
        }
        Else {
            Write-Host -ForegroundColor Red "Unknown command: $Line"
        }
    }

    function ProcessVersionChange() {
        param(
            [Parameter(Mandatory = $True)]
            [string] $FileName,
            [Parameter(Mandatory = $True)]
            [string] $Section,
            [Parameter(Mandatory = $True)]
            [string] $VersionMsg,
            [Parameter(Mandatory = $True)]
            [string] $OldVersion,
            [Parameter(Mandatory = $True)]
            [string] $NewVersion
        )

        $InSection = $false
        $InNewVersion = $false

        $NormalizedOldVersion = NormalizeVersionNumber $OldVersion
        $NormalizedNewVersion = NormalizeVersionNumber $NewVersion
        $FoundSomething = $False
        Get-Content $FileName -ErrorAction Stop | ForEach-Object {
            if ($_ -ne "") {
                if ($_ -match "\[\[$Section\]\]") {
                    $InSection = $True
                }
                ElseIf ($_ -match "\[\[.*\]\]") {
                    $InSection = $false
                    $InNewVersion = $false
                }
                ElseIf ($_ -match "\[\d\.*\d\.*\d\]") {
                    if ($InSection) {
                        $NormalizedSectionVersion = NormalizeVersionNumber $_.Substring(1, $_.length - 2)
                        $InNewVersion = ($NormalizedSectionVersion -gt $NormalizedOldVersion) -and ($NormalizedSectionVersion -le $NormalizedNewVersion)
                        if ($InNewVersion -and $InSection) {
                            Write-Host ""
                            Write-Host -ForegroundColor Cyan "$VersionMsg $_ :"
                        }
                    }
                }
                else {
                    if ($InSection -and $InNewVersion) {
                        $FoundSomething = $True
                        ProcessCommand $_
                    }
                }
            }
        }
        return $FoundSomething
    }

    Import-Module $PSScriptRoot\common.psm1 -Force

    Write-Host ""
    BoxMessage "openHAB 2.x.x update script" Magenta
    Write-Host ""
    
    try {
        $StartDir = Get-Location -ErrorAction Stop 
    }
    catch {
        exit PrintAndReturn "Can't retrieve the current location - exiting" $_
    }

    CheckForAdmin
    CheckOpenHABRunning

    # Find the proper directory
    Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
    $OHDirectory = GetOpenHABRoot $OHDirectory
    if ($OHDirectory -eq "") {
        exit PrintAndReturn "Could not find the openHAB directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
    }

    $OHConf = GetOpenHABDirectory "OPENHAB_CONF" "$OHDirectory\conf"
    $OHUserData = GetOpenHABDirectory "OPENHAB_USERDATA" "$OHDirectory\userdata"
    $OHRuntime = GetOpenHABDirectory "OPENHAB_RUNTIME" "$OHDirectory\runtime"
    $OHAddons = GetOpenHABDirectory "OPENHAB_ADDONS" "$OHDirectory\addons"

    if (-NOT (Test-Path -Path $OHConf -PathType Container)) {
        exit PrintAndReturn "Configuration directory does not exist:  $OHConf"
    }

    if (-NOT (Test-Path -Path $OHUserData -PathType Container)) {
        exit PrintAndReturn "Userdata directory does not exist:  $OHUserData"
    }
    
    if (-NOT (Test-Path -Path $OHRuntime -PathType Container)) {
        exit PrintAndReturn "Runtime directory does not exist:  $OHRuntime"
    }
    
    if (-NOT (Test-Path -Path $OHAddons -PathType Container)) {
        exit PrintAndReturn "Addons directory does not exist:  $OHAddons"
    }
    

    Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
    Write-Host -ForegroundColor Yellow "Using $OHUserData as userdata folder"
    Write-Host -ForegroundColor Yellow "Using $OHRuntime as runtime folder"
    Write-Host -ForegroundColor Yellow "Using $OHAddons as addons folder"

    # Get current openHAB version
    $CurrentVersion = GetOpenHABVersion $OHUserData
    if ($CurrentVersion -eq "") {
        exit PrintAndReturn "Can't get the current openhab version from $OHDirectory - exiting"
    }

    $CurrentVersionSnapshot = $False;
    if ($CurrentVersion.EndsWith("-SNAPSHOT")) {
        $CurrentVersionSnapshot = $True;
        $CurrentVersion = $CurrentVersion.Substring(0, $CurrentVersion.Length - "-SNAPSHOT".Length);
    }

    if (-Not $OHVersion) {
        # If snapshot - just used the current version
        # If not - bump minor of current version by 1
        if ($Snapshot) {
            $OHVersion = $CurrentVersion
        }
        else {
            $parts = $CurrentVersion.Split(".")
            if ($parts.Length -eq 3) {
                $OHVersion = $parts[0] + "." + ([int]$parts[1] + 1) + "." + $parts[2]
            }
            else {
                exit PrintAndReturn "The current version $CurrentVersion was not formatted correctly (d.d.d)"
            }
        }
    }

    $parts = $OHVersion.Split(".")

    if ($parts.Length -eq 2) {
        $parts += "0"
    }
    if ($parts.Length -ne 3) {
        exit PrintAndReturn "The specified OH version $OHVersion was not formatted correctly (d.d.d)"
    }

    $OHVersion = $parts[0] + "." + $parts[1] + "." + $parts[2]

    # Check if service is installed, stop and delete it
    Write-Host -ForegroundColor Cyan "Checking whether a service exists"
    try {
        $service = Get-Service 'openHAB%' -ErrorAction Ignore
        if ($service) {
            # Stop and delete the service
            Write-Host -ForegroundColor Cyan "Stopping the service"
            Stop-Service $service.Name -Force -ErrorAction Stop
            Write-Host -ForegroundColor Cyan "Deleting the service"
            Remove-Service $service.Name -ErrorAction Stop
        }
    }
    catch {
        exit PrintAndReturn "Could not stop/delete the openHAB windows server - please do that manually and try again" $_
    }

    Write-Host -ForegroundColor Cyan "Changing location to $OHDirectory"
    try {
        Set-Location -Path $OHDirectory
    }
    catch {
        exit PrintAndReturn "Could not change location to $OHDirectory - exiting" $_
    }

    # Download the selected openHAB version
    # Choose bintray for releases, jenkins for snapshots.
    $TempDir = "$(GetOpenHABTempDirectory)"
    $TempDistributionZip = "$TempDir\openhab-$OHVersion.zip";
    $TempDistribution = "$TempDir\update"

    if ($Snapshot) {
        $DownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$OHVersion-SNAPSHOT.zip"
        $AddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons/target/openhab-addons-$OHVersion-SNAPSHOT.kar"
        $LegacyAddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons-legacy/target/openhab-addons-legacy-$OHVersion-SNAPSHOT.kar"
    }
    else {
        $DownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab%2F$OHVersion%2Fopenhab-$OHVersion.zip"
        $AddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons%2F$OHVersion%2Fopenhab-addons-$OHVersion.kar"
        $LegacyAddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons-legacy%2F$OHVersion%2Fopenhab-addons-legacy-$OHVersion.kar"
    }

    if ($CurrentVersionSnapshot) {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion-SNAPSHOT"
    } else {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion"        
    }


    # If we are not in SkipNew:
    #   1. (Re)Create the temporary distribution directory
    #   2. Download the distribution to the temp directory
    #   3. Expand the distribution to the temp directory
    #   4. Detect whether a new update.ps1 should be executed
    # If we are in skipnew - all this should have been done already
    if (($SkipNew -eq $False) -or 
            (($SkipNew -eq $True) -and -NOT
                ((Test-Path -Path $TempDistributionZip -PathType Leaf) -and (Test-Path -Path $TempDistribution -PathType Container))
            )
        ) {
        ########### STEP 1 - create the temporary distribution directory
        try {
            DeleteIfExists $TempDir $True
        }
        catch {
            # Do nothing here - probably a file lock issue
        }

        try {
            Write-Host -ForegroundColor Cyan "Creating temporary update directory $TempDir"
            CreateDirectory $TempDir
        }
        catch {
            exit PrintAndReturn "Error creating temporary update directory $TempDir - exiting" $_
        }

        ########### STEP 2 - download the distribution
        try {
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $(OHVersionName $OHVersion $Snapshot) distribution to $TempDistributionZip"
            DownloadFiles $DownloadLocation $TempDistributionZip
        }
        catch {
            if ([int]$_.Exception.InnerException.Response.StatusCode -eq 404) {
                exit PrintAndReturn "Download of $(OHVersionName $OHVersion $Snapshot) failed because it's not a valid version" $_
            } else {
                exit PrintAndReturn "Download of $DownloadLocation failed" $_
            }
        }

        ########### STEP 3 - Expand the archive
        try {
            Write-Host -ForegroundColor Cyan "Extracting the archive ($TempDistributionZip) to $TempDistribution"
            Expand-Archive -Path $TempDistributionZip -DestinationPath $TempDistribution -Force -ErrorAction Stop
        } catch {
            exit PrintAndReturn "Unzipping of $TempDistributionZip to $TempDistribution failed." $_
        }

        ########### STEP 3b - Copy the update/common over if we are keeping the update scripts
        if ($KeepUpdateScript) {
            try {
                Write-Host -ForegroundColor Cyan "Keeping commons.psm1 and update.ps1 by copying to $TempDistribution\runtime\bin"
                Copy-Item -Path "$OHRuntime\bin\common.psm1" -Destination "$TempDistribution\runtime\bin\common.psm1" -Force
                Copy-Item -Path "$OHRuntime\bin\update.ps1" -Destination "$TempDistribution\runtime\bin\update.ps1" -Force
            } catch {
                Write-Error $_
                Write-Host -ForegroundColor Magenta "Could not copy the common.psm1 and update.ps1 to $TempDistribution\runtime\bin"
                # Don't bother with AutoConfirm here since this is special debugging logic to begin with
                $confirmation = Read-Host "Okay to Continue? [y/N]"
                if ($confirmation -ne 'y') {
                    exit PrintAndReturn "Cancelling update"
                }
            }
        }
    }

    ########### STEP 4 - Run new update.ps1 if needed
    if ($SkipNew -eq $False) {
        $newUpdate = Join-Path $TempDistribution "\runtime\bin\update.ps1"

        If (Test-Path $newUpdate) {
            Write-Host ""
            BoxMessage "New update.ps1 was found - executing it instead (found in $newUpdate)" Magenta
            Write-Host ""
            try {
                # go back to our original directory so the new update script does it as well
                Set-Location -Path $StartDir  -ErrorAction Continue 
                . $newUpdate
                Update-openHAB -OHDirectory $OHDirectory -OHVersion $OHVersion -Snapshot $Snapshot -AutoConfirm $AutoConfirm -SkipNew $true -KeepUpdateScript $KeepUpdateScript
                exit 2;
            } catch {
                exit PrintAndReturn "Execution of new update.ps1 failed - please execute it yourself (found in $newUpdate)" $_
            }
        }
    }

    # Do after the update.ps1 check to make sure this question isn't asked twice
    if ($OHVersion -eq $CurrentVersion -and $Snapshot -eq $False) {
        if ($AutoConfirm) {
            Write-Host -ForegroundColor Magenta "Current version is equal to specified version ($(OHVersionName $OHVersion $Snapshot)).  ***REINSTALLING*** $(OHVersionName $OHVersion $Snapshot) instead (rather than upgrading)."
        } else {
            Write-Host -ForegroundColor Magenta "Current version is equal to specified version ($(OHVersionName $OHVersion $Snapshot)).  If you continue, you will REINSTALL $(OHVersionName $OHVersion $Snapshot) rather than upgrade."
            $confirmation = Read-Host "Okay to Continue? [y/N]"
            if ($confirmation -ne 'y') {
                exit PrintAndReturn "Cancelling update"
            }
        }
        Write-Host -ForegroundColor Yellow "REINSTALLING" -NoNewline -BackgroundColor Blue
        Write-Host -ForegroundColor Yellow " version $(OHVersionName $OHVersion $Snapshot)"
    } else {
        # Check for downgrade
        if ((NormalizeVersionNumber $OHVersion) -lt (NormalizeVersionNumber $CurrentVersion)) {
            # Don't use autoconfirm on a downgrade warning
            BoxMessage "You are attempting to downgrade from $CurrentVersion to $(OHVersionName $OHVersion $Snapshot) !!!" Red
            Write-Host -ForegroundColor Magenta "This script is not meant to downgrade and the results will be unpredictable"
            $confirmation = Read-Host "Okay to Continue? [y/N]"
            if ($confirmation -ne 'y') {
                exit PrintAndReturn "Cancelling update"
            }
            Write-Host -ForegroundColor Yellow "DOWNGRADING" -NoNewline -BackgroundColor Red
            Write-Host -ForegroundColor Yellow " to version $(OHVersionName $OHVersion $Snapshot)"
        } else {
            Write-Host -ForegroundColor Yellow "Upgrading to version $(OHVersionName $OHVersion $Snapshot)"
        }
    }


    # Backup openHAB only if not coming via new update script

    $TempBackupDir = "$TempDir\backup-$CurrentVersion"
    $TempBackupDirHome = $TempBackupDir + "\home"
    $TempBackupDirRuntime = $TempBackupDir + "\runtime"
    $TempBackupDirUserData = $TempBackupDir + "\userdata"
    $TempBackupDirConf = $TempBackupDir + "\conf"
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Making a backup of your distribution to $TempBackupDir"
    try {
        Write-Host -ForegroundColor Cyan "Creating backup directories in $TempBackupDir"
        DeleteIfExists $TempBackupDir $True

        Write-Host -ForegroundColor Cyan "Copying directory conf, userdata and runtime to $TempBackupDirConf"
        Copy-Item -Path $OHConf, $OHUserData, $OHRuntime -Destination $TempBackupDir -Recurse -Force -ErrorAction Stop

        Write-Host -ForegroundColor Cyan "Copying files from $OHDirectory to $TempBackupDirHome"
        Get-ChildItem $OHDirectory -File -ErrorAction Stop | Copy-Item -Destination $TempBackupDirHome -Force -ErrorAction Stop

    } catch {
        exit PrintAndReturn "Could not backup existing distribution to $TempBackupDir" $_
    }
    
    try {
        $updateLst = Join-Path $TempDistribution "\runtime\bin\update.lst"

        if (Test-Path $updateLst) {
            Write-Host ""
            Write-Host -ForegroundColor Cyan "The script will attempt to update openHAB to version $(OHVersionName $OHVersion $Snapshot)"
            Write-Host -ForegroundColor Cyan "Please read the following " -NoNewLine
            Write-Host -ForegroundColor Green "notes" -NoNewLine
            Write-Host -ForegroundColor Cyan " and " -NoNewLine
            Write-Host -ForegroundColor Red "warnings"
            $NotesFound = $False
            try {
                $NotesFound = ProcessVersionChange $updateLst "MSG" "Important notes for version" $CurrentVersion $OHVersion
            } catch {
                # PrintAndReturn since there have been no file changes yet
                exit PrintAndReturn "Could not process 'MSG' of $updateLst" $_
            }

            if ($NotesFound) {
                if (-Not $AutoConfirm) {
                    $confirmation = Read-Host "Okay to Continue? [y/N]"
                    if ($confirmation -ne 'y') {
                        exit PrintAndReturn "Cancelling update"
                    }
                }
            } else {
                Write-Host -ForegroundColor Blue "No notes found for version $(OHVersionName $OHVersion $Snapshot)"    
            }

            try {
                Write-Host ""
                Write-Host -ForegroundColor Cyan "Execute 'PRE' instructions for version $(OHVersionName $OHVersion $Snapshot)"
                if (-NOT (ProcessVersionChange $updateLst "PRE" "Performing pre-update tasks for version" $CurrentVersion $OHVersion)) {
                    Write-Host -ForegroundColor Blue "No 'PRE' instructions found for version $(OHVersionName $OHVersion $Snapshot)"
                }
            } catch {
                return PrintAndThrow "Could not process 'PRE' of $updateLst" $_
            }
            Write-Host ""
        }


        # Delete current userdata files
        # Update openHAB
        #   1. First remove all file in runtime (they will all be replaced)
        #   2. Remove all the userdata\etc files listed in userdata_sysfiles.lst (they will be replaced)
        #   3. Remove the cache/tmp directories
        #   4. Then copy all files from our new distribution WITHOUT overwriting anything
        #      (by removals in 1 & 2 - that means we will replace those)
        #

        ############## STEP 1 - remove runtime
        try {
            Write-Host -ForegroundColor Cyan "Deleting current runtime ($OHRuntime)"
            DeleteIfExists $OHRuntime $True
        } catch {
            return PrintAndThrow "Could not delete current runtime ($OHRuntime)" $_
        }

        ############## STEP 2 - remove userdata\etc files in userdata_sysfiles.lst
        $updateSysFilesLst = "$TempDistribution\runtime\bin\userdata_sysfiles.lst"
        if (Test-Path $updateSysFilesLst) {
            Write-Host -ForegroundColor Cyan "Deleting current files in userdata that should not persist"
            foreach ($FileName in Get-Content $updateSysFilesLst) {
                $fileToDelete = "$OHUserData\etc\$FileName"
                try {
                    if (Test-Path -Path $fileToDelete) {
                        DeleteIfExists $fileToDelete
                        Write-Host -ForegroundColor Cyan "Deleted $FileName from $OHUserData\etc"
                    }
                } catch {
                    Write-Error $_
                    Write-Host "Could not delete $fileToDelete.  File is no longer needed and should be manually deleted."
                }
            }
        }

        ############## STEP 3 - remove cache/tmp directories
        try {
            Write-Host -ForegroundColor Cyan "Removing $OHUserData\cache"
            DeleteIfExists "$OHUserData\cache" $True
        } catch {
            return PrintAndThrow "Could not delete the $OHUserData\cache directory" $_
        }

        try {
            Write-Host -ForegroundColor Cyan "Removing $OHUserData\tmp"
            DeleteIfExists "$OHUserData\tmp" $True
        } catch {
            return PrintAndThrow "Could not delete the $OHUserData\tmp directory" $_
        }

        ############## STEP 4 - copy files from temporary to distribution WITHOUT replacement
        Write-Host -ForegroundColor Cyan "Copying $TempDistribution to $OHDirectory without overwriting existing ones"
        try {
            Get-ChildItem -Path $TempDistribution -Recurse -ErrorAction Stop | ForEach-Object { 
                $relPath = GetRelativePath $TempDistribution $_.FullName

                if ($relPath.StartsWith(".\addons")) {
                    $localPath = Join-Path $OHAddons $relPath.Substring(".\addons".Length)
                } elseif ($relPath.StartsWith(".\conf")) {
                    $localPath = Join-Path $OHConf $relPath.Substring(".\conf".Length)    
                } elseif ($relPath.StartsWith(".\userdata")) {
                    $localPath = Join-Path $OHUserData $relPath.Substring(".\userdata".Length)
                } elseif ($relPath.StartsWith(".\runtime")) {
                    $localPath = Join-Path $OHRuntime $relPath.Substring(".\runtime".Length)
                } else {
                    $localPath = Join-Path $OHDirectory $relPath
                }
                if (-Not (Test-Path $localPath)) {
                    if (Test-Path $localPath -PathType Container) {
                        CreateDirectory $localPath
                    } else {
                        Copy-Item -Path $_.FullName -Destination $localPath -ErrorAction Stop
                    }
                }
            }
        } catch {
            return PrintAndThrow "Error occurred copying $TempDistribution to $OHDirectory" $_
        }

        if (Test-Path $updateLst) {
            Write-Host ""
            try {
                Write-Host -ForegroundColor Cyan "Execute 'POST' instructions for version $(OHVersionName $OHVersion $Snapshot)"
                if (-NOT (ProcessVersionChange $updateLst "POST" "Performing post-update tasks for version" $CurrentVersion $OHVersion)) {
                    Write-Host -ForegroundColor Blue "No 'POST' instructions found for version $(OHVersionName $OHVersion $Snapshot)"
                }
            } catch {
                return PrintAndThrow "Could not process 'POST' of $updateLst" $_
            }
        }
        Write-Host ""


        # If there's an existing addons file, we need to replace it with the correct version.
        try {
            $AddonsFile = "$OHAddons\openhab-addons-$(OHVersionName $OHVersion $Snapshot).kar"
            if (Test-Path -Path $AddonsFile) {
                Write-Host "Found an openHAB addons file, replacing with new version"
                DeleteIfExists $AddonsFile
                DownloadFiles $AddonsDownloadLocation "$OHAddons\openhab-addons-$(OHVersionName $OHVersion $Snapshot).kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $AddonsFile" $_
        }


        # Do the same for the legacy addons file.
        try {
            $LegacyAddonsFile = "$OHAddons\openhab-addons-legacy-$(OHVersionName $OHVersion $Snapshot).kar"
            if (Test-Path -Path $LegacyAddonsFile) {
                Write-Host "Found an openHAB legacy addons file, replacing with new version"
                DeleteIfExists $LegacyAddonsFile
                DownloadFiles $LegacyAddonsDownloadLocation "$OHAddons\openhab-addons-legacy-$(OHVersionName $OHVersion $Snapshot).kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $LegacyAddonsFile" $_
        }

        Write-Host -ForegroundColor Green "openHAB updated to version $(OHVersionName $OHVersion $Snapshot)!"
        Write-Host -ForegroundColor Green "Run start.bat to launch it."
        Write-Host -ForegroundColor Green "Check https://www.openhab.org/docs/installation/windows.html"
        Write-Host -ForegroundColor Green "for instructions on re-installing the Windows Service if desired"
    }
    catch {

        BoxMessage "Restoring your distribution from $TempBackupDir" Yellow
        try {
            Write-Host -ForegroundColor Cyan "Removing existing files in $OHDirectory"
            Get-ChildItem $OHDirectory -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Cyan "Copying backup files from $TempBackupDirHome to $OHDirectory"
            Get-ChildItem $TempBackupDirHome -file -ErrorAction Stop | Copy-Item -Destination $OHDirectory -Force -ErrorAction Stop

            Write-Host -ForegroundColor Cyan "Removing the directory $OHConf"
            Remove-Item "$OHConf\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Cyan "Copying backup directory $TempBackupDirConf to $OHConf"
            Copy-Item -Path "$TempBackupDirConf\*" -Destination $OHConf -Recurse -Force -ErrorAction Stop

            Write-Host -ForegroundColor Cyan "Removing the directory $OHUserData"
            Remove-Item "$OHUserData\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Cyan "Copying backup directory $TempBackupDirUserData to $OHUserData"
            Copy-Item -Path "$TempBackupDirUserData\*" -Destination $OHUserData -Recurse -Force -ErrorAction Stop

            Write-Host -ForegroundColor Cyan "Removing the directory $OHRuntime"
            Remove-Item "$OHRuntime\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Cyan "Copying backup directory $TempBackupDirRuntime to $OHRuntime"
            Copy-Item -Path "$TempBackupDirRuntime\*" -Destination $OHRuntime -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host -ForegroundColor Cyan "Restoration was unsuccessful - you may want to restore from $TempBackupDir yourself"
            Write-Error $_
        }
        exit -1
    }
    finally {
        Write-Host ""

        try {
            if (Test-Path $TempBackupDir) {
                if ($AutoConfirm) {
                    Write-Host -ForegroundColor Cyan "Removing temporary distribution backup $TempBackupDir"
                    DeleteIfExists $TempBackupDir $True
                } else {
                    Write-Host -ForegroundColor Cyan "Your prior distribution is in $TempBackupDir"
                    $confirmation = Read-Host "Should it be deleted? [y/N]"
                    if ($confirmation -eq 'y') {
                        Write-Host -ForegroundColor Cyan "Removing temporary distribution backup $TempBackupDir"
                        DeleteIfExists $TempBackupDir $True
                    }
                }
            }
        }
        catch {
            Write-Host -ForegroundColor Red "Could not delete $TempBackupDir - delete it manually"
        }

        try {
            # If the backup directory doesn't exist - delete the tempdir directory (and it's parent)
            # (may exist if they answer "N" to the above question)
            if (-NOT (Test-Path $TempBackupDir)) {
                try {
                    Write-Host -ForegroundColor Cyan "Removing temporary directory $TempDir"
                    DeleteIfExists $TempDir $True
                }
                catch {
                    Write-Host -ForegroundColor Red "Could not delete $TempDir - delete it manually"
                }
            }
        }
        catch {
            Write-Host -ForegroundColor Red "Could not delete $parent - delete it manually"
        }

        Write-Host -ForegroundColor Cyan "Setting location back to $StartDir"
        Set-Location -Path $StartDir  -ErrorAction Continue
    }
}
