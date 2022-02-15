#############################################

# Vault Namespace - will be used to match an item out of the $vaults array below
$vltNamespace = Read-Host -Prompt "Enter Vault Namespace (insertNameSpacesHere): "

# Environment to get script from - choose nonprod, prepord, prod
$vltEnv = Read-Host -Prompt "Enter Vault Env (nonprod, preprod, prod): "

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

$appRoleList = @()

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
        
$authRequestUri = "$($envItem.VaultAddr)/v1/sys/auth"

$authListRequest = Invoke-WebRequest -Uri $authRequestUri -Headers $headers -Method Get
$vltAppRoles = ($authListRequest.Content | ConvertFrom-Json).data.psobject.properties
$vltAppRoles.Name| foreach { 
    $appRoleArr = $_.split("/")

    if ($appRoleArr.Length -gt 3) {
        $appRoleList += [pscustomobject]@{FullAppRole="$_";BIT="$($appRoleArr[0])";Environment="$($appRoleArr[1])";AppRole="$($appRoleArr[2])"}
    }
}

$appRoleList

$dateFormat = Get-Date -Format "yyyyMMddHHmmss"
$appRoleList | Out-File "$outputfolder\$($dateFormat)_$($vltEnv)_$($vltNamespace)_appRoles.txt"

