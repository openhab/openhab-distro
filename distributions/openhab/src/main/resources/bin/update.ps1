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
        [boolean]$Snapshot = $false
    )


    begin {}
    process {

        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "This script must be run as an Administrator. Start PowerShell with the Run as Administrator option"
        }

        Write-Host -ForegroundColor Cyan "Checking whether a service exists..."
        $service = (Get-WmiObject Win32_Service -filter "name='openHAB2'")
        if ($service) {
            # Stop the service
            Write-Host -ForegroundColor Cyan "Stopping the service..."
            Stop-Service openHAB2 -Force

            Write-Host -ForegroundColor Cyan "Deleting the service..."
            $service.Delete()
        }

        Write-Host -ForegroundColor Cyan "Checking the specified openHAB directory..."
        if (!(Test-Path "$OHDirectory/userdata")) {
            throw "$OHDirectory/userdata doesn't exist! Make sure you are in the " +
                "openHAB directory or specify the -OHDirectory parameter!"
        }

        Write-Host -ForegroundColor Cyan "Checking whether openHAB is running..."
        $m = (Get-WmiObject Win32_Process -Filter "name = 'java.exe'" |
              where { $_.CommandLine.Contains("openhab") } | measure)
        if ($m.Count -gt 0) {
            throw "openHAB seems to be running, stop it before running this update script"
        }

        # Download the selected openHAB version
        ## Choose bintray for releases, cloudbees for snapshot.
        Import-Module BitsTransfer

        if ($Snapshot) {
            $OHVersion = "$OHVersion-SNAPSHOT"
            $DownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target/openhab-$OHVersion.zip"
            #$AddonsDownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons/target/openhab-addons-$OHVersion.kar"
            #$LegacyAddonsDownloadLocation="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-addons-legacy/target/openhab-addons-legacy-$OHVersion.kar"
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersion distribution (snapshot)..."
            Invoke-WebRequest -Uri $DownloadLocation -OutFile "openhab-$OHVersion.zip"
        } else {
            $DownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab%2F$OHVersion%2Fopenhab-$OHVersion.zip"
            #$AddonsDownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons%2F$OHVersion%2Fopenhab-addons-$OHVersion.kar"
            #$LegacyAddonsDownloadLocation="https://bintray.com/openhab/mvn/download_file?file_path=org%2Fopenhab%2Fdistro%2Fopenhab-addons-legacy%2F$OHVersion%2Fopenhab-addons-legacy-$OHVersion.kar"
            Write-Host -ForegroundColor Cyan "Downloading the openHAB $OHVersion distribution (release)..."
            Start-BitsTransfer $DownloadLocation -Destination "openhab-$OHVersion.zip"
        }

        if (!(Test-Path "openhab-$OHVersion.zip")) {
            throw "Couldn't download the archive, aborting"
        }

        Write-Host -ForegroundColor Cyan "Making a backup in $OHDirectory\backup..."
        mkdir backup | Out-Null
        Copy-Item $OHDirectory\conf $OHDirectory\backup\conf -Recurse -Force
        Copy-Item $OHDirectory\runtime $OHDirectory\backup\runtime -Recurse -Force
        Copy-Item $OHDirectory\userdata $OHDirectory\backup\userdata -Recurse -Force

        Write-Host -ForegroundColor Cyan "Extracting the archive to $OHDirectory\openhab-$OHVersion..."
        Remove-Item $OHDirectory\openhab-$OHVersion -Recurse -ErrorAction Ignore
        Expand-Archive openhab-$OHVersion.zip -DestinationPath $OHDirectory\openhab-$OHVersion

        # Delete current userdata files
        Write-Host -ForegroundColor Cyan "Deleting current files in userdata that should not persist..."
        $userdata = $OHDirectory + "\userdata"
        Remove-Item ($userdata + '\etc\all.policy') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\branding.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\branding-ssh.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\config.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\custom.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\distribution.info') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\jre.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\profile.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\startup.properties') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\org.apache.karaf*') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\etc\org.ops4j.pax.url.mvn.cfg') -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\cache') -Recurse -ErrorAction SilentlyContinue
        Remove-Item ($userdata + '\tmp') -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Cyan "Deleting current runtime..."
        Remove-Item ($OHDirectory + '\runtime') -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Cyan "Copying new runtime..."
        Copy-Item $OHDirectory\openhab-$OHVersion\runtime -Destination $OHDirectory\runtime -Force -Recurse

        Write-Host -ForegroundColor Cyan "Copying userdata files to new install without overwriting existing ones..."
        $newuserdata = Get-Item $OHDirectory\openhab-$OHVersion\userdata
        #robocopy /xc /xo $newuserdata $userdata
        Get-ChildItem -Path $newuserdata -Recurse | Copy-Item -Destination {
            if ($_.PSIsContainer) {
                $path = Join-Path $userdata $_.Parent.FullName.Substring($newuserdata.FullName.Length)
                #Write-Host $path
                $path
            } else {
                $path = Join-Path $userdata $_.FullName.Substring($newuserdata.FullName.Length)
                #Write-Host $path
                $path
            }
        } -ErrorAction SilentlyContinue | Out-Null

        Write-Host -ForegroundColor Cyan "Removing the extracted files..."
        Remove-Item $OHDirectory\openhab-$OHVersion -Recurse -ErrorAction SilentlyContinue

        Write-Host -ForegroundColor Green "openHAB updated to version $OHVersion!"
        Write-Host -ForegroundColor Green "Run start.bat to launch it."
        Write-Host -ForegroundColor Green "Check http://docs.openhab.org/installation/windows.html "
        Write-Host -ForegroundColor Green "for instructions on re-installing the Windows Service if desired"
    }

}
