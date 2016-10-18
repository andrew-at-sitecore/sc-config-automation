<#
.Synopsis
   Script to verify or adjust configuration files of a Sitecore instance to fulfill particular Sitecore role in a scaled environment )
   ( Content Delivery, Content Management, Processing, Reporting ) 
.DESCRIPTION
   Long description
.EXAMPLE
   sc-config -Verify -Product AppCenter -Role ContentDelivery -Manifest [xml] (gc .\sc-81-config-manifest.xml )
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

param (
    $Webroot,
    [xml]$ConfigurationManifest
)

# CONFIGURATION ##############################################
# NOTE: extensions must be lower case
# NOTE: first entry in each extension list is to be used as default extension ( while renaming files to enable / disable them )
$SCRIPT:CONFIG:DisabledFileExtensions = @('.disabled', '.example')
$SCRIPT:CONFIG:EnabledFileExtensions = @('.config')
# END: CONFIGURATION #########################################

# HELPERS ####################################################
<#
.Synopsis
    Strips a config file name from the registered extensions ( to allow matching config files from manifest and those on file system since there can be different combinations of extensions )
#>
function Get-BaseConfigFileName {
    param (
        [string]$ConfigFileName
    )
    $fileNameElements = $ConfigFileName.Trim().Split('.')
    
    # process the collection from the tail
    $cutoffElementIndex = 0
    for ( $i=-1; $i -gt ($fileNameElements.Length * -1); $i-- ) {
        # each iteration tries to match element as an extension
        $extensionMatched = $false
        $currentIterationFileNameSegment = ".{0}" -f $fileNameElements[$i].ToLower()
        if ( $SCRIPT:CONFIG:DisabledFileExtensions.Contains($currentIterationFileNameSegment)) { $extensionMatched = $true }
        if ( $SCRIPT:CONFIG:EnabledFileExtensions.Contains($currentIterationFileNameSegment)) { $extensionMatched = $true }

        if ( -not $extensionMatched ) {
            #if no extension can be matched from the "tail" - what's left is to be considered the config file base name
            $cutoffElementIndex = $fileNameElements.Length + $i # $i is negative since the collection had been processed from the "tail"
            break
        }
    }

    return $fileNameElements[0..$cutoffElementIndex] -join '.'
}

function Get-MatchingConfigFile {
    param (
        $Webroot,
        [string]$ManifestConfigFilePath
    )

    $configFileName = split-path -Path $ManifestConfigFilePath -Leaf
    $configFileRelativePath = split-path -Path $ManifestConfigFilePath -Parent

    $configFileBaseName = Get-BaseConfigFileName -ConfigFileName $configFileName

    # A bit of trickery to
    #   - remove '\website' or 'website' entry from the manifest ( since the script operates in the context of webroot folder )
    #   - add '.*' to config file base name ( to get file system search pattern )
    # As a result we end up with '\relative\path\file.base.name.*' ( so that later on we can get all files from file system, get their base names and fetch the one that corresponds to the manifest entry )
    $adjustedConfigFileRelativePath = $configFileRelativePath -replace '^\\?website',''
    $configFileBaseRelativePath = ( "{0}.*" -f $configFileBaseName )
    if (-not [string]::IsNullOrEmpty($adjustedConfigFileRelativePath)) {
        # This is necessary for definitions like '/website/web.config'
        $configFileBaseRelativePath = Join-Path -Path $adjustedConfigFileRelativePath -ChildPath $configFileBaseRelativePath
    }

    $configFileBaseFullPath = Join-Path -Path $Webroot -ChildPath $configFileBaseRelativePath

    # Now we try to match the config file from the manifest to the actual config file by comparing their base names
    $matchedConfigFile = $null
    foreach ( $candidateConfigFile in (gci $configFileBaseFullPath)) {
        $candidateFileName = split-path -Path $candidateConfigFile -Leaf
        $candidateBaseFileName = Get-BaseConfigFileName -ConfigFileName $candidateFileName

        if ($candidateBaseFileName.ToLower() -eq $configFileBaseName.ToLower()) {
            #The match had been found
            $matchedConfigFile = $candidateConfigFile
            break
        }
    }

    if ($matchedConfigFile -eq $null) {
        Throw "Failed to find match for '$ManifestConfigFilePath' ( attempt: '$configFileBaseFullPath' )"
    }

    return $matchedConfigFile
}

