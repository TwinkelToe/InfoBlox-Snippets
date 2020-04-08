<# 
When migrating our network we had to reduces all the DHCP ranges to make room for gateways.
Query's all configued DHCP ranges. Gets the broadcast address and counts down to looks if it overlaps. So:
Inital DHCP range:
subnet: 10.10.10.0/24
Range: 10.10.10.1 - 10.10.10.253

The following IP's have to be free: 10.10.10.254, 10.10.10.253, 10.10.10.252, 10.10.10.251

The new end adress that will be written back: 10.10.10.250

Supports /21 to /28
#>

# Setup # - 
$IpRangeToMatch = ""
$Credential = Get-Credential
$ApplyChanges = $false # !!!True is commit changes otherwise functions as -whatif!!!
$hostFreefromDHCP = 4 # How many hosts counting down from broadcast have to be free. eg: 4 means 10.10.10.254, 10.10.10.253, 10.10.10.252, 10.10.10.251 have to be free.
$InfobloxURL = "https://x.x.x.x/wapi/v2.2.2/"

$ChangeCounter = 0

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

# Got this from somewhere but lost the source...
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
    $ReqeustURI = $InfobloxURL + "range"
    $Result = Invoke-RestMethod -Method Get -Uri $ReqeustURI -Credential $Credential
} catch {
    $error[0]
    exit
}

if ($Result) {
    $Result | ForEach-Object {
        # This can be done better...
        $Subnet = 0
        "------------------------------"
        "Checking " + $_.network
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
            "Not subnet found!~"
            exit
        }
        $BroadCast = Get-BroadcastAddress -IPAddress $Network[0] -SubnetMask $Subnet
        "Broadcast for this subnet: " + $BroadCast
        $HaveToChcange = $false
        "Must be free:"
        $BroadcastBits = $BroadCast -split "\."
        for ($i = 0; $i -lt $($hostFreefromDHCP -1); $i++){
            $BroadcastBits[3] = $BroadcastBits[3] - 1
            $dump = $BroadcastBits -join "."
            $dump
            
            if ($_.end_addr -eq $dump){
                $HaveToChcange = $true
                write-host "Address $($_.end_addr) is within current DHCP scope of network $($_.network)." -BackgroundColor Magenta
                #$_.network
                break
            }
        }
        if (-not $HaveToChcange){
            write-host "Network $($_.network) is good, no changed needed" -BackgroundColor Green
        }
        if ($ApplyChanges -and $HaveToChcange){
            "Saving Changes to infoblox...."

            # Opnieuw berekenen want lui enzo
            $BroadcastBits = $BroadCast -split "\."
            $BroadcastBits[3] = $BroadcastBits[3] - $hostFreefromDHCP
            $NewEndAddr = $BroadcastBits -join "."

            $data = ""
            $ReqeustURI = $InfobloxURL + $_._ref

            $JsonBody = '{"end_addr": "' + $NewEndAddr + '"}'
            "Update: " + $JsonBody

            #start-sleep -Seconds 20 # Failsave just in case...
            try {
                $data = Invoke-RestMethod -Method Put -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential -ContentType "application/json" -Body $JsonBody
                $ChangeCounter++
            } catch {
                $error[0]
                exit # Crash gentle.. xD
            }
            "Infoblox bijgewerkt"            
            if ($ChangeCounter -eq 50){
                break
            }
        
        }         
    }
    $Result | Out-GridView
}

"Totaal changes: $ChangeCounter"