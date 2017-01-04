cd C:\users\ac\Work\Sources\sc-git\sc-config-automation                                                                                                
import-module -force .\SC.Config.Automation.psm1

Get-Command -Module SC.Config.Automation

$result = Use-Manifest `
    -Apply:$false `
    -Role ContentDelivery `
    -SearchProvider Lucene `
    -Webroot 'C:\Users\ac\Work\Technical Support\473884 - xDB connectivity\1221\chr_delivery\cd1.test.orig' `
    -ConfigurationManifest .\manifest\Config_Enable-Disable_Sitecore_8.1_upd3-new.csv `
    # -Verbose