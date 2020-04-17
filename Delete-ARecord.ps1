# Infoblox delete a-record and corresponding PTR-record

#VAR
$a_record_to_remove = "FQDN"
$credential = Get-Credential
$commit_changes = $false #Commit changes? Functions as otherwise functions as -whatif

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

# Delete A record
$ReqeustURI = $INFOBLOX_WAPI + "record:a?name~=" + $a_record_to_remove
"Get URL: $ReqeustURI"
$Result_a_record = Invoke-RestMethod -Method Get -Uri $ReqeustURI -Credential $Credential
$Result_a_record

if (-not $Result_a_record){
    Write-Host "No A record found." -BackgroundColor Red
} elseif ($commit_changes -and ($Result_a_record.Length -eq 1)) {
    Write-Host "Deleting A-record..." -BackgroundColor Green
    $ReqeustURI = $INFOBLOX_WAPI + $Result_a_record._ref
    $Result_of_delete = Invoke-RestMethod -Method Delete -Uri $ReqeustURI -Credential $Credential
    "Result of delete: $Result_of_delete"
}

# Delete PTR Record
$ReqeustURI = $INFOBLOX_WAPI + "record:ptr?ptrdname~=" + $a_record_to_remove
"Get URL: $ReqeustURI"
$Result_ptr_record = Invoke-RestMethod -Method Get -Uri $ReqeustURI -Credential $Credential
$Result_ptr_record

if (-not $Result_ptr_record){
    Write-Host "No PTR record found." -BackgroundColor Red
} elseif ($commit_changes -and ($Result_ptr_record.Length -eq 1)) {
    Write-Host "Deleting PTR-record..." -BackgroundColor Green
    $ReqeustURI = $INFOBLOX_WAPI + $Result_ptr_record._ref
    $Result_ptr_delete = Invoke-RestMethod -Method Delete -Uri $ReqeustURI -Credential $Credential
    "Result of PTR delete: $Result_ptr_delete"
}