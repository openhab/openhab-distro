#Requires -Version 4.0
function DownloadFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DownloadSource,
        [Parameter(Mandatory=$true)]
        [string]$Outputfile,
        [Parameter(Mandatory=$false)]
        [string]$SkipNew
    )

    $uri = New-Object "System.Uri" "$DownloadSource"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000)
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $Outputfile, Create
    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    while ($count -gt 0)
    {
        [System.Console]::CursorLeft = 0
        [System.Console]::Write("Downloaded {0}K of {1}K", [System.Math]::Floor($downloadedBytes/1024), $totalLength)
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
    }
    Write-Host "`nFinished Download"
    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()

    if ($SkipNew -eq $false)
    {
        # Check for newer update.ps1
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($Outputfile)
        $update = $zip.Entries | where {$_.FullName -like 'runtime/bin/update.ps1'}

        if ($update)
        {
            $newUpdate = Join-Path $TempDir $update.Name
            [IO.Compression.ZipFileExtensions]::ExtractToFile($update, $newUpdate)
            Write-Host -ForegroundColor Red "==================================="
            Write-Host -ForegroundColor Red "New Update.ps1 found. Using that..."
            Write-Host -ForegroundColor Red "==================================="
            $zip.Dispose()
            Remove-Item $OutputFile -Force
            . $newUpdate
            Update-openHAB -OHDirectory $OHDirectory -OHVersion $OHVersion -Snapshot $Snapshot -SkipNew $true
            Return 2
        }
        $zip.Dispose()
    }
}

