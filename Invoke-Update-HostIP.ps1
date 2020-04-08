<#

Replaces the IP adress in a hostrecord on Infoblox. 
When migrating to a different hosting profider we had to change the IP-adress of 60+ hostrecords. We could not find a way in the webinterface to accomplish this task.

Note: minimal error handeling.

#>

#Ask infoblox login cred.
$Credential = Get-Credential

#Commit changes? Otherwise functions as -whatif. (As boolean)
$DirectChange = $true

#Update TTL, TTL in seconds. 0 = no change. (as int) - ignores DirectChange so you can lower the TTL before the migration.
$UpdateTTL = 0

#Old IP and New IP of host. (string)
$OudeIPAddr = "x.x.x.x"
$NieuweIPAddr = "x.x.x.x"

$InfoBloxURL = "https://x.x.x.x/wapi/v2.2.2/"

# Aanmaken Array #
$Hosts = @()


######################
##       Class      ##
######################

class Host {
    [string]$Hostname
    [string]$ref
    [string]$ip4addr

    Host([string]$temp, $temp1, $temp2) {
        $this.Hostname = $temp
        $this.ip4addr = $temp1
        $this.ref = $temp2
    }
}


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

DisableSSLCheck;

# Query hostrecords with old IP.
$data = null
$ReqeustURI = $($InfoBloxURL + "record:host?ipv4addr=" + $OudeIPAddr)
$data = Invoke-RestMethod -Method Get -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential 

# Write each host to an array. (Hostname, IP addr en refnubmer) 
$data | ForEach-Object {
    # / to remove IP host.
    if (-not $_.ipv4addrs.host.Contains("/") ) {
        $Hosts += New-Object Host($_.ipv4addrs.host, $_.ipv4addrs.ipv4addr, $_._ref)
        "Host: " + $_.ipv4addrs.host
    }
}

# Print found host as FYI
$Hosts

# Change TTL when asked.
if ( $UpdateTTL -ne 0 ) {
    " "
    "Bijwerken TTL over 5 seconden"
    " "
    Start-Sleep -Seconds 5
    $Hosts | ForEach-Object {
        "Update TTL: " + $_.Hostname

        $data = null
        $ReqeustURI = $InfoBloxURL + $_.ref

        $JsonBody = '{"use_ttl": true, "ttl": ' + $UpdateTTL + '}'
        $data = Invoke-RestMethod -Method Put -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential -ContentType "application/json" -Body $JsonBody 
    }
}

# Update HOST IP when asked.
if ( $DirectChange ) {
    " "
    "Start commiting changes in 5 seconds."
    " "
    " "
    " "
    Start-Sleep -Seconds 5
    $Hosts | ForEach-Object {
        $data = null
        $ReqeustURI = $InfoBloxURL + $_.ref

        #Json body. "ipv4addr" == overwrite. "ipv4addr+" == add. "ipv4addr-" == delete. 
        $JsonBody = '{"ipv4addrs": [
            {
              "ipv4addr": "' + $NieuweIPAddr + '"
            }
          ]}

        '
        "Change Host: " + $_.Hostname
        $data = Invoke-RestMethod -Method Put -Uri $ReqeustURI -SessionVariable infoblox -Credential $Credential -ContentType "application/json" -Body $JsonBody 
    }
}

