#Requires -Version 5.0
Set-StrictMode -Version Latest

function CheckForAdmin() {
    if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as an Administrator. Start PowerShell with the Run as Administrator option"
    }
}
function GetOpenHABRoot() {
    param(
        [Parameter(Mandatory = $true)]
        [string] $dirName
    )

    function IsOpenHabRoot() {
        param(
            [Parameter(Mandatory = $true)]    
            [string] $dirName
        )
        return ((Test-Path "$dirName\userdata") -And (Test-Path -Path "$dirName\conf")) -Or (Test-Path -Path "$dirName\runtime");
    }
    
    if ($dirName -eq ".") {
        $dirName = $PWD
    }
    
    if (-Not (IsOpenHabRoot $dirName)) {
        $dirName = GetOpenHABDirectory "OPENHAB_HOME" ""
        if (-NOT $dirName -eq "") {
            return $dirName
        }

        $dirName = $PSScriptRoot;
        while ($dirName -ne "" -and -not(IsOpenHabRoot $dirName)) {
            $dirName = Split-Path -Path $dirName -Parent
        }
    }

    return $dirName
}

function CreateDirectory() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $itemName
    )

    New-Item -Path $itemName -ItemType directory -Force -Confirm:$False -ErrorAction Stop | Out-Null
}

function CreateFile() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $itemName
    )

    New-Item -Path $itemName -ItemType file -Force -Confirm:$False -ErrorAction Stop | Out-Null
}

function DeleteIfExists() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $itemName,
        [Parameter(Mandatory = $False)]
        [boolean] $fallback

    )

    if (Test-Path $itemName -PathType Container) {
        try {
            Remove-Item $itemName -Force -Recurse -Confirm:$False -ErrorAction Stop | Out-Null
        } catch {
            # if fallback, try to remove all the files (recursively) instead of the directory
            if ($fallback -eq $True) {
                Get-ChildItem $itemName -File -Recurse -ErrorAction Stop | Remove-Item -Force -ErrorAction Stop
            } else {
                throw $_
            }
        }
    }
    ElseIf (Test-Path $itemName) {
        # note: -Recurse because sometimes check above doesn't catch a directory for some reason
        Remove-Item $itemName -Force -Recurse -Confirm:$False -ErrorAction Stop | Out-Null
    }
}

function GetOpenHABVersion() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $OHUserData
    )

    if (Test-Path "$OHUserData\etc\version.properties" -ErrorAction SilentlyContinue) {
        $VersionLine = Get-Content "$OHUserData\etc\version.properties" -ErrorAction SilentlyContinue | Where-Object { $_.Contains("openhab-distro")} -ErrorAction SilentlyContinue
        $CurrentVersionIndex = $VersionLine.IndexOf(":")
        if ($CurrentVersionIndex -gt -1) {
            return $VersionLine.Substring($currentVersionIndex + 2)
        }
    }

    return "";
}

function GetOpenHABTempDirectory() {
    return (GetOpenHABDirectory "TEMP" "c:\temp") + "\openhab"
}

function GetOpenHABDirectory() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $environmentVariable,
        [Parameter(Mandatory = $True)]
        [AllowEmptyString()]
        [string] $defaultValue

    )
    # Check the user variables first, then the process variables then the machine variables
    $setting = "$([Environment]::GetEnvironmentVariable($environmentVariable, "User"))"
    if ($setting) {
        return $setting
    } 
    
    $setting = "$([Environment]::GetEnvironmentVariable($environmentVariable, "Process"))"
    if ($setting) {
        return $setting
    } 
    
    $setting = "$([Environment]::GetEnvironmentVariable($environmentVariable, "Machine"))"
    if ($setting) {
        return $setting
    } 
    
    return $defaultValue
}

function CheckOpenHABRunning() {
    $m = (Get-WmiObject Win32_Process -Filter "name = 'java.exe'" |
            Where-Object { $_.CommandLine.Contains("openhab") } | Measure-Object)
    if ($m.Count -gt 0) {
        throw "openHAB seems to be running, stop it before running this update script"
    }

}
function GetRelativePath() {
    param(
        [Parameter(Mandatory = $True)]
        [string] $root,
        [Parameter(Mandatory = $True)]
        [string] $absPath
    )

    $tmp = Get-Location -ErrorAction Stop 
    Set-Location $root -ErrorAction Stop 
    try {
        return Resolve-Path $absPath -Relative -ErrorAction Stop 
    }
    finally {
        Set-Location $tmp -ErrorAction Stop 
    }
}

function PrintAndReturn {
    param(
        [Parameter(Mandatory = $True)]
        [string] $msg,
        [Parameter(Mandatory = $False)]
        [System.Management.Automation.ErrorRecord] $ex,
        [Parameter(Mandatory = $False)]
        [int] $rc
    )
    BoxMessage $msg Red

    if ($ex) {
        Write-Error $ex
    }

    if ($rc) {
        return $rc
    }
    return -1
}

function PrintAndThrow {
    param(
        [Parameter(Mandatory = $True)]
        [string] $msg,
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.ErrorRecord] $ex
    )
    BoxMessage $msg Red
    Write-Error $ex

    throw $ex.Exception
}

function BoxMessage {
    param(
        [Parameter(Mandatory = $True)]
        [string] $msg,
        [Parameter(Mandatory = $True)]
        [System.ConsoleColor] $color

    )
    $pad = "#".PadRight($msg.Length + 6, "#")
    Write-Host -ForegroundColor $color $pad
    Write-Host -ForegroundColor $color "#  $msg  #"
    Write-Host -ForegroundColor $color $pad
}

Export-ModuleMember -Function "BoxMessage"
Export-ModuleMember -Function "CheckForAdmin"
Export-ModuleMember -Function "CheckOpenHABRunning"
Export-ModuleMember -Function "CreateDirectory"
Export-ModuleMember -Function "CreateFile"
Export-ModuleMember -Function "DeleteIfExists"
Export-ModuleMember -Function "GetOpenHABRoot"
Export-ModuleMember -Function "GetOpenHABTempDirectory"
Export-ModuleMember -Function "GetOpenHABDirectory"
Export-ModuleMember -Function "GetOpenHABVersion"
Export-ModuleMember -Function "GetRelativePath"
Export-ModuleMember -Function "PrintAndReturn"
Export-ModuleMember -Function "PrintAndThrow"
