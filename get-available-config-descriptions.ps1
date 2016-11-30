<#
.Synopsis
   Produces list of descriptions ( comments ) from Sitecore configuration files 
.DESCRIPTION
   Produces list of descriptions ( comments ) from Sitecore configuration files
   The list can be further processed in Excel to increase readability of the information
.EXAMPLE
   .\get-available-config-descriptions.ps1 -WebrootFolder '<path>\Sitecore 8.1 rev. 160302\Website' -OutReportFile .\81u2-config-descriptions.csv
#>
param (
    $WebrootFolder,
    $OutReportFile
)

if (-not (Test-Path $WebrootFolder -PathType Container)) {
    throw "'$WebrootFolder' webroot folder cannot be found"
}

$appConfigPath = Join-Path $WebrootFolder "App_Config/Include"
if (-not (Test-Path $appConfigPath -PathType Container)) {
    throw "App_Config/Include folder for the webroot cannot be found"
}

try {
        
    $configFilesList = gci -Recurse $appConfigPath -File 
    
    $info = @()
    
    foreach ( $record in $configFilesList ) {
        try {
            $info += New-Object psobject -Property @{ FileName = $record.FullName; Notes= $(([xml](gc $record.FullName)).'#comment') }
        } catch [Exception]{
            Write-Warning "Failed to process '$record' due to '$($_.Exception.Message)'"
        }
    }                                                                                                                                                
    
    $info | select FileName,Notes | export-csv -NoTypeInformation $OutReportFile -ErrorAction Stop -Force

    $outReport = gi $OutReportFile

    Write-Host -NoNewline "- Output ( CSV ) had been written to the "
    Write-Host -NoNewLine -ForegroundColor Yellow -BackgroundColor Black "'$($outReport.FullName)'"
    Write-Host " file"

    Write-Host -NoNewline -ForegroundColor Yellow -BackgroundColor Black "NOTE: "
    Write-Host -BackgroundColor Black -ForegroundColor Gray @"
The CSV report can be opened in Excel using the following tricks:
> Make sure to open the file in Excel by double-clicking the file in File Explorer ( Excel import dialog fails to correctly process multiline strings. Yeah, go figure :) )
> After opened in excel ( in order to adjust height of cells ) you can select all the data ( Ctrl-A ) and choose 'Format as table' ( 'HOME' ribbon -> Styles chunk )
> Assuming the above two steps went as expected you can rely on Excel's sorcery to filter data like:
    - Show all configuration files with non-empty notes
    - Show all currently enabled files ( file name ends with .config )
    - Show all currently disabled files ( file name does not end with .config )
    - Whichever else comes to your mind

Happy configuring :)
"@

} catch [Exception] {
    Write-Error "Well ... Houston, we've got a problem..."
    Write-Error $_.Exception
}