function Process-ConfigFile {
    param (
        $Role,
        $Webroot,
        [System.Xml.XmlElement]$ManifestRecord
    )

    $roleConfigSetting = $ManifestRecord.SelectSingleNode($Role)
    if ($roleConfigSetting -eq $null) {
        throw "Failed to read '$Role' configuration on the manifest record  ( '$($ManifestRecord.OuterXml)' )"
    }

    $manifestRelativeFilePath = Join-Path -Path $ManifestRecord.FilePath -ChildPath $ManifestRecord.ConfigFileName
    $realConfigFile = Get-MatchingConfigFile -Webroot $Webroot -ManifestConfigFilePath $manifestRelativeFilePath 

    $realConfigFileName = Split-Path -Path $realConfigFile -Leaf
    $realConfigFileIsEnabled = ( $SCRIPT:CONFIG:EnabledFileExtensions.Contains([System.IO.Path]::GetExtension($realConfigFileName).ToLower()) )

    Trace -Info "Manifest file: '$manifestRelativeFilePath' ( resolved file: '$realConfigFile')"

    $status = "N/A"

    switch ($roleConfigSetting.InnerText.ToLower()) {
        "enable" { 
            if (-not $realConfigFileIsEnabled) {
                $status = "File has to be enabled but is disabled. Enabling file"
                Rename-Item -Path $realConfigFile -NewName ( [System.IO.Path]::ChangeExtension($realConfigFileName, $SCRIPT:CONFIG:EnabledFileExtensions[0]) )
            } else {
                $status = "File has to be ( and already is ) enabled. No further action required"
            }
        }
        "disable" { 
            if ($realConfigFileIsEnabled) {
                $status = "File has to be disabled but is enabled. Disabling file"
                Rename-Item -Path $realConfigFile -NewName ( [System.IO.Path]::ChangeExtension($realConfigFileName, $SCRIPT:CONFIG:DisabledFileExtensions[0]) )
            } else {
                $status = "File has to be ( and already is ) disabled. No further action required"
            }
        }
        "n/a" {
            $status = "The current role does not demand the file to be disabled or enabled ( config file is not being used in this configuration ). No action is to be performed"
        }
    }

    Trace -Info "  > STATUS: $status"

}


function Trace {
    [CmdletBinding(DefaultParametersetName="Info")] 
    param (
        [Parameter(ParameterSetName="Info")]
        [switch]$Info,
        [Parameter(ParameterSetName="Warn")]
        [switch]$Warn,
        [Parameter(ParameterSetName="Err")]
        [switch]$Err,
        [Parameter(Position=1)]
        $Message
    )

    $messageColor = (get-host).ui.rawui.ForegroundColor
    switch ( $PSCmdlet.ParameterSetName) {
        "Warn" { $messageColor = 'Yellow' }
        "Err" { $messageColor = 'Red' }
    }

    $timestamp = "[{0}] " -f (get-date -Format 'HH:mm:ss'),$Message

    write-host $timestamp -NoNewline
    if ($PSCmdlet.ParameterSetName -eq 'Info') {
        write-host $Message
    } else {
        write-host $Message -ForegroundColor $messageColor
    }
}
# END: HELPERS ###############################################



if (-not(Test-Path $Webroot -PathType Container)) {
    throw "'$Webroot' webroot folder not found"
}

if (-not(Test-Path (Join-Path -Path $Webroot -ChildPath "App_Config/Include"))) {
    throw "Sitecore configuration folder (App_Config/Include) not found under the webroot folder ($Webroot)"
}

