#############################################

# Vault Namespace - will be used to match an item out of the $vaults array below
$vltNamespace = Read-Host -Prompt "Enter Vault Namespace (insertNameSpacesHere): "

# Environment to get script from - choose nonprod, prepord, prod
$vltEnv = Read-Host -Prompt "Enter Vault Env (nonprod, preprod, prod): "

# AppRole to get secrets for  use GetAppRoles.ps1 to find all available appRoles
# ex: abapi-a2a-dev
$vltAppRole = Read-Host -Prompt "Enter Vault APP Role: "

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

$envItem = $environments | where { $_.Env -eq $vltEnv }
$vaultItem = $vaults | where { $_.Namespace -eq $vltNamespace }
$adGroup = "$($vaultItem.AdGroupName)$($envItem.AdGroupEnv)"

#log into Vault
$headers = @{
    "X-Vault-Namespace" = "$($vaultItem.Namespace)"
}
        
$body = @{
    "password" = "$userpass"
} | ConvertTo-Json

$loginUri = "$($envItem.VaultAddr)/v1/auth/$adGroup/$($vaultItem.Namespace)/login/$username"        
$loginRequest = Invoke-WebRequest -Uri $loginUri -Headers $headers -Method Post -Body $body
$loginResults = $loginRequest.Content | ConvertFrom-Json


Clear-Variable "headers"

$headers = @{
    "X-Vault-Namespace" = "$($vaultItem.Namespace)"
    "X-Vault-Token" = "$($loginResults.auth.client_token)"
} 
        
$keysRequestUri = "$($envItem.VaultAddr)/v1/secret/$($vaultItem.BarometerIT)/$($envItem.Env)/$vltAppRole/config"     

$kvRequest = Invoke-WebRequest -Uri $keysRequestUri -Headers $headers -Method Get
$output = ($kvRequest.Content | ConvertFrom-Json).data | ConvertTo-Json
$output = $output.Replace("\u003c", "<").Replace("\u003e", ">").Replace("\u0026", "&").Replace("\u0027", "'")
$output = $output | Sort-Object -Property Name

$dateFormat = Get-Date -Format "yyyMMddHHmmss"
Set-Content -Value $output -Path "$outputfolder\$($dateFormat)_$($vltEnv)_$($vltNamespace)_$($vltAppRole)_secrets.json"
#($kvRequest.Content | ConvertFrom-Json).data | ConvertTo-Json | Out-File "$outputfolder\$($envItem.Env)\secrets-$vltAppRole-$dateFormat.json" -Encoding utf8


