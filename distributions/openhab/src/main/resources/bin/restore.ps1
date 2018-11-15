#Requires -Version 5.0
Set-StrictMode -Version Latest

Function Restore-openHAB {
    <#
    .SYNOPSIS
    Restores openHAB files from a backup file.
    .DESCRIPTION
    The Restore-openHAB function performs the necessary tasks to restore openHAB from a backup file.
    .PARAMETER OHDirectory
    The directory where openHAB is installed (default: current directory).
    .PARAMETER OHBackups
    The directory where backup the files are.
    .PARAMETER FileName
    The name of the backup file to use (do not specify to use the latest)
    .PARAMETER AutoConfirm
    Whether to auto confirm ($true) replacement of files (used for headless mode)
    .EXAMPLE
    Restore an openHAB instance from the latest backup file
    Restore-openHAB
    .EXAMPLE
    Restore the openHAB distribution in the C:\openHAB2 directory from c:\openHAB2-backup\backup.zip without any user interaction
    Restore-openHAB -OHDirectory C:\openHAB2 -OHBackups c:\openHAB2-backup -FileName backup.zip -AutoConfirm $true
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHDirectory = ".",
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHBackups = "",
        [Parameter(ValueFromPipeline = $True)]
        [string]$FileName = "",
        [Parameter(ValueFromPipeline = $True)]
        [boolean]$AutoConfirm = $False
    )

    begin {}
    process {

        Import-Module $PSScriptRoot\common.psm1 -Force

        Write-Host ""
        BoxMessage "openHAB 2.x.x restore script" Magenta
        Write-Host ""
        
        try {
            $StartDir = Get-Location -ErrorAction Stop 
        }
        catch {
            return PrintAndReturn "Can't retrieve the current location - exiting" $_
        }

        CheckForAdmin
        CheckOpenHABRunning

        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
        $OHDirectory = GetOpenHABRoot $OHDirectory
        if ($OHDirectory -eq "") {
            return PrintAndReturn "Could not find the userdata directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
        }
    
        $OHConf = "$OHDirectory\conf"
        $OHUserdata = "$OHDirectory\userdata"

        if (([string]::IsNullOrEmpty($OHBackups))) {
            $OHBackups = "$OHDirectory\backups"
        }

        if ([string]::IsNullOrEmpty($FileName)) {
            $FileName = Get-ChildItem -Path $OHBackups -Filter *.zip -Name | Sort-Object -desc | Select-Object -First 1
        }

        if ([string]::IsNullOrEmpty($FileName)) {
            throw "No backup filename was specified and no files were found in the $OHBackups - ending"
        }

        Write-Host -ForegroundColor Cyan "Changing location to $OHDirectory"
        try {
            Set-Location -Path $OHDirectory
        }
        catch {
            return PrintAndReturn "Could not change location to $OHDirectory - exiting" $_
        }

        $TempDir = "$(GetOpenHABTempDirectory)\restore"
        Write-Host -ForegroundColor Cyan "Creating temporary restore directort $TempDir"
        try {
            CreateDirectory $TempDir
        }
        catch {
            return PrintAndReturn "Could not create directory $TempDir - exiting" $_
        }

        Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
        Write-Host -ForegroundColor Yellow "Using $OHUserdata as userdata folder"
        Write-Host -ForegroundColor Yellow "Using $OHBackups as backups folder"
        Write-Host -ForegroundColor Yellow "Using $TempDir as temporary restore directory"

        $ArchiveName = Join-Path $OHBackups $FileName

        try {
            try {
                Expand-Archive -Path $ArchiveName -DestinationPath $TempDir -ErrorAction Stop
            }
            catch {
                return PrintAndReturn "Could not unzip $ArchiveName to $TempDir - exiting" $_
            }

            try {
                Get-Content "$TempDir\backup.properties" -ErrorAction Stop | ForEach-Object {
                    $idx = $_.IndexOf("=")
                    if ($idx -ge 0) {
                        $propName = $_.Substring(0, $idx)
                        $propValue = $_.Substring($idx + 1);
                        if ($propName -eq "version") {
                            $BackupVersion = $propValue
                        }
                        ElseIf ($propName -eq "timestamp") {
                            $BackupTime = $propValue
                        }
                        ElseIf ($propName -eq "user") {
                            $OHUser = $propValue
                        }
                        ElseIf ($propName -eq "group") {
                            $OHGroup = $propValue
                        }
                    }
                }
            }
            catch {
                return PrintAndReturn "Error occurred reading/processing $TempDir\backup.properties - exiting" $_
            }

            $CurrentVersion = GetOpenHABVersion $OHDirectory

            Write-Host ""
            Write-Host -ForegroundColor Cyan " Backup Information:"
            Write-Host -ForegroundColor Cyan " -------------------"
            Write-Host -ForegroundColor Cyan " Backup File            | " -NoNewline
            Write-Host -ForegroundColor Yellow $FileName
            Write-Host -ForegroundColor Cyan " Backup Version         | " -NoNewline
            Write-Host -ForegroundColor Yellow "$BackupVersion (You are on $CurrentVersion)"
            Write-Host -ForegroundColor Cyan " Backup Timestamp       | " -NoNewline
            Write-Host -ForegroundColor Yellow $BackupTime
            Write-Host -ForegroundColor Cyan " Config belongs to user | " -NoNewline
            Write-Host -ForegroundColor Yellow $OHUser
            Write-Host -ForegroundColor Cyan "             from group | " -NoNewline
            Write-Host -ForegroundColor Yellow $OHGroup
            Write-Host ""
            Write-Host -ForegroundColor Cyan "Any existing files with the same name will be replaced."
            Write-Host -ForegroundColor Cyan "Any file without a replacement will be deleted."
            Write-Host ""
    
            if (-Not $AutoConfirm) {
                $confirmation = Read-Host "Okay to Continue? [y/N]"
                if ($confirmation -ne 'y') {
                    return PrintAndReturn "Cancelling restore"
                }
            }

            Write-Host -ForegroundColor Cyan "Copying the $TempDir\conf to $OHDirectory"
            try {
                # Replace the entire directory
                DeleteIfExists $OHConf
                Copy-Item -Path "$TempDir\conf" -Destination $OHDirectory -Force -Recurse
            }
            catch {
                return PrintAndReturn "Error copy $TempDir\conf to $OHDirectory - exiting" $_
            }

            Write-Host -ForegroundColor Cyan "Copying the $TempDir\userdata to $OHDirectory"
            try {
                # Remove everything not in the 'etc' directory
                # Will overwrite existing files in 'etc' leaving any non-match (ie new) files intact
                Get-ChildItem -Path $OHUserData -Recurse -ErrorAction Stop | Where-Object FullName -NotMatch ".*\\etc\\*.*" | ForEach-Object ($_) { 
                    DeleteIfExists $_.fullname
                    Copy-Item -Path "$TempDir\userdata" -Destination $OHDirectory -Force -Recurse -ErrorAction Stop
                }
            }
            catch {
                return PrintAndReturn "Error copy $TempDir\userdata to $OHDirectory - exiting" $_
            }

            Write-Host -ForegroundColor Green "Restore has completed"
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

            Write-Host -ForegroundColor Cyan "Setting location back to $StartDir"
            Set-Location -Path $StartDir  -ErrorAction Continue
        }
    }
}