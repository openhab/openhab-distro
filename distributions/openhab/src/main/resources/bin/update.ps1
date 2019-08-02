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
    DEPRECATED - Upgrade to a snapshot version ($true) or a release version ($false) (default: $false)
    DEPRECATED - Please specify "-snapshot" in the OHVersion instead (ex: "2.4.0-SNAPSHOT")
    .PARAMETER AutoConfirm
    Automatically confirm update (used for headless mode)
    .EXAMPLE
    Update the openHAB distribution in the current directory to the current stable version
    Update-openHAB
    .EXAMPLE
    Update the openHAB distribution in the C:\oh-snapshot directory to the next snapshot version
    Update-openHAB -OHDirectory C:\oh-snapshot -OHVersion 2.3.0-SNAPSHOT
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

    # Downloads the URL into a file showing a progress meter.  Any error will be thrown to the caller

    function DownloadFiles() {
        param(    
            [Parameter(Mandatory = $True)]
            [string] $URL, 
            [Parameter(Mandatory = $True)]
            [string] $OutputFile
        ) 
    
        # Create the request
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        $uri = New-Object "System.Uri" "$URL"
        $request = [System.Net.HttpWebRequest]::Create($uri)
        $request.set_Timeout(15000)

        #Get the response (along with the total size)
        $response = $request.GetResponse()
        $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)

        try {
            # Gets the response stream and setup the buffer
            $responseStream = $response.GetResponseStream()
            $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Outputfile, Create
            $buffer = new-object byte[] 10KB

            # Save console settings
            $startTop = [System.Console]::CursorTop
            $startVisibility = [System.Console]::CursorVisible
            $startColor = [System.Console]::ForegroundColor

            # Process each chunk into the output file (updating the progress meter along the way)
            try {
                [System.Console]::CursorVisible = $False
                [System.Console]::ForegroundColor = "Blue"
                $count = $responseStream.Read($buffer,0,$buffer.length)
                $downloadedBytes = $count
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
                # Set the console settings back
                [System.Console]::CursorVisible = $startVisibility
                [System.Console]::ForegroundColor = $startColor
            }
        } finally {
            # Cleanup resources
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

    # This function 'normalizes' the version number - creates left 0 padded segments "0000.0000.0000" that can be compared against
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

    # This function will process a command from the upgrade.lst file (called from ProcessVersionChange)
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
        
        # Split the line into it's distinct parts
        $parts = $Line.Split(";")

        # blank line - simply return
        if ($parts.length -eq 0) {
            return;
        }

        # If default - rename an item to "x.bak" (assumes a new version of this file will be added by the upgrade process)
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

        # Deletes an item
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

        # Moves an item
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

        # Replaces text in a file
        ElseIf ($parts[0] -eq "REPLACE") {
            if ($parts.length -le 3) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                try {
                    (Get-Content $parts[3]).replace($parts[1], $parts[2]) | Set-Content $parts[3]
                    Write-Host -ForegroundColor Cyan "Replaced string $($parts[1]) to $($parts[2]) in file $($parts[3])"
                }
                catch {
                    Write-Host -ForegroundColor Yellow "Could not replace string $($parts[1]) to $($parts[2]) in file $($parts[3])"
                }
            }
        }

        # Shows a note (console message with a green label)
        ElseIf ($parts[0] -eq "NOTE") {
            if ($parts.length -le 1) {
                Write-Host -ForegroundColor Red "Badly formatted: $Line"
            }
            else {
                Write-Host -ForegroundColor Green "Note: " -NoNewLine 
                Write-Host $parts[1]
            }
        }
        # Shows a note (console message with a red label)
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

    # Processes the update.lst file for the specific section, and version (going from x.x.x to x.x.x).
    # A boolean is returned indicating whether we found any commands or not
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

        # Flags used
        $InSection = $false
        $InNewVersion = $false

        # Normalize our lower/upper versions
        $NormalizedOldVersion = NormalizeVersionNumber $OldVersion
        $NormalizedNewVersion = NormalizeVersionNumber $NewVersion

        # FoundSomething is true if we did some action (and is returned to caller)
        $FoundSomething = $False

        # Loops through the content of the file...
        Get-Content $FileName -ErrorAction Stop | ForEach-Object {
            # Skip blank lines
            if ($_ -ne "") {
                # If it's OUR section - flip the switch
                if ($_ -match "\[\[$Section\]\]") {
                    $InSection = $True
                }
                # If it's not OUR section - flip it false
                ElseIf ($_ -match "\[\[.*\]\]") {
                    $InSection = $false
                    $InNewVersion = $false
                }
                # If its a version number section
                ElseIf ($_ -match "\[\d\.*\d\.*\d\]") {
                    # Determine if we are in a section and the version number is greater than our lower bound but less than or equal to our upper bound
                    if ($InSection) {
                        $NormalizedSectionVersion = NormalizeVersionNumber $_.Substring(1, $_.length - 2)
                        $InNewVersion = ($NormalizedSectionVersion -gt $NormalizedOldVersion) -and ($NormalizedSectionVersion -le $NormalizedNewVersion)
                        if ($InNewVersion -and $InSection) {
                            # If so, show that we are processing this section
                            Write-Host ""
                            Write-Host -ForegroundColor Cyan "$VersionMsg $_ :"
                        }
                    }
                }
                else {
                    if ($InSection -and $InNewVersion) {
                        # Woohoo - found a command to process
                        $FoundSomething = $True
                        ProcessCommand $_
                    }
                }
            }
        }

        return $FoundSomething
    }

    # Force reimport of common functions (in case of upgrading the script)
    Import-Module $PSScriptRoot\common.psm1 -Force

    # Write out startup message
    Write-Host ""
    BoxMessage "openHAB 2.x.x update script" Magenta
    Write-Host ""
    
    # Check for admin (commented out - don't think we need it)
    # CheckForAdmin

    # Check for openhab running
    CheckOpenHABRunning

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

    
    # Find the proper directory root directory
    Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
    $OHDirectory = GetOpenHABRoot $OHDirectory
    if ($OHDirectory -eq "") {
        exit PrintAndReturn "Could not find the openHAB directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
    }

    # Get the various 'other' directories
    $OHConf = GetOpenHABDirectory "OPENHAB_CONF" "$OHDirectory\conf"
    $OHUserData = GetOpenHABDirectory "OPENHAB_USERDATA" "$OHDirectory\userdata"
    $OHRuntime = GetOpenHABDirectory "OPENHAB_RUNTIME" "$OHDirectory\runtime"
    $OHAddons = GetOpenHABDirectory "OPENHAB_ADDONS" "$OHDirectory\addons"

    # Validate that all the directories exist (and are directories)
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
    
    # Tell the user what we are processing
    Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
    Write-Host -ForegroundColor Yellow "Using $OHUserData as userdata folder"
    Write-Host -ForegroundColor Yellow "Using $OHRuntime as runtime folder"
    Write-Host -ForegroundColor Yellow "Using $OHAddons as addons folder"

    # Get current openHAB version
    $CurrentVersion = GetOpenHABVersion $OHUserData
    if ($CurrentVersion -eq "") {
        exit PrintAndReturn "Can't get the current openhab version from $OHDirectory - exiting"
    }

    # Determine if it's a snapshot
    $CurrentVersionSnapshot = $False;
    if ($CurrentVersion.EndsWith("-SNAPSHOT", "CurrentCultureIgnoreCase")) {
        $CurrentVersionSnapshot = $True;
        $CurrentVersion = $CurrentVersion.Substring(0, $CurrentVersion.Length - "-SNAPSHOT".Length);
    }

    # Tell the user our current version
    if ($CurrentVersionSnapshot) {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion-SNAPSHOT"
    } else {
        Write-Host -ForegroundColor Yellow "The current version is $CurrentVersion"        
    }

    # If the version was not specified,
    #    If the current version is snapshot  - make OHVersion the same snapshot
    #    If the current version is stable    - make OHVersion the next minor upgrade (current version 2.3.0 would make our OHversion 2.4.0)
    #    If the current version is milestone - make OHVersion the stable version (2.3.0.M6 becomes 2.3.0)
    if (-Not $OHVersion) {
        $parts = $CurrentVersion.Split(".")
        if ($parts.Length -eq 3) {
            if ($CurrentVersionSnapshot -eq $True) {
                $OHVersion = $CurrentVersion + "-SNAPSHOT"
            } else {
                $OHVersion = $parts[0] + "." + ([int]$parts[1] + 1) + "." + $parts[2]
            }
        } elseif ($parts.Length -eq 4) {
            $OHVersion = $parts[0] + "." + $parts[1] + "." + $parts[2]
        }
        else {
            exit PrintAndReturn "The current version $CurrentVersion was not formatted correctly (d.d.d)"
        }

    }

    # If snapshot was defined, add "-snapshot" to the OHVersion if not already present
    if ($Snapshot -eq $true) {
        BoxMessage "-SNAPSHOT is deprecated - please put '-snapshot' in OHVersion instead (ex: 2.4.0-snapshot)" Magenta
        if (-Not $OHVersion.EndsWith("-SNAPSHOT", "CurrentCultureIgnoreCase")) {
            $OHVersion = $OHVersion + "-SNAPSHOT"
        }
    }

    # Split up the OHVersion to validate
    $parts = $OHVersion.Split(".")

    # If only "2.3" - make "2.3.0"
    if ($parts.Length -eq 2) {
        $parts += "0"
    }

    # Valid versions: 
    #    Stable:    "2.3.0"
    #    Snapshot:  "2.3.0-SNAPSHOT"
    #    Milestone: "2.3.0.M6"
    if (($parts.Length -lt 3) -or ($parts.Length -gt 4)) {
        exit PrintAndReturn "The specified OH version $OHVersion was not formatted correctly (d.d.d[.d])"
    }

    $Snapshot = $False
    $Milestone = ""
    if ($parts[2].EndsWith("-SNAPSHOT", "CurrentCultureIgnoreCase")) {
        $Snapshot = $True
        $parts[2] = $parts[2].Substring(0, $parts[2].Length - "-SNAPSHOT".Length);
    } elseif ($parts.Length -eq 4) {
        $Milestone = $parts[3]
    }
    $OHVersion = $parts[0] + "." + $parts[1] + "." + $parts[2]

    # Recreate the name - should be standardized now and is used for messages and downloads
    if ($Snapshot -eq $True) {
        $OHVersionName =  "$OHVersion-SNAPSHOT"
    } elseif ($Milestone -ne "") {
        $OHVersionName = $OHVersion + "." + $Milestone
    } else {
        $OHVersionName = $OHVersion
    }

    # Get the current directory (so we can switch back to it at the end)
    try {
        $StartDir = Get-Location -ErrorAction Stop 
    }
    catch {
        exit PrintAndReturn "Can't retrieve the current location - exiting" $_
    }

    # Set the current directory to our OH root directory
    Write-Host -ForegroundColor Cyan "Changing location to $OHDirectory"
    try {
        Set-Location -Path $OHDirectory
    }
    catch {
        exit PrintAndReturn "Could not change location to $OHDirectory - exiting" $_
    }

    # Setup where our temporary locations will be
    $TempDir = "$(GetOpenHABTempDirectory)"
    $TempDistributionZip = "$TempDir\openhab-$OHVersion.zip";
    $TempDistribution = "$TempDir\update"

    # Create the proper download URLs
    if ($Snapshot) {
        $DownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$OHVersionName.zip"
        $AddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons/target/openhab-addons-$OHVersionName.kar"
        $LegacyAddonsDownloadLocation="https://ci.openhab.org/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons-legacy/target/openhab-addons-legacy-$OHVersionName.kar"
    }
    elseif ($Milestone -ne "") {
        $DownloadLocation="https://openhab.jfrog.io/openhab/libs-milestone-local/org/openhab/distro/openhab/$OHVersionName/openhab-$OHVersionName.zip"
        $AddonsDownloadLocation="https://openhab.jfrog.io/openhab/libs-milestone-local/org/openhab/distro/openhab-addons/$OHVersionName/openhab-addons-$OHVersionName.kar"
        $LegacyAddonsDownloadLocation="https://openhab.jfrog.io/openhab/libs-milestone-local/org/openhab/distro/openhab-addons-legacy/$OHVersionName/openhab-addons-legacy-$OHVersionName.kar"
    }
    else {
        $DownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab%2F$OHVersion%2Fopenhab-$OHVersion.zip"
        $AddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons%2F$OHVersion%2Fopenhab-addons-$OHVersion.kar"
        $LegacyAddonsDownloadLocation = "https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons-legacy%2F$OHVersion%2Fopenhab-addons-legacy-$OHVersion.kar"
    }

    # If we are not in SkipNew (or SkipNew and the temporary distribution file/folders have not been created yet):
    #   1. Delete and recreate the temporary distribution directory if it exists
    #   2. Download the distribution to the temp directory
    #   3. Expand the distribution to the temp directory
    #   4. Copy the update.ps1/common.psm1 files to the temp distribution if KeepUpdateScript is true (dev purposes only)
    if (($SkipNew -eq $False) -or 
            (($SkipNew -eq $True) -and -NOT
                ((Test-Path -Path $TempDistributionZip -PathType Leaf) -and (Test-Path -Path $TempDistribution -PathType Container))
            )
        ) {
        ########### STEP 1 - Delete and recreate the temporary distribution directory if it exists
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
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersionName distribution to $TempDistributionZip"
            DownloadFiles $DownloadLocation $TempDistributionZip
        }
        catch {
            if ([int]$_.Exception.InnerException.Response.StatusCode -eq 404) {
                exit PrintAndReturn "Download of $OHVersionName failed because it's not a valid version" $_
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

        ########### STEP 4 - Copy the update/common over if we are keeping the update scripts
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

    # If not SkipNew - check to see if the new distribution has an update.ps1 (which is likely)
    # and then execute it (exiting with it's result)
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
                exit Update-openHAB -OHDirectory $OHDirectory -OHVersion $OHVersionName -AutoConfirm $AutoConfirm -SkipNew $true -KeepUpdateScript $KeepUpdateScript
            } catch {
                exit PrintAndReturn "Execution of new update.ps1 failed - please execute it yourself (found in $newUpdate)" $_
            }
        }
    }

    # Do the following questions after the update.ps1 check to make sure this question isn't asked twice!

    # Are we resinstalling the current version (as long as it's not a snapshot)
    if ($OHVersion -eq $CurrentVersion -and $Snapshot -eq $False) {
        if ($AutoConfirm) {
            Write-Host -ForegroundColor Magenta "Current version is equal to specified version ($OHVersionName).  ***REINSTALLING*** $OHVersionName instead (rather than upgrading)."
        } else {
            Write-Host -ForegroundColor Magenta "Current version is equal to specified version ($OHVersionName).  If you continue, you will REINSTALL $OHVersionName rather than upgrade."
            $confirmation = Read-Host "Okay to Continue? [y/N]"
            if ($confirmation -ne 'y') {
                exit PrintAndReturn "Cancelling update"
            }
        }
        Write-Host -ForegroundColor Yellow "REINSTALLING" -NoNewline -BackgroundColor Blue
        Write-Host -ForegroundColor Yellow " version $OHVersionName"
    } else {

        # Are we trying to downgrade the distribution (yikes!)
        if ((NormalizeVersionNumber $OHVersion) -lt (NormalizeVersionNumber $CurrentVersion)) {
            # Don't use autoconfirm on a downgrade warning
            BoxMessage "You are attempting to downgrade from $CurrentVersion to $OHVersionName !!!" Red
            Write-Host -ForegroundColor Magenta "This script is not meant to downgrade and the results will be unpredictable"
            $confirmation = Read-Host "Okay to Continue? [y/N]"
            if ($confirmation -ne 'y') {
                exit PrintAndReturn "Cancelling update"
            }
            Write-Host -ForegroundColor Yellow "DOWNGRADING" -NoNewline -BackgroundColor Red
            Write-Host -ForegroundColor Yellow " to version $OHVersionName"
        } else {
            Write-Host -ForegroundColor Yellow "Upgrading to version $OHVersionName"
        }
    }


    # Crete the temporary backup locations to the current distribution
    $TempBackupDir = "$TempDir\backup-$CurrentVersion"
    $TempBackupDirHome = $TempBackupDir + "\home"
    $TempBackupDirRuntime = $TempBackupDir + "\runtime"
    $TempBackupDirUserData = $TempBackupDir + "\userdata"
    $TempBackupDirConf = $TempBackupDir + "\conf"

    # Backup the current distribution to those locations
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
    
    # Alright - we are ready to being the update process.  This will be wrapped in a 
    # try/catch/finally to restore our current distribution on error and to cleanup
    # the temporary files when finished
    try {

        # If our update.lst exists, process the notes (ie MSG section) and the PRE section
        $updateLst = Join-Path $TempDistribution "\runtime\bin\update.lst"

        if (Test-Path $updateLst) {
            Write-Host ""
            Write-Host -ForegroundColor Cyan "The script will attempt to update openHAB to version $OHVersionName"
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
                Write-Host -ForegroundColor Blue "No notes found for version $OHVersionName"    
            }

            try {
                Write-Host ""
                Write-Host -ForegroundColor Cyan "Execute 'PRE' instructions for version $OHVersionName"
                if (-NOT (ProcessVersionChange $updateLst "PRE" "Performing pre-update tasks for version" $CurrentVersion $OHVersion)) {
                    Write-Host -ForegroundColor Blue "No 'PRE' instructions found for version $OHVersionName"
                }
            } catch {
                return PrintAndThrow "Could not process 'PRE' of $updateLst" $_
            }
            Write-Host ""
        }


        # Delete current userdata files
        # Update openHAB
        #   1. First remove all file in runtime (they will all be replaced)
        #   2. Remove all the userdata\etc files listed in userdata_sysfiles.lst (they may be replaced)
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

        # If we have an update.lst - process the "POST" section
        if (Test-Path $updateLst) {
            Write-Host ""
            try {
                Write-Host -ForegroundColor Cyan "Execute 'POST' instructions for version $OHVersionName"
                if (-NOT (ProcessVersionChange $updateLst "POST" "Performing post-update tasks for version" $CurrentVersion $OHVersion)) {
                    Write-Host -ForegroundColor Blue "No 'POST' instructions found for version $OHVersionName"
                }
            } catch {
                return PrintAndThrow "Could not process 'POST' of $updateLst" $_
            }
        }
        Write-Host ""


        # If there's an existing addons file, we need to replace it with the correct version.
        try {
            $AddonsFile = "$OHAddons\openhab-addons-$OHVersionName.kar"
            if (Test-Path -Path $AddonsFile) {
                Write-Host "Found an openHAB addons file, replacing with new version"
                DeleteIfExists $AddonsFile
                DownloadFiles $AddonsDownloadLocation "$OHAddons\openhab-addons-$OHVersionName.kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $AddonsFile" $_
        }


        # Do the same for the legacy addons file.
        try {
            $LegacyAddonsFile = "$OHAddons\openhab-addons-legacy-$OHVersionName.kar"
            if (Test-Path -Path $LegacyAddonsFile) {
                Write-Host "Found an openHAB legacy addons file, replacing with new version"
                DeleteIfExists $LegacyAddonsFile
                DownloadFiles $LegacyAddonsDownloadLocation "$OHAddons\openhab-addons-legacy-$OHVersionName.kar"
            }
        } catch {
            return PrintAndThrow "Could not replace the $LegacyAddonsFile" $_
        }

        # Hop for joy - we did it!
        Write-Host -ForegroundColor Green "openHAB updated to version $OHVersionName!"
        Write-Host -ForegroundColor Green "Run start.bat to launch it."
        Write-Host -ForegroundColor Green "Check https://www.openhab.org/docs/installation/windows.html"
        Write-Host -ForegroundColor Green "for instructions on re-installing the Windows Service if desired"
    }
    catch {

        # Some issue happened - we need to copy the old distribution back 
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
        # And we are done...
        Write-Host ""

        # If our temp backup directory exists - ask if we should remove it
        # TODO - maybe only do this if an error occurred
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

        # FINALLY - set our location back to where we began
        Write-Host -ForegroundColor Cyan "Setting location back to $StartDir"
        Set-Location -Path $StartDir  -ErrorAction Continue
    }
}
