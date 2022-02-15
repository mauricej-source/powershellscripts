<#
.SYNOPSIS
scrubSecV finds a string of text that matches the criteria across multiple files, and replaces it with the specified new string.
.DESCRIPTION
This command searches through a directory or the file specified, and obtain the content of the files with Get-Content PowerShell cmdlet, find and replace matching strings within the obtained content and set the new text as the content of the original file.
.PARAMETER folderPath
.EXAMPLE
This example finds all the files within the C:\temp\temp_folder, and scrubs them of GitHub Sedation Vulnerabilities
scrubSecV -folderPath 'C:\temp\temp_folder'
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $folderPath
)

if ($folderPath -ne '') {
    $currentdate = $(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss"))
    $report = "./" + $currentdate + "_SecurityVulnerability_Report.html"
    $report1 = "./" + $currentdate + "_EISRepository_Report.html"

    $mask1 = 'insertMaskHere'

    $secV1 = 'insertGiTHubSedationViolationHere'

    $repo1 = 'insertRepositoryURLHere'

    #-----------------------------------------------------------------------------------------
    #Find and Log All Occurences of GitHub Sedation Vulnerabilities
    #-----------------------------------------------------------------------------------------
    Get-ChildItem -Path ($folderPath+"\*") -recurse -exclude *.ps1, *.zip, *.log, *.html, *.helmignore, *.gitignore, *.lock | `
    Select-String -pattern $secV1   | `
    Select-Object -Property Path,LineNumber,Line | ConvertTo-Html | Out-File -FilePath $report

    #-----------------------------------------------------------------------------------------
    #Find and Log All Occurences of Repositories throughout Source Code
    #-----------------------------------------------------------------------------------------
    Get-ChildItem -Path ($folderPath+"\*") -recurse -exclude *.ps1, *.zip, *.log, *.html, *.helmignore, *.gitignore, *.lock | `
    Select-String -pattern $repo1 | `
    Select-Object -Property Path,LineNumber,Line | ConvertTo-Html | Out-File -FilePath $report1

    #-----------------------------------------------------------------------------------------
    #Replace GitHub Sedation Security Vulnerabilities within Source Code
    #-----------------------------------------------------------------------------------------
    $files = Get-ChildItem -Path ($folderPath+"\*") -Recurse -Exclude *.ps1, *.zip, *.log, *.html, *.helmignore, *.gitignore, *.lock
    foreach ($f in $files){
        if($f.PSIsContainer){
            #If Folder do nothing
        } else {
            (Get-Content $f.FullName) | Foreach-Object {
                $_ -replace $secV1, $mask1 `
                } | Set-Content -Path $f.FullName
        }
    }
}
elseif ($folderPath -eq '') {
    Write-Host "Warning: You need to specify a file path and try again" -ForegroundColor Red;
}
