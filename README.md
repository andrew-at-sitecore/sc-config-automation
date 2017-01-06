# sc-config-automation
PowerShell module intended to automate config file activation / deactivation ( depending on specific instance role )

# Notes
The script does **NOT**
- Automatically verify that the manifest corresponds to the version of Sitecore it is being applied to

Consider this a beta version. The script is to be further developed should it be recognized as a useful tool by Sitecore PSS engineers / partners / customers. Feel free to share your feedback.

# Concepts

- Manifest : CSV file containing information on which default Sitecore configuration files have to be enabled / disabled for particular role. The manifest CSV file is manually generated from the Excel document available at doc.sitecore.net website. 
  - The CSV manifest can be obtained from xlsx Excel file using standard Excel capabilities ( by copying only the data, pasting it in a new Excel document and saving as CSV file )

- The module allows to:
  - Apply / Verify a manifest against a Sitecore instance ( using path to the instance webroot folder )

# Module settings
The powershell module provides set of settings that can be adjusted ( if needed ). The available settings can be located by editing the '(sc.config.automation.psm1)' module file in text editor and locating '$SCRIPT:CONFIG:' entries.
Comments in the module file provide technical description of each individual configuration entry.

# Examples
- Importing the PowerShell module ( from a PowerShell runtime such as PowerShell command line or PowerShell ISE ):
  - `import-module -force .\sc.config.automation.psm1`
    - __NOTE__: The PowerShell module has dependency - '__SC.Config.dll__' assembly ( output of the '[/sc-config-src/SC.Config](/sc-config-src/SC.Config)' project ). The assembly should be in the same folder as the '[sc.config.automation.psm1](sc.config.automation.psm1)' module file

- List the command(s) exported by the module:
  - `get-command -Module sc.config.automation`
- List the roles supported by the module:
  - `[SC.Config.SitecoreRole].GetEnumValues()`
- Verify a Sitecore instance against a manifest file: 
  - Persist execution result to the $resultList variable ( collection ) [ trace is still generated during the execution ]
    - `$resultList = Use-Manifest -Role ContentDelivery -SearchProvider Lucene -ConfigurationManifest .\manifest\sc-config-manifest-81u3.csv -Webroot C:\inetpub\wwwroot\sc81u3.sup\Website`
  - Review statuses produced by the script
    - `$resultList | Group-Object -Property Status | select count,name`
  - Review errors
    - `$resultList | ? { $_.Status -eq 'Fail'} | select StatusDetails, ProcessingTrace`
  - List files that need to be disabled
    - `$resultList | ? { ($_.Status -eq 'Action') -and ($_.StatusDetails -eq 'Needs to be disabled') } | select RealConfigFilePath`
  - List files that need to be enabled
    - `$resultList | ? { ($_.Status -eq 'Action') -and ($_.StatusDetails -eq 'Needs to be enabled') } | select RealConfigFilePath`

- Apply a manifest to a Sitecore instance
  - Persist execution result to the $changeList variable ( collection ) [ trace is still generated during the execution ]
    - `$changeList = Use-Manifest -Apply -Role ContentDelivery -SearchProvider Lucene -ConfigurationManifest .\manifest\sc-config-manifest-81u3.csv -Webroot C:\inetpub\wwwroot\sc81u3.sup\Website`
  - Review statuses produced by the execution
    - `$changeList | Group-Object -Property Status | select count,name`
  - ... You know the drill by now ... :)
