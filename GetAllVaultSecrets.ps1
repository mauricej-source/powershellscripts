#############################################
# UserName
$username = Read-Host -Prompt "Enter username: "

# Password
$userpass = Read-Host -Prompt "Enter password: "

#############################################

$scriptfolder = $PSScriptRoot

$outputfolder = "$($scriptfolder)\_OUTPUT"

if(Test-Path $outputfolder){
  #folder exists do nothing
} else {
  New-Item $outputfolder -ItemType Directory
}

# - Vault URLs
$environments = @(
    [pscustomobject]@{Env="nonprod";AdGroupEnv="DEV";VaultAddr="insertDEVVaultURLHere"}
    [pscustomobject]@{Env="preprod";AdGroupEnv="TST";VaultAddr="insertTSTVaultURLHere"}
    [pscustomobject]@{Env="prod";AdGroupEnv="PRD";VaultAddr="insertPRDVaultURLHere"}
)

# - Vault Configurations Insert Where Needed: Organization, Namespace, ActiveDirectoryGroup
$vaults = @(
    [pscustomobject]@{Org="";Namespace="";BarometerIT="";AdGroupName=""}
    [pscustomobject]@{Org="";Namespace="";BarometerIT="";AdGroupName=""}
    [pscustomobject]@{Org="";Namespace="";BarometerIT="";AdGroupName=""}
    [pscustomobject]@{Org="";Namespace="";BarometerIT="";AdGroupName=""}
    [pscustomobject]@{Org="";Namespace="";BarometerIT="";AdGroupName=""}
)

$failures = @()
$dateFormat = Get-Date -Format "yyyMMddHHmmss"

foreach($vlt in $vaultInfo) {
    foreach($envData in $environments){
        $adGroup = "$($vlt.AdGroupName)$($envData.AdGroupEnv)"
        $loginUri = "$($envData.VaultAddr)/v1/auth/$adGroup/$($vlt.Namespace)/login/$username"
        $loginUri
        
        $headers = @{
            "X-Vault-Namespace" = "$($vlt.Namespace)"
        }
        
        $body = @{
            "password" = "$userpass"
        } | ConvertTo-Json
        
        #login

        try {
            $loginRequest = Invoke-WebRequest -Uri $loginUri -Headers $headers -Method Post -Body $body
            $content = $loginRequest.Content | ConvertFrom-Json
            $content.auth.client_token

            $headers = @{
                "X-Vault-Namespace" = "$($vlt.Namespace)"
                "X-Vault-Token" = "$($content.auth.client_token)"
            } 
            
            #get folder paths
            $authRequestUri = "$($envData.VaultAddr)/v1/sys/auth"
            $authListRequest = Invoke-WebRequest -Uri $authRequestUri -Headers $headers -Method Get
            $properties = ($authListRequest.Content | ConvertFrom-Json).data.psobject.properties
            
            #get and write key/values into json
            foreach($property in $properties) {
                if ($property.Value.type -ieq "appRole") {
                    try {
                        $pathSplit = $property.Name.split("/")
                        $appRole = $pathSplit[($pathSplit.Length-2)]
                        $keysRequestUri = "$($envData.VaultAddr)/v1/secret/$($property.Name)config"
                    
                        $kvRequest = Invoke-WebRequest -Uri $keysRequestUri -Headers $headers -Method Get
                        #($kvRequest.Content | ConvertFrom-Json).data | ConvertTo-Json | Out-File "$outputfolder\$($envData.Env)\secrets-$appRole-$dateFormat.json"
                        $output = ($kvRequest.Content | ConvertFrom-Json).data | ConvertTo-Json 
                        $output = $output.Replace("\u003c", "<").Replace("\u003e", ">").Replace("\u0026", "&").Replace("\u0027", "'")

                        $dateFormat = Get-Date -Format "yyyMMddHHmmss"
                        Set-Content -Value $output -Path "$outputfolder\$($dateFormat)_$($envData.Env)_$($appRole)_secrets.json"
                        
                        Clear-Variable "output"
                        Clear-Variable "kvRequest"
                    }
                    catch {
                        $failures += "Failed to get $($property.Name)"
                    }
                }          
            }
            
            Clear-Variable "properties"
            Clear-Variable "authListRequest"
            Clear-Variable "loginRequest"
            Clear-Variable "content"
        }
        catch {
            $failures += "Failed to login for AdGroup: $adGroup and Vault Namespace: $($vlt.Namespace)"
        }

    }    
}

$dateFormat = Get-Date -Format "yyyyMMddHHmmss"

if ($failures.Count -gt 0) {
    $failures | Out-File "$outputfolder\$($dateFormat)_GetAllVaultSecrets_ERRORS.txt"
}

Clear-Variable "failures"
