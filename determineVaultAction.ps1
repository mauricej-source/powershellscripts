#############################################
# Environment to get script from - choose nonprod, prepord, prod
$vaultapprole = Read-Host -Prompt "Enter Vault APP Role Name "

# Vault Namespace - will be used to match an item out of the $vaults array below
$vaultReviewFileName = Read-Host -Prompt "Enter Vault Review File Name "

# Path to Vault Secret JSON File
$vaultSecretFileName = Read-Host -Prompt "Enter Vault Secret File Name "

#############################################

$scriptfolder = $PSScriptRoot

$inputfolder = "$($scriptfolder)\_INPUT"

$outputfolder = "$($scriptfolder)\_OUTPUT"

if(Test-Path $outputfolder){
  #folder exists do nothing
} else {
  New-Item $outputfolder -ItemType Directory
}

#Input File to be Reviewed
$inputreviewfile = "$($inputfolder)\$($vaultReviewFileName)"

#Input Vault Secret File to Compare the Review Against - This comparison will determine the Action needed within Vault
$inputsecretfile = "$($outputfolder)\$($vaultSecretFileName)"

$sheetName = "Sheet1"

#create new excel COM object
$excel = New-Object -com Excel.Application

#open excel file
$wb = $excel.workbooks.open($inputreviewfile)

#select excel sheet to read data
$sheet = $wb.Worksheets.Item($sheetname)

#select total rows
$rowMax = ($sheet.UsedRange.Rows).Count

#create new object with Name, Address, Email properties.
$vaultData = New-Object -TypeName psobject
$vaultData | Add-Member -MemberType NoteProperty -Name Namespace -Value $null
$vaultData | Add-Member -MemberType NoteProperty -Name Approle -Value $null
$vaultData | Add-Member -MemberType NoteProperty -Name Secretkey -Value $null

#create empty arraylist
$myArray = @()

for ($i = 2; $i -le $rowMax; $i++)
{
    $objTemp = $vaultData | Select-Object *

    #read data from each cell
    $objTemp.Namespace = $sheet.Cells.Item($i,1).Text
    $objTemp.Approle = $sheet.Cells.Item($i,2).Text
    $objTemp.Secretkey = $sheet.Cells.Item($i,3).Text
    #Write-Host 'Namespace-' $objTemp.Namespace 'Approle-' $objTemp.Approle 'Secretkey-' $objTemp.Secretkey

    #equalsignorecase
    if($vaultapprole -ieq $objTemp.Approle){
        $searchPattern = Select-String -Path $inputsecretfile -Pattern $objTemp.Secretkey
        if ($searchPattern -ne $null) {
            Write-Host 'Action: UPDATE   - Approle: ' $objTemp.Approle '   - Secret: ' $objTemp.Secretkey
        } else {
            Write-Host 'Action: ADD      - Approle: ' $objTemp.Approle '   - Secret: ' $objTemp.Secretkey
        }

        $myArray += $objTemp
    }
}

#######################################################################################
# Close Input Excel File
#######################################################################################
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)
Remove-Variable excel
