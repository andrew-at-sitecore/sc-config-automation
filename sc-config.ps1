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
    [Parameter(Mandatory=$true,ParameterSetName="Apply")]
    [switch]$ApplyManifest,
    [Parameter(Mandatory=$true,ParameterSetName="Verify")]
    [switch]$Verify,
    $Role,
    $SearchProvider,
    $Webroot,
    $ConfigurationManifest
)

# CONFIGURATION ##############################################
# NOTE: extensions must be lower case
# NOTE: first entry in each extension list is to be used as default extension ( while renaming files to enable / disable them )
$SCRIPT:CONFIG:DisabledFileExtensions = @('.disabled', '.example')
$SCRIPT:CONFIG:EnabledFileExtensions = @('.config')

$SCRIPT:CONFIG:ManifestDefinitionsXPath = "/scconfigmanifest/record"
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

    # Check that target location exists
    $configTargetLocation = Split-Path -Path $configFileBaseFullPath -Parent
    if (-not (Test-Path -Path $configTargetLocation -PathType Container )) {
        throw "Target location directory '$configTargetLocation' does not exist ( processing '$ManifestConfigFilePath' entry from the configuration manifest )"
    }

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

function Do-DisableConfigFile {
    param (
        $ConfigFile,
        $TraceRecord
    )

    try {
        #TODO: try do remove disable extensions first ( and verify that what is left is enable extension)
        $configFileName= Split-Path -Path $ConfigFile -Leaf
        $newFileName = [System.IO.Path]::ChangeExtension($configFileName, $SCRIPT:CONFIG:DisabledFileExtensions[0])
        Rename-Item -Path $ConfigFile -NewName $newFileName
        $TraceRecord.ProcessingTrace += "Renamed '$ConfigFile' -> '$newFileName'"
        $TraceRecord.Status = 'Disabled'
    } catch {
        $TraceRecord.ProcessingTrace += "$($_.Exception.Message)"
        $TraceRecord.ProcessingTrace += "$($_.Exception.StackTrace)"
        $TraceRecord.Status = 'Failed to disable'
    } 
}

function Do-EnableConfigFile {
    param (
        $ConfigFile,
        $TraceRecord
    )

    try {
        $configFileName = Split-Path -Path $ConfigFile -Leaf
        $newFileName = [System.IO.Path]::ChangeExtension($configFileName, $SCRIPT:CONFIG:EnabledFileExtensions[0])
        Rename-Item -Path $ConfigFile -NewName $newFileName
        $TraceRecord.ProcessingTrace += "Renamed '$ConfigFile' -> '$newFileName'"
        $TraceRecord.Status = 'Enabled'
    } catch {
        $TraceRecord.ProcessingTrace += "$($_.Exception.Message)"
        $TraceRecord.ProcessingTrace += "$($_.Exception.StackTrace)"
        $TraceRecord.Status = 'Failed to enable'
    }
}

