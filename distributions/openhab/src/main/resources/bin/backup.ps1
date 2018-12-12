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
    .PARAMETER MaxFiles
    The maximum number of files to keep
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
        [string]$FileName,
        [Parameter(ValueFromPipeline = $True)]
        [int]$MaxFiles
    )

    begin {}
    process {

        Import-Module $PSScriptRoot\common.psm1 -Force

        Write-Host ""
        BoxMessage "openHAB 2.x.x backup script" Magenta
        Write-Host ""

        # Check for admin (commented out - don't think we need it)
        # CheckForAdmin

        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory"
        $OHDirectory = GetOpenHABRoot $OHDirectory
        if ($OHDirectory -eq "") {
            exit PrintAndReturn "Could not find the userdata directory! Make sure you are in the openHAB directory or specify the -OHDirectory parameter!"
        }
    
        $OHConf = GetOpenHABDirectory "OPENHAB_CONF" "$OHDirectory\conf"
        $OHUserData = GetOpenHABDirectory "OPENHAB_USERDATA" "$OHDirectory\userdata"
        $OHRuntime = GetOpenHABDirectory "OPENHAB_RUNTIME" "$OHDirectory\runtime"

        if ([string]::IsNullOrEmpty($OHBackups)) {
            $OHBackups = GetOpenHABDirectory "OPENHAB_BACKUPS" "$OHDirectory\backups"
        }

        if (-NOT (Test-Path -Path $OHConf -PathType Container)) {
            exit PrintAndReturn "Configuration directory does not exist:  $OHConf"
        }

        if (-NOT (Test-Path -Path $OHUserData -PathType Container)) {
            exit PrintAndReturn "Userdata directory does not exist:  $OHUserData"
        }
        
        if (-NOT (Test-Path -Path $OHRuntime -PathType Container)) {
            exit PrintAndReturn "Runtime directory does not exist:  $OHRuntime"
        }
        
        if (-NOT (Test-Path -Path $OHBackups -PathType Container)) {
            try {
                Write-Host -ForegroundColor Cyan "Creating backup directory $OHBackups"
                CreateDirectory $OHBackups
            }
            catch {
                exit PrintAndReturn "Error creating backup directory $OHBackups - exiting" $_
            }
        }

        Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
        Write-Host -ForegroundColor Yellow "Using $OHUserData as userdata folder"
        Write-Host -ForegroundColor Yellow "Using $OHBackups as backups folder"
        Write-Host -ForegroundColor Yellow "Using $OHRuntime as runtime folder"

        $TempDir = "$(GetOpenHABTempDirectory)\backup"

        try {
            Write-Host -ForegroundColor Cyan "Creating temporary backup directory $TempDir"
            CreateDirectory $TempDir
        }
        catch {
            exit PrintAndReturn "Error creating temporary backup directory $TempDir - exiting" $_
        }

        try {
            $CurrentVersion = GetOpenHABVersion $OHUserData
            if ($CurrentVersion -eq "") {
                exit PrintAndReturn "Can't get the current openhab version from $OHDirectory - exiting"
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
                exit PrintAndReturn "Can't create the temporary backup.properties file in $TempDir - exiting" $_
            }

            Write-Host -ForegroundColor Cyan "Copying userdata and conf folder contents to temp directory"
            try {
                Copy-Item $OHUserData $TempDir -Recurse -ErrorAction Stop
                Copy-Item $OHConf $TempDir -Recurse -ErrorAction Stop
            }
            catch {
                exit PrintAndReturn "Can't copy the userdata/conf directory to the temporary directory $TempDir - exiting" $_
            }

            try {
                Write-Host -ForegroundColor Cyan "Removing unnecessary files"
                foreach ($sysFile in Get-Content "$OHRuntime\bin\userdata_sysfiles.lst") {
                    DeleteIfExists "$TempDir\userdata\etc\$sysFile"
                }
                DeleteIfExists "$TempDir\userdata\cache" $True
                DeleteIfExists "$TempDir\userdata\tmp" $True

                Write-Host -ForegroundColor Cyan "Removing backup folder from backup userdata if it exists"
                DeleteIfExists "$TempDir\userdata\backups" $True
            }
            catch {
                exit PrintAndReturn "Error removing unnecessary files from $TempDir - exiting" $_
            }

            if ([string]::IsNullOrEmpty($FileName)) {
                $FileName = "$OHBackups\openhab2-backup-$timestamp.zip"
            } else {
                if (-NOT $FileName.EndsWith(".zip")) {
                    $FileName = $FileName + ".zip";
                }

                if ((Split-Path -Path $FileName) -eq "") {
                    $FileName = "$OHBackups\$FileName"
                }
            }

            if (Test-Path -Path $FileName) {
                Write-Host -ForegroundColor Yellow "Backup file $FileName already exists!"
                $confirmation = Read-Host "Do you wish to overwrite that file? [y/N]"
                if ($confirmation -ne 'y') {
                    exit PrintAndReturn "Cancelling backup"
                }
                DeleteIfExists $FileName
            }

            Write-Host -ForegroundColor Cyan "Zipping up files to $FileName"
            try {
                Compress-Archive -Path "$TempDir\*" -DestinationPath $FileName -ErrorAction Stop
            }
            catch {
                exit PrintAndReturn "Error zipping up files to $FileName - exiting" $_
            }

            Write-Host -ForegroundColor Green "Backup created at $FileName"

            if ($MaxFiles -gt 0) {
                Write-Host -ForegroundColor Cyan "Keeping only the last $MaxFiles backups"
                Get-ChildItem -Path $OHBackups -Filter *.zip | Sort LastWriteTime -Descending | Select -Skip $MaxFiles | %{
                    Write-Host -ForegroundColor Cyan "Deleting $_"
                    DeleteIfExists $_.FullName
                }
            }
        }
        catch {
            # No printandthrows so we are catching an unknown error
            exit PrintAndReturn "Exception occurred backing up file" $_
        }
        finally {
            $parent = (Get-Item $TempDir).Parent.FullName

            try {
                Write-Host -ForegroundColor Cyan "Removing temporary directory $TempDir"
                DeleteIfExists $TempDir $True
            }
            catch {
                Write-Host -ForegroundColor Red "Could not delete $TempDir - delete it manually"
            }

            try {
                if (-Not (Test-Path "$parent\*")) {
                    Write-Host -ForegroundColor Cyan "Removing temporary directory $parent"
                    DeleteIfExists $parent $True
                }
            }
            catch {
                Write-Host -ForegroundColor Red "Could not delete $parent - delete it manually"
            }
       }
    }
}