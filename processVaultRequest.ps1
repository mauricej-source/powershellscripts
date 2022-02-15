#######################################################################################
# Prompt Variables
#######################################################################################
# Path to Vault Secret JSON File
$vaultRequestInputFileName = Read-Host -Prompt "Enter Vault Request Input File Name "

# Environment to get script from - choose nonprod, prepord, prod
$vltEnv = Read-Host -Prompt "Enter Vault Env (nonprod, preprod, prod) "

# UserName
$username = Read-Host -Prompt "Enter username "

# Password
$userpass = Read-Host -Prompt "Enter password "
#######################################################################################

#######################################################################################
# Declared Variables
#######################################################################################
# - IO Variables
$dateFormat = Get-Date -Format "yyyMMddHHmmss"

$scriptfolder = $PSScriptRoot

$inputfolder = "$($scriptfolder)\_INPUT"

$outputfolder = "$($scriptfolder)\_OUTPUT"

if(Test-Path $outputfolder){
  #folder exists do nothing
} else {
  New-Item $outputfolder -ItemType Directory
}

#Vault Request Input Filename, full path
$vaultrequestfile = "$($inputfolder)\$($vaultRequestInputFileName)"

$sheetName = "Sheet1"

#Excel COM object
$excel = New-Object -com Excel.Application

#Open excel file
$wb = $excel.workbooks.open($vaultrequestfile)

#Select Excel Sheet
$sheet = $wb.Worksheets.Item($sheetname)

#Get Total Rows per sheet
$rowMax = ($sheet.UsedRange.Rows).Count

#Create Data Object with Namespace, Approle, Key, Value properties.
$vaultData = New-Object -TypeName psobject
$vaultData | Add-Member -MemberType NoteProperty -Name Namespace -Value $null
$vaultData | Add-Member -MemberType NoteProperty -Name Approle -Value $null
$vaultData | Add-Member -MemberType NoteProperty -Name Key -Value $null
$vaultData | Add-Member -MemberType NoteProperty -Name Value -Value $null

#create empty arraylist
$dataArray = @()

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
#######################################################################################

#######################################################################################
# Process Vault RequestInput File
#######################################################################################
$vaultapprole_previous = "firsttime"
$writecontent = "false"

for ($i = 2; $i -le $rowMax; $i++)
{
    $objTemp = $vaultData | Select-Object *

    #Get the Data from each Excel File Row Cell
    $objTemp.Namespace = $sheet.Cells.Item($i,1).Text
    $objTemp.Approle = $sheet.Cells.Item($i,2).Text
    $objTemp.Key = $sheet.Cells.Item($i,3).Text
    $objTemp.Value = $sheet.Cells.Item($i,4).Text

    #Write-Host 'Namespace-' $objTemp.Namespace      'Approle-' $objTemp.Approle      'Key-' $objTemp.Key      'Value-' $objTemp.Value

    ##################################################################################################
    # Log into Vault - If Necessary - Refactor later
    ##################################################################################################
    if($vaultapprole_previous){
        if($vaultapprole_previous -ieq "firsttime"){
            $envItem = $environments | where { $_.Env -eq $vltEnv }

            $vaultItem = $vaults | where { $_.Namespace -eq $objTemp.Namespace }

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

            $vaultapprole_previous = $objTemp.Approle
            $writecontent = "true"
        } else {
            if($objTemp.Approle -ieq $vaultapprole_previous){
                $writecontent = "false"
                Write-Host "processing..."
            } else {
                $envItem = $environments | where { $_.Env -eq $vltEnv }

                $vaultItem = $vaults | where { $_.Namespace -eq $objTemp.Namespace }

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

                $vaultapprole_previous = $objTemp.Approle
                $writecontent = "true"
            }
        }
    } else {
        Write-Host 'Vault Request Input File Processing ERROR - Internal Variable vaultapprole not set'
    }

    ###################################################
    # Get Current Vault Secrets per APPRole
    ###################################################
    if($writecontent -ieq "true"){
        Clear-Variable "headers"

        $headers = @{
            "X-Vault-Namespace" = "$($vaultItem.Namespace)"
            "X-Vault-Token" = "$($loginResults.auth.client_token)"
        }

        $keysRequestUri = "$($envItem.VaultAddr)/v1/secret/$($vaultItem.BarometerIT)/$($envItem.Env)/$($objTemp.Approle)/config"

        $kvRequest = Invoke-WebRequest -Uri $keysRequestUri -Headers $headers -Method Get
        $jsonoutput = ($kvRequest.Content | ConvertFrom-Json).data | ConvertTo-Json
        $jsonoutput = $jsonoutput.Replace("\u003c", "<").Replace("\u003e", ">").Replace("\u0026", "&").Replace("\u0027", "'")
        $jsonoutput = $jsonoutput | Sort-Object -Property Name

        $vaultSecretsBackupOutputJSONFileName = "$outputfolder\$($dateFormat)_BACKUP_$($vltEnv)_$($objTemp.Namespace)_$($objTemp.Approle)_secrets.json"
        $vaultSecretsMaintOutputJSONFileName = "$outputfolder\$($dateFormat)_MAINT_$($vltEnv)_$($objTemp.Namespace)_$($objTemp.Approle)_secrets.json"

        Set-Content -Value $jsonoutput -Path $vaultSecretsBackupOutputJSONFileName
        Set-Content -Value $jsonoutput -Path $vaultSecretsMaintOutputJSONFileName

        #########################################################################################
        # Pause Script for 10 Seconds
        #########################################################################################
        Start-Sleep -s 10
    }

    ###################################################
    # Determine Action Needed
    ###################################################
    $vaultSecretsActionOutputFileName = "$outputfolder\$($dateFormat)_$($vltEnv)_$($objTemp.Namespace)_VAULT_ACTION_REQUIRED.txt"

    $searchPattern = Select-String -Path $vaultSecretsMaintOutputJSONFileName -Pattern $objTemp.Key

    if ($searchPattern -ne $null) {
        #Write-Host 'Action: UPDATE   - Approle: ' $objTemp.Approle '   - Secret: ' $objTemp.Key
        Add-Content $vaultSecretsActionOutputFileName "Action: UPDATE   - Approle:  $($objTemp.Approle)   - Secret:   $($objTemp.Key)"

        ######################################################
        # Find and Replace Value by Key Name within JSON File
        ######################################################
        $JsonData = Convertfrom-json (Get-Content $vaultSecretsMaintOutputJSONFileName)

        ##Left Off Here Johnson??? - Not certain if this is possible.
        $JsonData.engineconfiguration.Components.Parameters.$($objTemp.Key) = "$($objTemp.Value)"

        ConvertTo-Json $JsonData -Depth 4 | Out-File $vaultSecretsMaintOutputJSONFileName -Force
    } else {
        #Write-Host 'Action: ADD      - Approle: ' $objTemp.Approle '   - Secret: ' $objTemp.Key
        Add-Content $vaultSecretsActionOutputFileName "Action: ADD      - Approle:  $($objTemp.Approle)   - Secret:   $($objTemp.Key)"


        ###################################################
        # Append KEY/Value Pair to End of JSON File
        ###################################################
    }

    $dataArray += $objTemp
}

#######################################################################################
# Close Input Excel File
#######################################################################################
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)
Remove-Variable excel