function Process-ConfigFile {
    param (
        [Parameter(Mandatory=$true,ParameterSetName="Apply")]
        [switch]$ApplyManifest,
        [Parameter(Mandatory=$true,ParameterSetName="Verify")]
        [switch]$Verify,
        [Parameter(Mandatory=$true)]
        $Role,
        [Parameter(Mandatory=$true)]
        $SearchProvider,
        [Parameter(Mandatory=$true)]
        $Webroot,
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlElement]$ManifestRecord
    )

    $manifestRelativeFilePath = Join-Path -Path $ManifestRecord.FilePath -ChildPath $ManifestRecord.ConfigFileName

    $realConfigFile = Get-MatchingConfigFile -Webroot $Webroot -ManifestConfigFilePath $manifestRelativeFilePath 
    $realConfigFileName = Split-Path -Path $realConfigFile -Leaf
    $realConfigFileIsEnabled = ( $SCRIPT:CONFIG:EnabledFileExtensions.Contains([System.IO.Path]::GetExtension($realConfigFileName).ToLower()) )

    # Clarifying if there is specific search provider associated with the manifest record
    $manifestRecordSearchProvider = $null
    $manifestRecordSearchProviderDisplayName = "NONE"
    $manifestRecordSearchConfig = $ManifestRecord.SelectSingleNode('SearchProviderUsed')
    if ($manifestRecordSearchConfig -ne $null) {
        $manifestRecordSearchProvider = $manifestRecordSearchConfig.InnerText
        $manifestRecordSearchProviderDisplayName = $manifestRecordSearchConfig.InnerText
    }

    $traceRecord = new-object psobject -Property @{
        ManifestRecord = $ManifestRecord.OuterXml;
        ManifestRelativePath = $manifestRelativeFilePath;
        ManifestSearchProvider = $manifestRecordSearchProviderDisplayName;
        RealConfigFile = $realConfigFile;
        ProcessingTrace = @();
        Status = 'N\A'
    }

    $roleConfigSetting = $ManifestRecord.SelectSingleNode($Role)
    if ($roleConfigSetting -eq $null) {
        $msg = "Failed to read '$Role' configuration on the manifest record  ( '$($ManifestRecord.OuterXml)' )"
        $traceRecord.Status = 'Failed'
        $traceRecord.ProcessingTrace += $msg
        return $traceRecord
    }

    if ( ($manifestRecordSearchProvider -ne $null) -and ($manifestRecordSearchProvider.ToLower() -ne $SearchProvider.ToLower()) ) {
        $traceRecord.ProcessingTrace += "The manifest record is for '$manifestRecordSearchProvider' search provider whereas target search provider for the operation is set to '$SearchProvider'. The configuration file needs to be disabled"
        if ($PSCmdlet.ParameterSetName -eq 'Apply') {
            Do-DisableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
        } else {
            $traceRecord.Status = 'Needs to be disabled'
        }
        return $traceRecord
    } 

    # Proceed if search provider is the same
    switch ($roleConfigSetting.InnerText.ToLower()) {
        "enable" {
            if (-not $realConfigFileIsEnabled) {
                $traceRecord.ProcessingTrace += " > The configuration file is disabled ( has to be enabled as per manifest )"
                if ($PSCmdlet.ParameterSetName -eq 'Apply') {
                    Do-EnableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
                } else {
                    $traceRecord.Status = 'Needs to be enabled'
                }
            } else {
                $traceRecord.ProcessingTrace += " > File has to be ( and already is ) enabled. No further action required"
                $traceRecord.Status = 'OK'
            }
        }
        "disable" { 
            if ($realConfigFileIsEnabled) {
                $traceRecord.ProcessingTrace += " > The configuration file is enabled ( has to be disabled as per manifest )"
                if ($PSCmdlet.ParameterSetName -eq 'Apply') {
                    Do-DisableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
                } else {
                    $traceRecord.Status = 'Needs to be disabled'
                }
            } else {
                $traceRecord.ProcessingTrace += " > File has to be ( and already is ) disabled. No further action required"
                $traceRecord.Status = 'OK'
            }
        }
        "n/a" {
            $traceRecord.ProcessingTrace += " > The current role does not demand the file to be disabled or enabled ( config file is not being used in this configuration ). No action is to be performed"
            $traceRecord.Status = 'OK'
        }
    }

    return $traceRecord
}

function Trace {
    [CmdletBinding(DefaultParametersetName="Info")] 
    param (
        [Parameter(ParameterSetName="Info")]
        [switch]$Info,
        [Parameter(ParameterSetName="Highlight")]
        [switch]$Highlight,
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
        "Highlight" { $messageColor = 'Cyan'}
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

if (-not(Test-Path -Path $ConfigurationManifest -PathType Leaf)) {
    throw "Failed to find configuration manifest '$ConfigurationManifest'"
}

$sconfig = [xml](gc $ConfigurationManifest)

$executionTrace = @()
$traceRecord = $null
$sconfig.SelectNodes($SCRIPT:CONFIG:ManifestDefinitionsXPath) | % { 
    try {
        if ($PSCmdlet.ParameterSetName -eq 'Verify') { 
            $traceRecord = Process-ConfigFile -Verify -Role $Role -SearchProvider $SearchProvider -Webroot $Webroot -ManifestRecord $_
        } elseif ($PSCmdlet.ParameterSetName -eq 'Apply') {
            $traceRecord = Process-ConfigFile -ApplyManifest -Role $Role -SearchProvider $SearchProvider -Webroot $Webroot -ManifestRecord $_
        }

        if ($traceRecord -ne $null) {
            $executionTrace += $traceRecord
            $screenMsg = "[$($traceRecord.Status)] $($traceRecord.RealConfigFile)" 
            if ($traceRecord.Status -like 'Fail.*') {
                Trace -Err $screenMsg 
            } elseif ($traceRecord.Status -ne 'OK') {
                Trace -Highlight $screenMsg
            } else {
                Trace -Info $screenMsg
            }
        }
    } catch { 
            Trace -Err -Message $_.Exception.Message 
    } 
}

return $executionTrace
