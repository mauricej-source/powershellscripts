#############################################

# Vault Namespace - will be used to match an item out of the $vaults array below
$vltNamespace = Read-Host -Prompt "Enter Vault Namespace (insertNameSpacesHere): "

# Environment to get script from - choose nonprod, prepord, prod
$vltEnv = Read-Host -Prompt "Enter Vault Env (nonprod, preprod, prod): "

# Vault APPRole
$vltAppRole = Read-Host -Prompt "Enter Vault APP Role: "

# Path to Vault Secret JSON File
$secretsFile = Read-Host -Prompt "Enter Vault Secret File Name: "

# UserName
$username = Read-Host -Prompt "Enter username: "

# Password
$userpass = Read-Host -Prompt "Enter password: "

#############################################
$scriptfolder = $PSScriptRoot

$inputfolder = "$($scriptfolder)\_INPUT"

$outputfolder = "$($scriptfolder)\_OUTPUT"

if(Test-Path $outputfolder){
  #folder exists do nothing
} else {
  New-Item $outputfolder -ItemType Directory
}

#Input Vault Secret File to Compare the Review Against - This comparison will determine the Action needed within Vault
$inputsecretfile = "$($outputfolder)\$($secretsFile)"

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

#Prompt User to Continue with Administration?

Write-Host ""
Write-Host "Processing Vault Administration..."
Write-Host ""
Write-Host "Environment:`t $vltEnv"
Write-Host "Namespace:`t $vltNamespace"
Write-Host "AppRole:`t $vltAppRole"
Write-Host "File:`t`t $inputsecretfile"
Write-Host ""

$answer = Read-Host -Prompt "Would You Like to Continue? ([Y] or [N])"

if ($answer -eq "Y") {
  
    $headers = @{
        "X-Vault-Namespace" = "$($vaultItem.Namespace)"
        "X-Vault-Token" = "$($loginResults.auth.client_token)"
        "Content-Type" = "application/json"
    } 
    
    $secretData = Get-Content -Path $inputsecretfile -Raw

    $results = Invoke-WebRequest -Uri $keysRequestUri -Headers $headers -Body $secretData -Method Post
    Write-Host "Vault was updated"
}
else {
    Write-Host "Vault was not updated"
}

