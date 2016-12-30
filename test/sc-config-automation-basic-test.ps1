cd C:\users\ac\Work\Sources\sc-git\sc-config-automation   

$SCRIPT:CONFIG:EnableActionDescriptions = @('Enable')
$SCRIPT:CONFIG:DisableActionDescriptions = @('Disable')

$manifest = Import-Csv .\manifest\Config_Enable-Disable_Sitecore_8.1_upd3-new.csv
$mr = $manifest[0]
$sp = Get-SearchProvider `
    -SearchProviderDescription $mr.'Search Provider Used' `
    -LuceneProviderDescriptionSet @('Base','Lucene is used') `
    -SOLRProviderDescriptionSet @('Solr is used') `
    -AnyProviderDescriptionSet @('')

$m = Get-ManifestRecord `
    -CurrentAction           $mr.$Role
    -SearchProviderUsed      $sp `
    -ContentDeliveryAction   (Get-ManifestAction -ManifestActionDescription $mr.'Content Delivery (CD)'   -EnableActionDescriptions $SCRIPT:CONFIG:EnableActionDescriptions -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions) `
    -ContentManagementAction (Get-ManifestAction -ManifestActionDescription $mr.'Content Management (CM)' -EnableActionDescriptions $SCRIPT:CONFIG:EnableActionDescriptions -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions) `
    -ProcessingAction        (Get-ManifestAction -ManifestActionDescription $mr.'Processing'              -EnableActionDescriptions $SCRIPT:CONFIG:EnableActionDescriptions -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions) `
    -CMAndProcessingAction   (Get-ManifestAction -ManifestActionDescription $mr.'CM + Processing'         -EnableActionDescriptions $SCRIPT:CONFIG:EnableActionDescriptions -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions) `
    -ReportingAction         (Get-ManifestAction -ManifestActionDescription $mr.'Reporting'               -EnableActionDescriptions $SCRIPT:CONFIG:EnableActionDescriptions -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions) `
    -ProductName             $mr.'Product Name' `
    -FilePath                $mr.'File Path' `
    -ConfigFileName          $mr.'Config file name' `
    -ConfigType              $mr.'Config Type'
