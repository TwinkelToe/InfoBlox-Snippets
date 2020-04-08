<# 

Create a list of all domains configured in infoblox.
The TLD of each domain in noted and checked for:
HTTP 200-Ok with and without www in from of the domainname.

Results are written to CSV.

#>

$DestinationFile = Read-Host -Prompt "Destination filename?"
$Credential = Get-Credential
$ReqeustURI = "https://x.x.x.x/wapi/v2.2.2/zone_auth"

$Domeinnamen = @()

######################
##       Class      ##
######################


class Domein {
    
    [string]$Naam
    [string]$BadHost_Name
    [string]$BadHost_Name_WWW
    [string]$nl
    [string]$nu
    [string]$eu
    [string]$com
    [string]$org
    [string]$info
    [string]$net
    [string]$xxx


    Domein([string]$temp) {
        $this.Naam = $temp

    }
}


## Invoke-Rest doens't have -IgnoreInvalidSSL flag, disable SSL-check voor dit script.
function DisableSSLCheck {
Add-Type @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            ServicePointManager.ServerCertificateValidationCallback += 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;
                };
        }
    }
"@
 
    [ServerCertificateValidationCallback]::Ignore();
    
}

DisableSSLCheck;
$data = null
$data2 = null
$data = Invoke-RestMethod -Method Get -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential 

$data.fqdn | ForEach-Object {
    if (-not $_.Contains("/") ) {
        $Domeinnamen += New-Object Domein($_)
    }
}

$i = 0
$Domeinnamen | ForEach-Object {
    $Result = ""
    $_.Naam
    $split = $_.Naam -split ("\.")
    switch ($split[1]) {
        "nl" { $Domeinnamen[$i].nl = "x" }
        "nu" { $Domeinnamen[$i].nu = "x"}
        "eu" { $Domeinnamen[$i].eu = "x"}
        "com" { $Domeinnamen[$i].com = "x"}
        "org" { $Domeinnamen[$i].org = "x"}
        "info" { $Domeinnamen[$i].info = "x"}
        "net" { $Domeinnamen[$i].net = "x"}
        "xxx" { $Domeinnamen[$i].xxx = "x"}
    }
    
    $ReqeustURI = $_.Naam
    $Result = Invoke-WebRequest -Method GET -Uri $ReqeustURI
    $Result.StatusCode
    if ($Result.StatusCode -ne 200) {
        $_.BadHost_Name = "x"
    }
    Start-Sleep -Milliseconds 200

    $ReqeustURI = "www." + $_.Naam
    $Result = Invoke-WebRequest -Method GET -Uri $ReqeustURI
    $Result.StatusCode
    if ($Result.StatusCode -ne 200) {
        $_.BadHost_Name_WWW = "x"
    }
    Start-Sleep -Milliseconds 100
    $i++
}

#Output stuff
$Domeinnamen | Export-Csv -Path $DestinationFile
