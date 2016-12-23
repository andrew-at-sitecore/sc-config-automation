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
    [string]$Role,
    [string]$SearchProvider,
    $Webroot,
    $ConfigurationManifest
)

# CONFIGURATION::FILE EXTENSIONS ##############################################
# NOTE: anticipated to be edited by end user to adjust for desired behavior
# NOTE: extensions must be lower case
# NOTE: first entry in each extension list is to be used as default extension ( while renaming files to enable / disable them )
$SCRIPT:CONFIG:DisabledFileExtensions = @('.disabled', '.example')
$SCRIPT:CONFIG:EnabledFileExtensions = @('.config')

# CONFIGURATION::SEARCH PROVIDERS ##############################################
# NOTE: anticipated to be edited by end user ( in case some manifest records differ )
# NOTE: used by script to "translate" actual manifest records to the corresponding search provider ( to resolve some ambiguity )
$SCRIPT:CONFIG:SearchProviderDictionary = @{
    Any = @('');
    Lucene = @('Base','Lucene is used');
    Solr = @('Solr is used')
}

# CONFIGURATION::MANIFEST  #####################################################
# NOTE: anticipated to be edited by end user ( in case some manifest records differ )
# NOTE: used by script to "translate" from hardcoded (keys) to actual (values) properties of records from a manifest
#       (only for the manifest properties describing supported configuration roles)
#       (implemented as a separate dictionary because it doubles as source for verification of the script 'Role' parameter) 
$SCRIPT:CONFIG:ManifestDictionarySupportedRoles = @{
    ContentDelivery = 'Content Delivery (CD)';
    ContentManagement = 'Content Management (CM)';
    Processing = 'Processing';
    CMAndProcessing = 'CM + Processing';
    Reporting = 'Reporting'
}
# NOTE: anticipated to be edited by end user ( in case some manifest records differ )
# NOTE: used by script to "translate" from hardcoded (keys) to actual (values) properties of records from a manifest 
#       (other properties except of supported configuration roles) 
$SCRIPT:CONFIG:ManifestDictionaryOther = @{
    Product = 'Product Name';
    FilePath = 'File Path';
    ConfigFileName = 'Config file name';
    ConfigType = 'Config Type';
    SearchProviderUsed = 'Search Provider Used'
}
# NOTE: this dictionary ( combination of SCRIPT:CONFIG:ManifestDictionaryOther and SCRIPT:CONFIG:ManifestDictionarySupportedRoles )
#       is being actually used in the code
$SCRIPT:CONFIG:ManifestDictionary = $SCRIPT:CONFIG:ManifestDictionaryOther + $SCRIPT:CONFIG:ManifestDictionarySupportedRoles
# CONFIGURATION::END ##########################################################

# HELPERS ####################################################
function Get-StandardizedSearchProviderNameOrNull {
    param (
        $SearchProviderName
    )
    foreach ($key in $SCRIPT:CONFIG:SearchProviderDictionary.Keys) {
        if ($SCRIPT:CONFIG:SearchProviderDictionary[$key].Contains($SearchProviderName)) {
            return $key
        }
    }
    return $null
}

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