Function Update-openHAB {
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
    .PARAMETER SkipNew
    Internal use only. For skipping the check for a new update.ps1
    .EXAMPLE
    Update the openHAB distribution in the current directory to the current stable version
    Update-openHAB
    .EXAMPLE
    Update the openHAB distribution in the C:\oh-snapshot directory to the next snapshot version
    Update-openHAB -OHDirectory C:\oh-snapshot -OHVersion 2.2.0 -Snapshot $true
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$OHDirectory = ".",
        [Parameter(ValueFromPipeline=$True)]
        [string]$OHVersion = "2.1.0",
        [Parameter(ValueFromPipeline=$True)]
        [boolean]$Snapshot = $false,
        [Parameter(ValueFromPipeline=$True)]
        [boolean]$SkipNew = $false
    )

    begin {}
    process {

        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This script must be run as an Administrator. Start PowerShell with the Run as Administrator option"
        }

        # Verify we're in an openHAB directory
        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory..."
        if (!(Test-Path "$OHDirectory\userdata") -And !(Test-Path -Path "$OHDirectory\conf")) {
            throw "$OHDirectory\userdata doesn't exist! Make sure you are in the " +
                "openHAB directory or specify the -OHDirectory parameter!"
        }


        # Get current openHAB version
        if (Test-Path "$OHDirectory\userdata\etc\version.properties")
        {
            $VersionLine = Get-Content "$OHDirectory\userdata\etc\version.properties" | Where-Object { $_.Contains("openhab-distro")}
            $CurrentVersionIndex = $VersionLine.IndexOf(":")
            $CurrentVersion = $VersionLine.Substring($currentVersionIndex + 2)
            if ($OHVersion -eq $CurrentVersion) {
                throw "You are already on openHAB $OHVersion"
            }
        }


        # Check if service is installed, stop and delete it
        Write-Host -ForegroundColor Cyan "Checking whether a service exists..."
        $service = (Get-WmiObject Win32_Service -filter "name LIKE 'openHAB%'")
        if ($service) {
            # Stop and delete the service
            Write-Host -ForegroundColor Cyan "Stopping the service..."
            Stop-Service $service.Name -Force
            Write-Host -ForegroundColor Cyan "Deleting the service..."
            $service.Delete()
        }
        

        # Checking if openHAB is running
        Write-Host -ForegroundColor Cyan "Checking whether openHAB is running..."
        $m = (Get-WmiObject Win32_Process -Filter "name = 'java.exe'" |
              where { $_.CommandLine.Contains("openhab") } | measure)
        if ($m.Count -gt 0) {
            throw "openHAB seems to be running, stop it before running this update script"
        }


        # Backup openHAB only if not coming via new update script
        if ($SkipNew -eq $false)
        {
            Write-Host ""
            Write-Host -ForegroundColor Magenta "Backup script starting..."
            Write-Host -ForegroundColor Cyan "Making a backup in '$OHDirectory\backups' ..."
            $BackupScript = Join-Path (pwd) '\runtime\bin\backup.ps1'
            . $BackupScript
            Backup-openHAB -OHDirectory (pwd)
            Write-Host -ForegroundColor Magenta "Backup script finished."
            Write-Host ""
        }


        # Set the temporary directories
        $TempDir=([Environment]::GetEnvironmentVariable("TEMP", "Machine"))+"\openhab"
        $OutputFile = "$TempDir\openhab-$OHVersion.zip"
        if (Test-Path $TempDir)
        {
            Remove-Item $TempDir -Recurse
        }
        New-Item $TempDir -Type directory -Force | Out-Null


        # Download the selected openHAB version
        # Choose bintray for releases, cloudbees for snapshot.
        if ($Snapshot) {
            $OHVersion = "$OHVersion-SNAPSHOT"
            $DownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$OHVersion.zip"
            $AddonsDownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons/target/openhab-addons-$OHVersion.kar"
            $LegacyAddonsDownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons-legacy/target/openhab-addons-legacy-$OHVersion.kar"
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersion distribution..."
            $DL = DownloadFiles $DownloadLocation "$TempDir\openhab-$OHVersion.zip" $SkipNew
            if ($DL -eq 2) {Return}
        } else {
            $DownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab%2F$OHVersion%2Fopenhab-$OHVersion.zip"
            $AddonsDownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons%2F$OHVersion%2Fopenhab-addons-$OHVersion.kar"
            $LegacyAddonsDownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons-legacy%2F$OHVersion%2Fopenhab-addons-legacy-$OHVersion.kar"
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersion distribution..."
            $DL = DownloadFiles $DownloadLocation "$TempDir\openhab-$OHVersion.zip" $SkipNew
            if ($DL -eq 2) {Return}
        }


        # Unzip new files
        Write-Host -ForegroundColor Cyan "Extracting the archive to $TempDir\openhab-$OHVersion..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$TempDir\openhab-$OHVersion.zip", "$TempDir\openhab-$OHVersion")


        # Delete current userdata files
        Write-Host -ForegroundColor Cyan "Deleting current files in userdata that should not persist..."
        Remove-Item ($OHDirectory + '\userdata\etc\all.policy') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\branding.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\branding-ssh.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\config.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\custom.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\distribution.info') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\jre.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\org.ops4j.pax.url.mvn.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\profile.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\startup.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\version.properties') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\etc\org.apache.karaf*') -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\cache') -Recurse -ErrorAction SilentlyContinue
        Remove-Item ($OHDirectory + '\userdata\tmp') -Recurse -ErrorAction SilentlyContinue


        # Keep a backup of this file in case the user modified it
        Copy-Item ($OHDirectory + '\userdata\etc\org.ops4j.pax.logging.cfg') ($OHDirectory + '\userdata\etc\org.ops4j.pax.logging.cfg.bak')


        # Update openHAB
        Write-Host -ForegroundColor Cyan "Deleting current runtime..."
        Remove-Item ($OHDirectory + '\runtime') -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Cyan "Copying new runtime..."
        Copy-Item $TempDir\openhab-$OHVersion\runtime -Destination $OHDirectory\runtime -Force -Recurse

        Write-Host -ForegroundColor Cyan "Copying userdata files to new install without overwriting existing ones..."
        $newuserdata = Get-Item $TempDir\openhab-$OHVersion\userdata
        Get-ChildItem -Path $newuserdata -Recurse | Copy-Item -Destination {
            if ($_.PSIsContainer) {
                $path = Join-Path "$OHDirectory\userdata" $_.Parent.FullName.Substring($newuserdata.FullName.Length)
                #Write-Host $path
                $path
            } else {
                $path = Join-Path "$OHDirectory\userdata" $_.FullName.Substring($newuserdata.FullName.Length)
                #Write-Host $path
                $path
            }
        } -ErrorAction SilentlyContinue | Out-Null


        # If there's an existing addons file, we need to replace it with the correct version.
        $AddonsFile="$OHDirectory\addons\openhab-addons-$CurrentVersion.kar"
        if (Test-Path -Path $AddonsFile) {
            Write-Host "Found an openHAB addons file, replacing with new version..."
            Remove-Item $AddonsFile
            DownloadFiles $AddonsDownloadLocation "$OHDirectory\addons\openhab-addons-$OHVersion.kar"
        }


        # Do the same for the legacy addons file.
        $LegacyAddonsFile="$OHDirectory\addons\openhab-addons-legacy-$CurrentVersion.kar"
        if (Test-Path -Path $LegacyAddonsFile) {
            Write-Host "Found an openHAB legacy addons file, replacing with new version..."
            Remove-Item $LegacyAddonsFile
            DownloadFiles $LegacyAddonsDownloadLocation "$OHDirectory\addons\openhab-addons-legacy-$OHVersion.kar"
        }


        # Delete Temp Directory
        Write-Host -ForegroundColor Cyan "Removing the extracted files..."
        Remove-Item $TempDir -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Green "openHAB updated to version $OHVersion!"
        Write-Host -ForegroundColor Green "Run start.bat to launch it."
        Write-Host -ForegroundColor Green "Check http://docs.openhab.org/installation/windows.html "
        Write-Host -ForegroundColor Green "for instructions on re-installing the Windows Service if desired"
    }

}
