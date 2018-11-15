#Requires -Version 5.0
Set-StrictMode -Version Latest

Function Backup-openHAB {
    <#
    .SYNOPSIS
    Backsup openHAB files.
    .DESCRIPTION
    The Backup-openHAB function performs the necessary tasks to backup openHAB.
    .PARAMETER OHDirectory
    The directory where openHAB is installed (default: current directory).
    .PARAMETER OHBackups
    The directory to backup the files to.
    .PARAMETER FileName
    The name of the zip file to create
    .EXAMPLE
    Backup an openHAB instance to a zip file
    Backup-openHAB
    .EXAMPLE
    Backup the openHAB distribution in the C:\openHAB2 directory to c:\openHAB2-backup\backup.zip
    Backup-openHAB -OHDirectory C:\openHAB2 -OHBackups c:\openHAB2-backup -FileName backup.zip
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHDirectory = ".",
        [Parameter(ValueFromPipeline = $True)]
        [string]$OHBackups,
        [Parameter(ValueFromPipeline = $True)]
        [string]$FileName
    )

    begin {}
    process {

        Import-Module $PSScriptRoot\common.psm1 -Force

        Write-Host ""
        BoxMessage "openHAB 2.x.x backup script" Magenta
        Write-Host ""

        CheckForAdmin

        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
        $OHDirectory = GetOpenHABRoot $OHDirectory
        if ($OHDirectory -eq "") {
            return PrintAndReturn "Could not find the userdata directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
        }
    
        $OHConf = "$OHDirectory\conf"
        $OHUserdata = "$OHDirectory\userdata"

        if ([string]::IsNullOrEmpty($OHBackups)) {
            $OHBackups = "$OHDirectory\backups"
        }

        if (!(Test-Path $OHBackups -PathType Container)) {
            try {
                Write-Host -ForegroundColor Cyan "Creating backup directory $OHBackups"
                CreateDirectory $OHBackups
            }
            catch {
                return PrintAndReturn "Error creating backup directory $OHBackups - exiting" $_
            }
        }

        Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
        Write-Host -ForegroundColor Yellow "Using $OHUserdata as userdata folder"
        Write-Host -ForegroundColor Yellow "Using $OHBackups as backups folder"

        $TempDir = "$(GetOpenHABTempDirectory)\backup"

        try {
            Write-Host -ForegroundColor Cyan "Creating temporary backup directory $TempDir"
            CreateDirectory $TempDir
        }
        catch {
            return PrintAndReturn "Error creating temporary backup directory $TempDir - exiting" $_
        }

        try {
            $CurrentVersion = GetOpenHABVersion $OHDirectory
            if ($CurrentVersion -eq "") {
                return PrintAndReturn "Can't get the current openhab version from $OHDirectory - exiting"
            }

            $timestamp = Get-Date -UFormat "%y_%m_%d-%H_%M_%S"
            $BackupProperites = "$TempDir\backup.properties"
            try {
                CreateFile $BackupProperites
                Write-Output "version=$CurrentVersion" -ErrorAction Stop | Add-Content $BackupProperites -ErrorAction Stop
                Write-Output "timestamp=$timestamp" -ErrorAction Stop | Add-Content $BackupProperites -ErrorAction Stop 
                Write-Output "user=openhab" -ErrorAction Stop | Add-Content $BackupProperites -ErrorAction Stop
                Write-Output "group=openhab" -ErrorAction Stop | Add-Content $BackupProperites -ErrorAction Stop
            }
            catch {
                return PrintAndReturn "Can't create the temporary backup.properties file in $TempDir - exiting" $_
            }

            Write-Host -ForegroundColor Cyan "Copying userdata and conf folder contents to temp directory"
            try {
                Copy-Item $OHUserdata $TempDir -Recurse
                Copy-Item $OHConf $TempDir -Recurse
            }
            catch {
                return PrintAndReturn "Can't copy the userdata/conf directory to the temporary directory $TempDir - exiting" $_
            }

            try {
                Write-Host -ForegroundColor Cyan "Removing unnecessary files"
                foreach ($sysFile in Get-Content "$OHDirectory\runtime\bin\userdata_sysfiles.lst") {
                    DeleteIfExists "$TempDir\userdata\etc\$sysFile"
                }
                DeleteIfExists "$TempDir\userdata\cache"
                DeleteIfExists "$TempDir\userdata\tmp"

                Write-Host -ForegroundColor Cyan "Removing backup folder from backup userdata if it exists"
                DeleteIfExists "$TempDir\userdata\backups"
            }
            catch {
                return PrintAndReturn "Error removing unnecessary files from $TempDir - exiting" $_
            }

            if ([string]::IsNullOrEmpty($FileName)) {
                $FileName = "$OHBackups\openhab2-backup-$timestamp.zip"
            }

            Write-Host -ForegroundColor Cyan "Zipping up files to $FileName"
            try {
                Compress-Archive -Path "$TempDir\*" -DestinationPath $FileName -ErrorAction Stop
            }
            catch {
                return PrintAndReturn "Error zipping up files to $FileName - exiting" $_
            }

            Write-Host -ForegroundColor Green "Backup created at $FileName"

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
       }
    }
}