[CmdletBinding()]
param
(
	[Parameter(Mandatory=$true)] [string]$serverEnv,
    [Parameter(Mandatory=$true)] [string]$octopusEnv,
    [Parameter(Mandatory=$true)] [string]$serverRegion,
    [Parameter(Mandatory=$true)] [string]$serverRole,
	[Parameter(Mandatory=$true)] [string]$SAS
)

#region CONSTANTS
    $logDir = "C:\logs"
    $oselDir = "c:\OSEL"
    $rootStgContainer = "https://oriflamestorage.blob.core.windows.net/onlineassets"
    $oselRes = "osel.zip"
    $cfgJson = "config.json"
#endregion


#logging preparation
    if (!(test-path $logDir)) { mkdir $logDirs | Out-Null }

    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
    $currentScriptFolder = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
    $logFile = "$logDir\$scriptName.txt"

function LogToFile( [string] $text )
{
    $date = Get-Date -Format s
    "$date: $text" | Out-File $logFile -Append
}


#start
    LogToFile "Current folder $currentScriptFolder" 
    Add-Type -AssemblyName System.IO.Compression.FileSystem

try
{
#enable samba    
    LogToFile "Enabling Samba" 
    netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes

    $sasDecoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($SAS))
    $serverEnv = $serverEnv.Replace("_", " ")
    $octopusEnv = $octopusEnv.Replace("_", " ")
    $serverRole = $serverRole.Replace("_NA_", "")


    LogToFile "Server environment: $serverEnv" 
    LogToFile "Octopus environment: $octopusEnv" 
    LogToFile "Server region: $serverRegion" 
    LogToFile "Server role: $serverRole" 
    LogToFile "SAS token: $sasDecoded" 

#persist parameters in the Osel Dir
    if (!(test-path $oselDir)) {mkdir $oselDir }
    LogToFile "saving parameters as config file $oselDir\$cfgJson" 
    @{ env=$serverEnv;
       octopusEnv=$octopusEnv;
       region=$serverRegion;
       role=$serverRole;
       SAS=$SAS } | 
                ConvertTo-Json | 
                Out-File "$oselDir\$cfgJson"

#download resource storage
    $url = "$rootStgContainer/$serverEnv/$oselRes"
    LogToFile "downloading OSEL: $url" 
    (New-Object System.Net.WebClient).DownloadFile("$url$sasDecoded", "$oselDir\$oselRes")

#unzip
    LogToFile "unziping OSEL to [$oselDir]"   
    [System.IO.Compression.ZipFile]::ExtractToDirectory "$oselDir\$oselRes" $oselDir

#exec init-server    
    LogToFile "starting OSEL init-server.ps1" 
    Set-Location "$oselDir\StandAloneScripts\ServerSetup\"
    & .\init-server.ps1 -step new-server

#done    
    LogToFile "OSEL init-server finished" 
}
catch
{
	LogToFile "An error ocurred: $_" 
}
