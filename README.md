# sc-config-automation
PowerShell scripts intended to automate config file activation / deactivation ( depending on instance role )

# Notes
The script does **NOT**
- Automatically verify that the manifest corresponds to the version of Sitecore it is being applied to

Consider this an alpha version. The script is to be further developed should it be recognized as a useful tool by other PSS engineers. Feel free to share your feedback.

# Concepts

- Manifest : CSV file containing information on which default Sitecore configuration files have to be enabled / disabled for particular role. The manifest CSV file is manually generated from the Excel document available at doc.sitecore.net website. 
  - The CSV manifest can be obtained from xlsx Excel file using standard Excel capabilities ( by copying only the data, pasting it in a new Excel document and saving as CSV file )

- The scripts allow to:
  - Apply / Verify a manifest against a Sitecore instance ( using path to the instance webroot folder ): **sc-config.ps1**

# Examples
- Inspecting a manifest file:
  - `.\sc-view-manifest.ps1 -ManifestFilePath .\manifest\sc-config-manifest-81u3.csv`

- Verify a Sitecore instance against a manifest file: 
  - Persist execution result to the $resultList variable ( collection ) [ trace is still generated during the execution ]
    - `$resultList = .\sc-config.ps1 -Verify -Role ContentDelivery -SearchProvider Lucene -ConfigurationManifest .\manifest\sc-config-manifest-81u3.csv -Webroot C:\inetpub\wwwroot\sc81u3.sup\Website`
  - Review statuses produced by the script
    - `$resultList | select -ExpandProperty Status | sort | Get-Unique`
  - Number of files that need to be modified ( enabled or disabled )
    - `$resultList | ? { $_.Status -ne 'OK' } | measure`
  - List files that need to be disabled
    - `$resultList | ? { $_.Status -eq 'Needs to be disabled' } | select -ExpandProperty RealConfigFile`
  - List files that need to be enabled
    - `$resultList | ? { $_.Status -eq 'Needs to be enabled' } | select -ExpandProperty RealConfigFile`

- Apply a manifest to a Sitecore instance
  - Persist execution result to the $changeList variable ( collection ) [ trace is still generated during the execution ]
    - `$changeList = .\sc-config.ps1 -ApplyManifest -Role ContentDelivery -SearchProvider Lucene -ConfigurationManifest .\manifest\sc-config-manifest-81u3.csv -Webroot C:\inetpub\wwwroot\sc81u3.sup\Website`
  - Review statuses produced by the execution
    - `$changeList | select -ExpandProperty Status | sort | Get-Unique`
