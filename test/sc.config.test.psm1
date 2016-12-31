#Loading required dependencies
if (-not (Get-Module SC.Config)) {
    Import-Module .\sc-config-src\SC.Config\bin\Debug\SC.Config.dll -ErrorAction Stop
}

#Module configuration ( can be adjusted if necessary )
$SCRIPT:CONFIG:EnableActionDescriptions = @('Enable')
$SCRIPT:CONFIG:DisableActionDescriptions = @('Disable')
$SCRIPT:CONFIG:NAActionDescriptions = @('n/a')

$SCRIPT:CONFIG:ManifestRolesMapping = @{
    [SC.Config.SitecoreRole]::ContentDelivery                = 'Content Delivery (CD)';
    [SC.Config.SitecoreRole]::ContentManagement              = 'Content Management (CM)';
    [SC.Config.SitecoreRole]::ContentManagementAndProcessing = 'CM + Processing';
    [SC.Config.SitecoreRole]::Processing                     = 'Processing';
    [SC.Config.SitecoreRole]::Reporting                      = 'Reporting'
}


function Run-Test {
    param (
        [Parameter(Mandatory=$true)]
        [SC.Config.SitecoreRole[]]$Role = [System.Enum]::GetValues([SC.Config.SitecoreRole])
    )

    cd C:\users\ac\Work\Sources\sc-git\sc-config-automation   
    
    $manifest = Import-Csv .\manifest\Config_Enable-Disable_Sitecore_8.1_upd3-new.csv
    $manifest | gm | out-host
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $mr = $manifest[0]
    $mr | out-host
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $sp = Get-SearchProvider `
        -SearchProviderDescription $mr.'Search Provider Used' `
        -LuceneProviderDescriptionSet @('Base','Lucene is used') `
        -SOLRProviderDescriptionSet @('Solr is used') `
        -AnyProviderDescriptionSet @('')
    "Search Provider:" | out-host
    $sp | out-host
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $targetRole = $SCRIPT:CONFIG:ManifestRolesMapping.$($Role)
    $targetRole | Out-Host
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $action = Get-ManifestAction `
        -ManifestActionDescription $mr.$($targetRole) `
        -EnableActionDescriptions  $SCRIPT:CONFIG:EnableActionDescriptions `
        -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions `
        -NAActionDescriptions      $SCRIPT:CONFIG:NAActionDescriptions
    $action | out-host     
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $mrdata = $mr | out-string
    $mrdata | out-host
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | out-host

    $m = Get-ManifestRecord `
        -Action                  $action `
        -SearchProviderUsed      $sp `
        -FilePath                $mr.'File Path' `
        -ConfigFileName          $mr.'Config file name' `
}