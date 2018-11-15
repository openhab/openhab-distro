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
    .PARAMETER SkipNew
    Internal use only. For skipping the check for a new update.ps1
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
        [boolean]$SkipNew = $false,
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$KeepUpdateScript = $false  # sssh - secret switch ;)
    )

    function DownloadFiles() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $DownloadSource, 
            [Parameter(Mandatory = $True)]
            [string] $OutputFile
        ) 
    
        $uri = New-Object "System.Uri" "$DownloadSource"

        $request = [System.Net.HttpWebRequest]::Create($uri)
        $request.set_Timeout(15000)

        Invoke-WebRequest $uri -Outfile $Outputfile -ErrorAction Stop
    }

    function NormalizeVersionNumber() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $VersionNumber
        )

        $parts = $VersionNumber.Split(".")
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
                    DeleteIfExists $parts[1]
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
            [string] $CurrentVersion
        )

        $InSection = $false
        $InNewVersion = $false

        $NormalizedCurrentVersion = NormalizeVersionNumber $CurrentVersion
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
                        $NormalizedVersion = NormalizeVersionNumber $_.Substring(1, $_.length - 2)
                        $InNewVersion = ($NormalizedCurrentVersion -lt $NormalizedVersion)
                        if ($InNewVersion -and $InSection) {
                            Write-Host ""
                            Write-Host -ForegroundColor Cyan "$VersionMsg $_ :"
                        }
                    }
                }
                else {
                    if ($InSection -and $InNewVersion) {
                        ProcessCommand $_
                    }
                }
            }
        }
    }

    Import-Module $PSScriptRoot\common.psm1 -Force

    Write-Host ""
    BoxMessage "openHAB 2.x.x update script" Magenta
    Write-Host ""
    
    try {
        $StartDir = Get-Location -ErrorAction Stop 
    }
    catch {
        return PrintAndReturn "Can't retrieve the current location - exiting" $_
    }

    CheckForAdmin
    CheckOpenHABRunning


    # Find the proper directory
    Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
    $OHDirectory = GetOpenHABRoot $OHDirectory
    if ($OHDirectory -eq "") {
        return PrintAndReturn "Could not find the openHAB directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
    }

    # Get current openHAB version
    $CurrentVersion = GetOpenHABVersion $OHDirectory;
    if ($CurrentVersion -eq "") {
        return PrintAndReturn "Can't get the current openhab version from $OHDirectory - exiting"
    }
    if ($CurrentVersion.EndsWith("-SNAPSHOT")) {
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
                return PrintAndReturn "The current version $CurrentVersion was not formatted correctly (d.d.d)"
            }
        }
    }

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
        return PrintAndReturn "Could not stop/delete the openHAB windows server - please do that manually and try again" $_
    }

    Write-Host -ForegroundColor Cyan "Changing location to $OHDirectory"
    try {
        Set-Location -Path $OHDirectory
    }
    catch {
        return PrintAndReturn "Could not change location to $OHDirectory - exiting" $_
    }

    # Download the selected openHAB version
    # Choose bintray for releases, jenkins for snapshots.
    $TempDir = "$(GetOpenHABTempDirectory)\update"
    $OutputFile = "$TempDir\openhab-$OHVersion.zip"
    $TempDistributionZip = "$TempDir\openhab-$OHVersion.zip";
    $TempDistribution = "$TempDir\openhab-$OHVersion"
    if ($Snapshot) {
        $OHVersion = "$OHVersion-SNAPSHOT"
        $DownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$OHVersion.zip"
        $AddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons/target/openhab-addons-$OHVersion.kar"
        $LegacyAddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons-legacy/target/openhab-addons-legacy-$OHVersion.kar"
    }
    else {
        $DownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab%2F$OHVersion%2Fopenhab-$OHVersion.zip"
        $AddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons%2F$OHVersion%2Fopenhab-addons-$OHVersion.kar"
        $LegacyAddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons-legacy%2F$OHVersion%2Fopenhab-addons-legacy-$OHVersion.kar"
    }

    if ($Snapshot) {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion-SNAPSHOT"
    } else {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion"        
    }
    Write-Host -ForegroundColor Yellow "Upgrading to version $OHVersion"

    # If we are not in SkipNew:
    #   1. (Re)Create the temporary distribution directory
    #   2. Download the distribution to the temp directory
    #   3. Expand the distribution to the temp directory
    #   4. Detect whether a new update.ps1 should be executed
    # If we are in skipnew - all this should have been done already
    if ($SkipNew -eq $False) {
        ########### STEP 1 - create the temporary distribution directory
        try {
            DeleteIfExists $TempDir
        }
        catch {
            # Do nothing here - probably a file lock issue
        }

        try {
            Write-Host -ForegroundColor Cyan "Creating temporary update directory $TempDir"
            CreateDirectory $TempDir
        }
        catch {
            return PrintAndReturn "Error creating temporary update directory $TempDir - exiting" $_
        }

        ########### STEP 2 - download the distribution
        try {
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersion distribution to $TempDistributionZip"
            DownloadFiles $DownloadLocation $TempDistributionZip
        }
        catch {
            return PrintAndReturn "Download of $DownloadLocation failed" $_
        }

        ########### STEP 3 - Expand the archive
        try {
            Write-Host -ForegroundColor Cyan "Extracting the archive ($TempDistributionZip) to $TempDistribution"
            Expand-Archive -Path $TempDistributionZip -DestinationPath $TempDistribution -Force -ErrorAction Stop
        } catch {
            return PrintAndReturn "Unzipping of $TempDistributionZip to $TempDistribution failed." $_
        }

        ########### STEP 4 - Run new update.ps1 if needed
        $newUpdate = Join-Path $TempDistribution "/runtime/bin/update.ps1"
        if ($KeepUpdateScript) {
            try {
                Copy-Item -Path "$OHDirectory/runtime/bin/common.psm1" -Destination "$TempDistribution/runtime/bin/common.psm1" -Force
                Copy-Item -Path "$OHDirectory/runtime/bin/update.ps1" -Destination $newUpdate -Force
            } catch {
                Write-Host -ForegroundColor Magenta "Could not copy the update.ps1 to the new distribution"
                # Don't bother with AutoConfirm here since this is special debugging logic to begin with
                $confirmation = Read-Host "Okay to Continue? [y/N]"
                if ($confirmation -ne 'y') {
                    return PrintAndReturn "Cancelling update"
                }
            }
        }
        
        If (Test-Path $newUpdate) {
            Write-Host ""
            BoxMessage "New update.ps1 was found - executing it instead (found in $newUpdate)" Magenta
            Write-Host ""
            try {
                $rawOHVersion = $OHVersion
                if ($rawOHVersion.EndsWith("-SNAPSHOT")) {
                    $rawOHVersion = $rawOHVersion.Substring(0, $rawOHVersion.Length - "-SNAPSHOT".Length)
                }
                # go back to our original directory so the new update script does it as well
                Set-Location -Path $StartDir  -ErrorAction Continue 
                . $newUpdate
                Update-openHAB -OHDirectory $OHDirectory -OHVersion $rawOHVersion -Snapshot $Snapshot -AutoConfirm $AutoConfirm -SkipNew $true -KeepUpdateScript $KeepUpdateScript
                return 2;
            } catch {
                return PrintAndReturn "Execution of new update.ps1 failed - please execute it yourself (found in $newUpdate)" $_
            }
        }
    }

    # Backup openHAB only if not coming via new update script
    $BackupFile = "$OHDirectory\backup-$CurrentVersion.zip"
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Making a backup of your distribution to $BackupFile"
    try {
        DeleteIfExists $BackupFile
        Compress-Archive -Path "$OHDirectory\*" -DestinationPath $BackupFile -CompressionLevel Fastest -ErrorAction Stop
    } catch {
        return PrintAndReturn "Could not backup existing distribution to $BackupFile" $_
    }
    
    try {
        $updateLst = Join-Path $TempDistribution "/runtime/bin/update.lst"

        if (Test-Path $updateLst) {
            Write-Host ""
            Write-Host -ForegroundColor Cyan "The script will attempt to update openHAB to version $OHVersion"
            Write-Host -ForegroundColor Cyan "Please read the following " -NoNewLine
            Write-Host -ForegroundColor Green "notes" -NoNewLine
            Write-Host -ForegroundColor Cyan " and " -NoNewLine
            Write-Host -ForegroundColor Red "warnings"
            try {
                ProcessVersionChange $updateLst "MSG" "Important notes for version" $CurrentVersion
            } catch {
                # PrintAndReturn since there have been no file changes yet
                return PrintAndReturn "Could not process 'MSG' of $updateLst" $_
            }

            if (-Not $AutoConfirm) {
                $confirmation = Read-Host "Okay to Continue? [y/N]"
                if ($confirmation -ne 'y') {
                    return PrintAndReturn "Cancelling update"
                }
            }
        }

        try {
            Write-Host ""
            Write-Host -ForegroundColor Cyan "Execute 'PRE' instructions"
            ProcessVersionChange $updateLst "PRE" "Performing pre-update tasks for version" $CurrentVersion
        } catch {
            return PrintAndThrow "Could not process 'PRE' of $updateLst" $_
        }
        Write-Host ""

        # Delete current userdata files
        # Update openHAB
        #   1. First remove all file in runtime (they will all be replaced)
        #   2. Remove all the userdata\etc files listed in userdata_sysfiles.lst (they will be replaced)
        #   3. Remove the cache/tmp directories
        #   4. Then copy all files from our new distribution WITHOUT overwriting anything
        #      (by removals in 1 & 2 - that means we will replace those)
        #

        ############## STEP 1 - remove runtime
        $runtime = Join-Path $OHDirectory "\runtime"
        try {
            Write-Host -ForegroundColor Cyan "Deleting current runtime ($runtime)"
            DeleteIfExists $runtime
        } catch {
            return PrintAndThrow "Could not delete current runtime ($runtime)" $_
        }

        ############## STEP 2 - remove userdata\etc files in userdata_sysfiles.lst
        Write-Host -ForegroundColor Cyan "Deleting current files in userdata that should not persist"
        foreach ($FileName in Get-Content "$TempDistribution\runtime\bin\userdata_sysfiles.lst") {
            $fileToDelete = "$OHDirectory\userdata\etc\$FileName"
            try {
                if (Test-Path -Path $fileToDelete) {
                    DeleteIfExists $fileToDelete
                    Write-Host -ForegroundColor Cyan "Deleted $FileName from $OHDirectory\userdata\etc"
                }
            } catch {
                Write-Error $_
                Write-Host "Could not delete $fileToDelete.  File is no longer needed and should be manually deleted."
            }
        }

        ############## STEP 3 - remove cache/tmp directories
        try {
            Write-Host -ForegroundColor Cyan "Removing $OHDirectory\userdata\cache"
            DeleteIfExists "$OHDirectory\userdata\cache"
        } catch {
            return PrintAndThrow "Could not delete the $OHDirectory\userdata\cache directory" $_
        }

        try {
            Write-Host -ForegroundColor Cyan "Removing $OHDirectory\userdata\tmp"
            DeleteIfExists "$OHDirectory\userdata\tmp"
        } catch {
            return PrintAndThrow "Could not delete the $OHDirectory\userdata\tmp directory" $_
        }

        ############## STEP 4 - copy files from temporary to distribution WITHOUT replacement
        Write-Host -ForegroundColor Cyan "Copying $TempDistribution to $OHDirectory without overwriting existing ones"
        try {
            Get-ChildItem -Path $TempDistribution -Recurse -ErrorAction Stop | ForEach-Object { 
                $relPath = GetRelativePath $TempDistribution $_.FullName
                $localPath = Join-Path $OHDirectory $relPath
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

        Write-Host ""
        try {
            Write-Host -ForegroundColor Cyan "Execute 'POST' instructions"
            ProcessVersionChange $updateLst "POST" "Performing post-update tasks for version" $CurrentVersion
        } catch {
            return PrintAndThrow "Could not process 'POST' of $updateLst" $_
        }
        Write-Host ""


        # If there's an existing addons file, we need to replace it with the correct version.
        try {
            $AddonsFile = "$OHDirectory\addons\openhab-addons-$OHVersion.kar"
            if (Test-Path -Path $AddonsFile) {
                Write-Host "Found an openHAB addons file, replacing with new version"
                DeleteIfExists $AddonsFile
                DownloadFiles $AddonsDownloadLocation "$OHDirectory\addons\openhab-addons-$OHVersion.kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $AddonsFile" $_
        }


        # Do the same for the legacy addons file.
        try {
            $LegacyAddonsFile = "$OHDirectory\addons\openhab-addons-legacy-$OHVersion.kar"
            if (Test-Path -Path $LegacyAddonsFile) {
                Write-Host "Found an openHAB legacy addons file, replacing with new version"
                DeleteIfExists $LegacyAddonsFile
                DownloadFiles $LegacyAddonsDownloadLocation "$OHDirectory\addons\openhab-addons-legacy-$OHVersion.kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $LegacyAddonsFile" $_
        }

        Write-Host -ForegroundColor Green "openHAB updated to version $OHVersion!"
        Write-Host -ForegroundColor Green "Run start.bat to launch it."
        Write-Host -ForegroundColor Green "Check https://www.openhab.org/docs/installation/windows.html"
        Write-Host -ForegroundColor Green "for instructions on re-installing the Windows Service if desired"
    }
    catch {
        BoxMessage "Restoring your distribution from $BackupFile" Yellow
        try {
            Write-Host -ForegroundColor Cyan "Removing all files from distribution (except $BackupFile)"
            Get-ChildItem -Path $OHDirectory -Recurse -ErrorAction Stop | Where-Object FullName -ne $BackupFile | ForEach-Object {
                try {
                    DeleteIfExists $_.FullName
                } catch {
                    # do nothing
                }
            }

            Write-Host -ForegroundColor Cyan "Restoring distribution backup $BackupFile"
            Expand-Archive -Path $BackupFile -DestinationPath $OHDirectory -Force -ErrorAction Stop
        } catch {
            Write-Host -ForegroundColor Cyan "Restoration was unsuccessful - you may want to try unzipping $BackupFile"
            Write-Error $_

            # Important to reset this variable so the 'finally' block doesn't delete it
            $BackupFile = "doesntexist"
        }
    }
    finally {
        $parent = (Get-Item $TempDir).Parent.FullName

        try {
            Write-Host -ForegroundColor Cyan "Removing temporary directory $TempDir"
            DeleteIfExists $TempDir
        }
        catch {
            Write-Host -ForegroundColor Red "Could not delete $TempDir - delete it manually"
        }

        try {
            if (-Not (Test-Path "$parent\*")) {
                Write-Host -ForegroundColor Cyan "Removing temporary directory $parent"
                DeleteIfExists $parent
            }
        }
        catch {
            Write-Host -ForegroundColor Red "Could not delete $parent - delete it manually"
        }

        try {
            if (Test-Path $BackupFile) {
                if ($AutoConfirm) {
                    Write-Host -ForegroundColor Cyan "Removing temporary distribution backup $BackupFile"
                    DeleteIfExists $BackupFile
                } else {
                    Write-Host -ForegroundColor Cyan "Your prior distribution is in $BackupFile"
                    $confirmation = Read-Host "Should it be deleted? [y/N]"
                    if ($confirmation -eq 'y') {
                        Write-Host -ForegroundColor Cyan "Removing temporary distribution backup $BackupFile"
                        DeleteIfExists $BackupFile
                    }
                }
            }
        }
        catch {
            Write-Host -ForegroundColor Red "Could not delete $BackupFile - delete it manually"
        }

        Write-Host -ForegroundColor Cyan "Setting location back to $StartDir"
        Set-Location -Path $StartDir  -ErrorAction Continue
    }
}
