<#

Modified version of Invoke-ReduceDHCPScope

When migrating our network we had to reduces all the DHCP ranges to make room for gateways. But we had fixed IP's that would overlap with new gateways. 
This script tries to find the fixed IP's that overlap. 

Querys all the fixed IP configured in infoblox. Then counts down from the broadcat and matches the adresses against the fixed IP. So:
subnet: 10.10.10.0/24
Range: 10.10.10.1 - 10.10.10.253

The following IP's have to be free: 10.10.10.254, 10.10.10.253, 10.10.10.252, 10.10.10.251. If a host is configured to use one of these IP's it will me listed.

Supports /21 to /28
#>
# Setup #
$hostFreefromDHCP = 4 # How many hosts counting down from broadcast have to be free. eg: 4 means 10.10.10.254, 10.10.10.253, 10.10.10.252, 10.10.10.251 have to be free.
$InfobloxURL = "https://x.x.x.x/wapi/v2.2.2/"
$Credential = Get-Credential


## Invoke-Rest kent geen -IgnoreInvalidSSL flag, disable SSL-check voor dit script.
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

$FixedRecordList = @()


function Get-BroadcastAddress
{
   
    param
    (
    [Parameter(Mandatory=$true)]
    $IPAddress,
    $SubnetMask
    )

    filter Convert-IP2Decimal
    {
        ([IPAddress][String]([IPAddress]$_)).Address
    }


    filter Convert-Decimal2IP
    {
    ([System.Net.IPAddress]$_).IPAddressToString 
    }


    [UInt32]$ip = $IPAddress | Convert-IP2Decimal
    [UInt32]$subnet = $SubnetMask | Convert-IP2Decimal
    [UInt32]$broadcast = $ip -band $subnet 
    $broadcast -bor -bnot $subnet | Convert-Decimal2IP
}


DisableSSLCheck;

try {
    $ReqeustURI = $InfobloxURL + "fixedaddress?_return_fields%2b=network,mac,name,comment"
    $Result = Invoke-RestMethod -Method Get -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential
} catch {
    $error[0]
    exit
}

if ($Result) {
    $Result | ForEach-Object {
        $Subnet = 0
        $Network = $_.network -split "/"
        if ($Network[1] -eq "24") {
            $Subnet = "255.255.255.0"
        } elseif ($Network[1] -eq "25") {
            $Subnet = "255.255.255.128"
        } elseif ($Network[1] -eq "26") {
            $Subnet = "255.255.255.192"
        } elseif ($Network[1] -eq "27") {
            $Subnet = "255.255.255.224"
        } elseif ($Network[1] -eq "28") {
            $Subnet = "255.255.255.240"
        } elseif ($Network[1] -eq "23") {
            $Subnet = "255.255.254.0"
        } elseif ($Network[1] -eq "22") {
            $Subnet = "255.255.252.0"
        } elseif ($Network[1] -eq "21") {
            $Subnet = "255.255.248.0"
        }
        if ($Subnet -eq 0) {
            "Geen subnet gevonden!~"
            exit
        }
        $BroadCast = Get-BroadcastAddress -IPAddress $Network[0] -SubnetMask $Subnet
        $BroadcastBits = $BroadCast -split "\."
        for ($i = 0; $i -lt $($hostFreefromDHCP - 1); $i++){
            $BroadcastBits[3] = $BroadcastBits[3] - 1
            $dump = $BroadcastBits -join "."
            $Result | Where-Object ipv4addr -Match $dump
        }
         
    }


    $Result | Out-GridView
}
# Push update # 
<#
$Result | ForEach-Object {
    if ( $Result.network -match $IpRangeToMatch ) {
        "Found ref: " + $_._ref
        
    }
}
    $Result | Where-Object ipv4addr -Match ".+\..+\..+\.252"
    $Result | Where-Object ipv4addr -Match ".+\..+\..+\.253"    
    $Result | Where-Object ipv4addr -Match ".+\..+\..+\.254"
#>