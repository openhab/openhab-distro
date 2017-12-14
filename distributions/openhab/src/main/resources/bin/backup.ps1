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
    .PARAMETER ZipFileOut
    The name of the zip file to create
    .EXAMPLE
    Backup an openHAB instance to a zip file
    Backup-openHAB
    .EXAMPLE
    Backup the openHAB distribution in the C:\openHAB2 directory to c:\openHAB2-backup\backup.zip
    Backup-openHAB -OHDirectory C:\openHAB2 -OHBackups c:\openHAB2-backup -ZipFileOut backup.zip
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$OHDirectory = ".",
        [Parameter(ValueFromPipeline=$True)]
        [string]$OHBackups,
        [Parameter(ValueFromPipeline=$True)]
        [string]$ZipFileOut
    )

    begin {}
    process {

        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This script must be run as an Administrator. Start PowerShell with the Run as Administrator option"
        }

        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory..."
        if (!(Test-Path "$OHDirectory\userdata") -And !(Test-Path -Path "$OHDirectory\conf")) {
            throw "$OHDirectory\userdata doesn't exist! Make sure you are in the " +
                "openHAB directory or specify the -OHDirectory parameter!"
        }

        if ($OHDirectory -eq '.') {$OHDirectory = pwd }

        if ([Environment]::GetEnvironmentVariable("OPENHAB_CONF", "Machine")) {
            $OHConf = [Environment]::GetEnvironmentVariable("OPENHAB_CONF", "Machine")
        } else {
            $OHConf = "$OHDirectory\conf"
        }
        if ([Environment]::GetEnvironmentVariable("OPENHAB_USERDATA", "Machine")) {
            $OHUserdata = [Environment]::GetEnvironmentVariable("OPENHAB_USERDATA", "Machine")
        } else {
            $OHUserdata = "$OHDirectory\userdata"
        }
        if (!($OHBackups)) {
            if ([Environment]::GetEnvironmentVariable("OPENHAB_BACKUPS", "Machine")) {
                $OHBackups = [Environment]::GetEnvironmentVariable("OPENHAB_BACKUPS", "Machine")
            } else {
                $OHBackups = "$OHDirectory\backups"
                if (!(Test-Path "$OHDirectory\backups")){
                    mkdir "$OHBackups" | Out-Null
                }
            }
        }

        Write-Host -ForegroundColor Yellow "Using $OHConf as conf folder"
        Write-Host -ForegroundColor Yellow "Using $OHUserdata as userdata folder"
        Write-Host -ForegroundColor Yellow "Using $OHBackups as backups folder"

        $TempDir=([Environment]::GetEnvironmentVariable("TEMP", "Machine"))+"\openhab"
        New-Item $TempDir -Type directory -Force | Out-Null

        $VersionLine = Get-Content "$OHDirectory\userdata\etc\version.properties" | Where-Object { $_.Contains("openhab-distro")}
        $CurrentVersionIndex = $VersionLine.IndexOf(":")
        $CurrentVersion = $VersionLine.Substring($currentVersionIndex + 2)
        $timestamp = Get-Date -Format yyyyMMddHHmm
        Write-Output "version=$CurrentVersion" | Set-Content "$TempDir\backup.properties"
        Write-Output "timestamp=$timestamp" | Add-Content "$TempDir\backup.properties"
        Write-Output "user=openhab" | Add-Content "$TempDir\backup.properties"
        Write-Output "group=openhab" | Add-Content "$TempDir\backup.properties"
        
        Write-Host -ForegroundColor Cyan "Copying userdata and conf folder contents to temp directory"
        mkdir "$TempDir\userdata" | Out-Null
        Copy-Item $OHUserdata $TempDir -Recurse -Force
        mkdir "$TempDir\conf" | Out-Null
        Copy-Item $OHConf $TempDir -Recurse -Force

        Write-Host -ForegroundColor Cyan "Removing unnecessary files..."
        Remove-Item ($TempDir + '\userdata\etc\all.policy') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\branding.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\branding-ssh.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\config.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\custom.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\distribution.info') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\jre.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\org.ops4j.pax.url.mvn.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\profile.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\startup.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\version.properties') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\etc\org.apache.karaf*') -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\cache') -Recurse -ErrorAction SilentlyContinue
        Remove-Item ($TempDir + '\userdata\tmp') -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Cyan "Removing backup folder from backup userdata if it exists..."
        if (Test-Path "$TempDir\userdata\backups") {Remove-Item "$TempDir\userdata\backups" -Recurse -ErrorAction SilentlyContinue}

        Write-Host -ForegroundColor Cyan "Zipping up files..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if (!($ZipFileOut)) {$ZipFileOut = "$OHBackups\openhab2-backup-$timestamp.zip"}
        [System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipFileOut)

        Write-Host -ForegroundColor Cyan "Removing temp files..."
        Remove-Item $TempDir -Recurse -ErrorAction SilentlyContinue
        
        Write-Host -ForegroundColor Green "Backup created at $OHBackups\openhab2-backup-$timestamp.zip"
    }
}