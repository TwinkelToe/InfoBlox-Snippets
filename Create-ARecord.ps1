# Infoblox Create A-record and corresponding PTR-record

#VAR
$a_record_to_create = "FQDN"
$ip_addr = "127.0.0.1"
$credential = Get-Credential

#$password = ConvertTo-SecureString “PlainTextPassword” -AsPlainText -Force
#$credential = New-Object System.Management.Automation.PSCredential (“username”, $password)

#CONST
$INFOBLOX_WAPI = "https://x.x.x.x/wapi/v2.9.5/"

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

$ReqeustURI = $INFOBLOX_WAPI + "record:a?name~=" + $a_record_to_create
"Get URL: $ReqeustURI"
$Result_a_record = Invoke-RestMethod -Method Get -Uri $ReqeustURI -Credential $Credential

if ($Result_a_record){
    Write-Host "A-record already exists:" -BackgroundColor Red
    $Result_a_record
} else {
    # Create A-record
    Write-Host "No A-record found, creating.." -BackgroundColor Green
    $ReqeustURI = $INFOBLOX_WAPI + "record:a"

    $JsonBody = '
    {
    	"name": "' + $a_record_to_create + '",
    	"ipv4addr": "' + $ip_addr + '"
    }
    '

    $Result_a_post = Invoke-RestMethod -Method Post -Uri $ReqeustURI -Body $JsonBody -Credential $Credential -ContentType "application/json"
    "Result of post: $Result_a_post"
    if ($Result_a_post){
        # Create PTR-Record
        $ReqeustURI = $INFOBLOX_WAPI + "record:ptr?ptrdname~=" + $a_record_to_remove
        "Get URL: $ReqeustURI"
        $Result_ptr_record = Invoke-RestMethod -Method Get -Uri $ReqeustURI -Credential $Credential
        if ($Result_ptr_record){
            write-host "PTR-record already exist:" -BackgroundColor Red
            $Result_ptr_record
        } else {
                Write-Host "No PTR-record found, creating.." -BackgroundColor Green
            $ReqeustURI = $INFOBLOX_WAPI + "record:ptr"

            $JsonBody = '
            {
    	        "ptrdname": "' + $a_record_to_create + '",
    	        "ipv4addr": "' + $ip_addr + '"
            }
            '
            $Result_ptr_post = Invoke-RestMethod -Method Post -Uri $ReqeustURI -Body $JsonBody -Credential $Credential -ContentType "application/json"
            "Result of post: $Result_ptr_post"
        }
    }
}