function Change-FileExtension {
    param (
        $ConfigFile,
        $TraceRecord,
        $NewExtension
    )

    try {
        $configFileName= Split-Path -Path $ConfigFile -Leaf
        $newFileName = [System.IO.Path]::ChangeExtension($configFileName, $NewExtension)
        Rename-Item -Path $ConfigFile -NewName $newFileName -ErrorAction Stop
        $TraceRecord.ProcessingTrace += "Renamed '$ConfigFile' -> '$newFileName'"
        $TraceRecord.Status = 'Disabled'
    } catch {
        $TraceRecord.ProcessingTrace += "$($_.Exception.Message)"
        $TraceRecord.ProcessingTrace += "$($_.Exception.StackTrace)"
        $TraceRecord.Status = 'Failed to disable'
    } 
    
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
        Rename-Item -Path $ConfigFile -NewName $newFileName -ErrorAction Stop
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
        Rename-Item -Path $ConfigFile -NewName $newFileName -ErrorAction Stop
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
        $ManifestRecord
    )

    # $LOCAL is used for estetic purposes ( so that it is clear the variables are local to the function and easier to identify visually )
    $LOCAL:MNFST:FilePath = $ManifestRecord | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['FilePath']
    $LOCAL:MNFST:ConfigFileName = $ManifestRecord | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['ConfigFileName']
    $LOCAL:MNFST:SearchProviderUsed = $ManifestRecord | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['SearchProviderUsed']
    $LOCAL:MNFST:Role = $Role
    $LOCAL:MNFST:RoleAction = $ManifestRecord | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary[$Role]
    $LOCAL:MNFST:ManifestStr = $ManifestRecord | Out-String

    $LOCAL:SEARCH:ManifestProvider = Get-StandardizedSearchProviderNameOrNull -SearchProviderName $LOCAL:MNFST:SearchProviderUsed
    $LOCAL:SEARCH:TargetProvider = $SearchProvider 

    $manifestRelativeFilePath = Join-Path -Path $LOCAL:MNFST:FilePath -ChildPath $LOCAL:MNFST:ConfigFileName

    $realConfigFile = Get-MatchingConfigFile -Webroot $Webroot -ManifestConfigFilePath $manifestRelativeFilePath 
    $realConfigFileName = Split-Path -Path $realConfigFile -Leaf
    $realConfigFileIsEnabled = ( $SCRIPT:CONFIG:EnabledFileExtensions.Contains([System.IO.Path]::GetExtension($realConfigFileName).ToLower()) )

    $manifestRecordSearchProvider = $LOCAL:SEARCH:ManifestProvider
    $manifestRecordSearchProviderDisplayName = $LOCAL:MNFST:SearchProviderUsed

    $traceRecord = new-object psobject -Property @{
        ManifestRecord = $LOCAL:MNFST:ManifestStr;
        ManifestRelativePath = $manifestRelativeFilePath;
        ManifestSearchProvider = $manifestRecordSearchProviderDisplayName;
        RealConfigFile = $realConfigFile;
        ProcessingTrace = @();
        Status = 'N\A'
    }

    $roleConfigSetting = $LOCAL:MNFST:RoleAction
    if ($roleConfigSetting -eq $null) {
        $msg = "Failed to read '$Role' configuration on the manifest record  [$($LOCAL:MNFST:ManifestStr)]"
        $traceRecord.Status = 'Failed'
        $traceRecord.ProcessingTrace += $msg
        return $traceRecord
    }

    if ( ($manifestRecordSearchProvider.ToLower() -ne 'any') -and ($manifestRecordSearchProvider.ToLower() -ne $LOCAL:SEARCH:TargetProvider.ToLower()) ) {
        if (-not $realConfigFileIsEnabled) {
            # Search provider does not match the target search provider ( but the config file is already disabled )
            $traceRecord.ProcessingTrace += " > File has to be ( and already is ) disabled due to mismatching search providers ( Target:'$($LOCAL:SEARCH:TargetProvider)'; Manifest:'$manifestRecordSearchProvider'). No further action required"
            $traceRecord.Status = 'OK'
        } else {
            # Search provider does not match the target search provider ( and the config file is still enabled - needs to be disabled )
            $traceRecord.ProcessingTrace += "The manifest record is for '$manifestRecordSearchProvider' ($manifestRecordSearchProviderDisplayName) search provider whereas target search provider for the operation is set to '$($LOCAL:SEARCH:TargetProvider)'. The configuration file needs to be disabled"
            if ($PSCmdlet.ParameterSetName -eq 'Apply') {
                Do-DisableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
            } else {
                $traceRecord.Status = 'Needs to be disabled'
            }
        }
        return $traceRecord
    } 

    # Proceed if search provider is the same
    switch ($roleConfigSetting.ToLower()) {
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

<#
.SYNOPSIS 
    Accounting for situation when there are duplicate manifest records for the same file ( with different search providers )
    Resolution: if there is - filter out manifest records where the search provider is different from the target search provider
.INPUTS
   Manifest (collection of manifest records)
.OUTPUTS
   Filtered manifest (collection of manifest records where duplicates have been removed)
#>
function Remove-DuplicateManifestEntries {
    param (
        $Manifest,
        $TargetSearchProvider
    )
    #Find duplicate records
    $ManifestGroupped = $Manifest | Group-Object -Property { Join-Path -Path ($_ | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['FilePath']) -ChildPath ($_ | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['ConfigFileName']) }

    $ManifestDuplications = $ManifestGroupped | ? { $_.Count -gt 1 }
    Trace -Warn "$($ManifestDuplications.Length) duplicate manifest records identified. Processing ..."
    
    $ExcludeList = @()

    $processedCounter = 0
    foreach ( $DuplicationGroup in $ManifestDuplications) {
        $processedCounter += 1
        Trace -Info "Processing #$processedCounter CONFIG:$($DuplicationGroup.Name)"
        #If there are more than 2 duplicates - throw in a towel
        if ($DuplicationGroup.Count -gt 2) {
            throw "$($DuplicationGroup.Count) duplicates found for the '$($DuplicationGroup.Name)' configuration file. Cannot be resolved (is not anticipated by the design of the utility)"
        }

        $dupA = $DuplicationGroup.Group[0]
        $dupB = $DuplicationGroup.Group[1]

        $dupASearchProvider = $dupA | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['SearchProviderUsed']
        $dupBSearchProvider = $dupB | select -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['SearchProviderUsed']
        $dupASearchProviderResolved = Get-StandardizedSearchProviderNameOrNull -SearchProviderName $dupASearchProvider
        $dupBSearchProviderResolved = Get-StandardizedSearchProviderNameOrNull -SearchProviderName $dupBSearchProvider
        #Check if search providers are different
        if ($dupASearchProviderResolved -ne $dupBSearchProviderResolved) {
            if ($dupASearchProviderResolved -eq $TargetSearchProvider) {
                $ExcludeList += $dupB
                Trace -Info "Added to exclude list ( the record for the '$dupBSearchProvider' search provider)"
                continue
            } elseif ($dupBSearchProviderResolved -eq $TargetSearchProvider) {
                $ExcludeList += $dupA
                Trace -Info "Added to exclude list ( the record for the '$dupASearchProvider' search provider)"
                continue
            } else {
                throw "Failed to process duplicate ( neither record matches target search provider : '$($TargetSearchProvider)'). Duplicate info: $DuplicationGroup"
            }
        } else {
            #If search providers are the same - check for instructions
            if ( (
                  $dupA | select `
                    $SCRIPT:CONFIG:ManifestDictionary['ContentDelivery'], `
                    $SCRIPT:CONFIG:ManifestDictionary['ContentManagement'], `
                    $SCRIPT:CONFIG:ManifestDictionary['Processing'], ` 
                    $SCRIPT:CONFIG:ManifestDictionary['CMAndProcessing'], ` 
                    $SCRIPT:CONFIG:ManifestDictionary['Reporting'] 
                 ) -eq (
                  $dupB | select `
                    $SCRIPT:CONFIG:ManifestDictionary['ContentDelivery'], `
                    $SCRIPT:CONFIG:ManifestDictionary['ContentManagement'], `
                    $SCRIPT:CONFIG:ManifestDictionary['Processing'], ` 
                    $SCRIPT:CONFIG:ManifestDictionary['CMAndProcessing'], ` 
                    $SCRIPT:CONFIG:ManifestDictionary['Reporting'] 
                ) ) {
                Trace -Warn "There are two duplicate records for the '$($DuplicationGroup.Name)' configuration file with identical settings."
            } else {
                Trace -Warn "There are two duplicate records for the '$($DuplicationGroup.Name)' configuration file with different settings."
            }
            throw "Failed to resolve ambiguity ( recommended to edit manifest file as per above messages )"
        }
    }

    return $Manifest | ? { $ExcludeList -notcontains $_ }
}

# END: HELPERS ###############################################

#Validate $Role
if (-not($SCRIPT:CONFIG:ManifestDictionarySupportedRoles.ContainsKey($Role))) {
    Write-Warning "'$Role'is not supported configuration role. Supported configuration roles list is:"
    Write-Warning $SCRIPT:CONFIG:ManifestDictionarySupportedRoles.Keys
    return
}
#Validate $SearchProvider
if (-not($SCRIPT:CONFIG:SearchProviderDictionary.ContainsKey($SearchProvider))) {
    Write-Warning "'$SearchProvider' is not supported search provider. Supported search providers list is:"
    Write-Warning $SCRIPT:CONFIG:SearchProviderDictionary.Keys
    return 
}

if (-not(Test-Path $Webroot -PathType Container)) {
    throw "'$Webroot' webroot folder not found"
}

if (-not(Test-Path (Join-Path -Path $Webroot -ChildPath "App_Config/Include"))) {
    throw "Sitecore configuration folder (App_Config/Include) not found under the webroot folder ($Webroot)"
}

if (-not(Test-Path -Path $ConfigurationManifest -PathType Leaf)) {
    throw "Failed to find configuration manifest '$ConfigurationManifest'"
}

$sconfig = Import-Csv $ConfigurationManifest

$executionTrace = @()
$traceRecord = $null

$sconfigOrig = $sconfig
$sconfig = Remove-DuplicateManifestEntries -Manifest $sconfig -TargetSearchProvider $SearchProvider

if ($sconfigOrig -ne $sconfig) {
    Trace -Highlight "Listing removed entries"
    foreach ($record in $sconfigOrig) {
        if ($sconfig -notcontains $record) {
            $record | Out-String | Write-Host
        }
    }
}

Trace -Highlight "Processing manifest"
$sconfig | % { 
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