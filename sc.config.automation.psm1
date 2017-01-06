<#
 The module depends upon SC.Config.dll .NET extension ( which contains implementation of complex cmdlets )
 Verifying that the module is loaded ( the module dll is expected to be located in the same folder as the 
  PowerShell module psm1 file )
#>
if (-not (Get-Module SC.Config)) {
    Import-Module ( Join-Path -Path $PSScriptRoot -ChildPath 'SC.Config.dll') -ErrorAction Stop
}

<# README

        Configuration sections below contain the module parameters that can be edited in order to adjust the
          module to a particular situation.
        Any definition that starts with '$SCRIPT:CONFIG:' is anticipated to be changed / extended if needed
        Each configuration section has a brief description in the comments

#>

<# CONFIGURATION::FILE EXTENSIONS ##############################################
Describe extensions which are to be used by the module to determine ( set ) a configuration file state ( enabled / disabled )
First entry in each extension list is to be used as default extension ( while renaming files to enable / disable them ) #>
$SCRIPT:CONFIG:DisableFileExtensions = @('.disabled', '.example')
$SCRIPT:CONFIG:EnableFileExtensions = @('.config')

<# CONFIGURATION::SEARCH PROVIDERS ##############################################
Used by the module to "translate" manifest records to the corresponding search provider 
 ( as defined by the [SC.Config.Manifest.SearchProvider] .NET enumeration from the SC.Config .NET module ) #>
$SCRIPT:CONFIG:SearchProviderDictionary = @{
    Lucene = @('Base','Lucene is used');
    SOLR = @('Solr is used')
    Any = @('');
}

<# CONFIGURATION::MANIFEST ACTIONS #############################################
Use by the module to "translate" manifest records to the corresponding action 
 ( as defined by the [SC.Config.Manifest.Action] .NET enumeration from the SC.Config .NET module )  #>
$SCRIPT:CONFIG:EnableActionDescriptions = @('Enable')
$SCRIPT:CONFIG:DisableActionDescriptions = @('Disable')
$SCRIPT:CONFIG:NAActionDescriptions = @('n/a')

<# CONFIGURATION::MANIFEST ROLES #############################################
Use by the module to "translate" manifest roles from the manifest to the corresponding role enumeration 
 ( as defined by the [SC.Config.SitecoreRole] .NET enumeration from the SC.Config .NET module )  #>
$SCRIPT:CONFIG:ManifestRolesMapping = @{
    [SC.Config.SitecoreRole]::ContentDelivery                = 'Content Delivery (CD)';
    [SC.Config.SitecoreRole]::ContentManagement              = 'Content Management (CM)';
    [SC.Config.SitecoreRole]::ContentManagementAndProcessing = 'CM + Processing';
    [SC.Config.SitecoreRole]::Processing                     = 'Processing';
    [SC.Config.SitecoreRole]::Reporting                      = 'Reporting'
}

<# CONFIGURATION::MANIFEST PROPERTIES ########################################
Use by the module to "translate" manifest properties from the manifest to the corresponding 
  PowerShell expression ( in order to avoid hard-coding properties in the script #>
$SCRIPT:CONFIG:ManifestDictionary = @{
    SearchProviderUsed = 'Search Provider Used';
    FilePath           = 'File Path';
    ConfigFileName     = 'Config file name'
}


###############################################################################
# CONFIGURATION::END ##########################################################
###############################################################################

<# Below lies a misterious domain containing author's thoughts materialized into
PowerShell code. Proceed with caution at your own risk :-| #>


# HELPERS ####################################################
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

    if ($PSCmdlet.ParameterSetName -eq 'Info') {
        write-verbose ( "{0} {1}" -f ($timestamp,$Message) )
    } else {
        write-host $timestamp -NoNewline
        write-host $Message -ForegroundColor $messageColor
    }
}


<# "WRAPPER" for the Get-SearchProvider cmdlet ( to avoid passing all the config parameters every time )#>
function Resolve-SearchProvider {
    param (
        $SearchProviderDesc
    )

    return Get-SearchProvider `
            -SearchProviderDescription    $SearchProviderDesc `
            -LuceneProviderDescriptionSet $SCRIPT:CONFIG:SearchProviderDictionary.Lucene `
            -SOLRProviderDescriptionSet   $SCRIPT:CONFIG:SearchProviderDictionary.SOLR `
            -AnyProviderDescriptionSet    $SCRIPT:CONFIG:SearchProviderDictionary.Any
}

<# "WRAPPER" for the Get-SearchProvider cmdlet ( to avoid passing all the config parameters every time )#>
function Resolve-Action {
    param (
        $ActionDesc
    )

    return Get-ManifestAction `
            -ManifestActionDescription $ActionDesc `
            -EnableActionDescriptions  $SCRIPT:CONFIG:EnableActionDescriptions `
            -DisableActionDescriptions $SCRIPT:CONFIG:DisableActionDescriptions `
            -NAActionDescriptions      $SCRIPT:CONFIG:NAActionDescriptions `
}

<#
.SYNOPSIS 
    A manifest can comain multiple records for the same file ( with different search providers )
    Resolution: "compact" manifest ( group it by the target configuration file path )
    Then each configuration group is to be processed to determine best-suiting manifest record
.INPUTS
   ManifestRecordGroup - group of manifest records ( for the same config file )
   SearchProvider      - search provider that is to be used to resolve which record to use
.OUTPUTS
   ManifestRecord (best suited for the given context)
#>
function Resolve-ManifestRecord {
    param (
        $ManifestRecordGroup,
        [SC.Config.Manifest.SearchProvider]$SearchProvider
    )


    if ($ManifestRecordGroup.Count -eq 1) {
        return $ManifestRecordGroup.Group[0]
    }

    Trace -Info "Resolving manifest duplicates for the CONFIG:$($ManifestRecordGroup.Name)"
    
    #If there are more than 2 duplicates - throw in a towel
    if ($ManifestRecordGroup.Count -gt 2) {
        throw "$($ManifestRecordGroup.Count) duplicates found for the '$($ManifestRecordGroup.Name)' configuration file. Cannot be resolved (is not anticipated by the design of the utility, maximum 2 duplication for different search providers are supported )"
    }

    $dupA = $ManifestRecordGroup.Group[0]
    $dupB = $ManifestRecordGroup.Group[1]

    $dupASearchProvider = $dupA | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['SearchProviderUsed']
    $dupBSearchProvider = $dupB | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['SearchProviderUsed']

    $dupASearchProviderResolved = Resolve-SearchProvider -SearchProviderDesc $dupASearchProvider
    $dupBSearchProviderResolved = Resolve-SearchProvider -SearchProviderDesc $dupBSearchProvider
    
    #Check if search providers are different
    if ($dupASearchProviderResolved -ne $dupBSearchProviderResolved) {
        if ($dupASearchProviderResolved -eq $SearchProvider) {
            Trace -Info "Resolved $($ManifestRecordGroup.Count) config file duplicates ( using record for the '$dupASearchProviderResolved' search provider)"
            return $dupA
        } elseif ($dupBSearchProviderResolved -eq $SearchProvider) {
            Trace -Info "Resolved $($ManifestRecordGroup.Count) config file duplicates ( using record for the '$dupBSearchProviderResolved' search provider)"
            return $dupB
        } else {
            throw "Failed to resolve manifest duplicate for the '$($ManifestRecordGroup.Name)' configuration file. Neither record matches target search provider : '$($SearchProvider)')"
        }
    } else {
        #If search providers are the same - give up
        throw "Failed to resolve manifest duplicates for the '$($ManifestRecordGroup.Name)' configuration file. Duplicated records are for the same search provider ( it cannot be determined which one should be used )"
    }
}

# END: HELPERS ###############################################

<#
.Synopsis
   Script to verify or adjust configuration files of a Sitecore instance to fulfill particular Sitecore role in a scaled environment )
   ( Content Delivery, Content Management, Processing, Reporting ) 
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
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
function Use-Manifest {
[CmdletBinding()]
param (
    [switch]$Apply,
    [Parameter(Mandatory=$true)]
    [SC.Config.SitecoreRole]$Role,
    [Parameter(Mandatory=$true)]
    [ValidateSet('Lucene', 'SOLR')]
    [SC.Config.Manifest.SearchProvider]$SearchProvider,
    [Parameter(Mandatory=$true)]
    $Webroot,
    [Parameter(Mandatory=$true)]
    $ConfigurationManifest
)

    if (-not(Test-Path $Webroot -PathType Container)) {
        throw "'$Webroot' webroot folder not found"
    }

    if (-not(Test-Path (Join-Path -Path $Webroot -ChildPath "App_Config/Include"))) {
        throw "Sitecore configuration folder (App_Config/Include) not found under the webroot folder ($Webroot)"
    }

    if (-not(Test-Path -Path $ConfigurationManifest -PathType Leaf)) {
        throw "Failed to find configuration manifest '$ConfigurationManifest'"
    }


    #A manifest can comain multiple records for the same file ( with different search providers )
    # Resolution: "compact" manifest ( group it by the target configuration file path )
    #             Then each configuration group is to be processed to determine 
    #             best-suiting manifest record
    $sconfig = (Import-Csv $ConfigurationManifest ) | Group-Object `
        -Property { 
            Join-Path `
                -Path      ($_ | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['FilePath']) `
                -ChildPath ($_ | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['ConfigFileName']) 
        }

    $executionTrace = @()

    Trace -Info "Processing manifest"
    $sconfig | % { 
        try {
            # Resolving the matching manifest record data from the group ( of manifest records for the same configuration file )
            $manifestRecordData = Resolve-ManifestRecord -ManifestRecordGroup $_ -SearchProvider $SearchProvider
            
            # Determining the action to be applied ( as per the specified configuration role )
            $manifestRoleDesc = $SCRIPT:CONFIG:ManifestRolesMapping[$Role]
            $currentAction = Resolve-Action -ActionDesc ( $manifestRecordData."$manifestRoleDesc" )
            Trace -Info "Current action resolved to '$currentAction'"

            # "Translating" the manifest record data to the object being used by .NET cmdlets
            $manifestRecord = Get-ManifestRecord `
                -Action             $currentAction `
                -SearchProviderUsed $SearchProvider `
                -FilePath           ( $manifestRecordData | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['FilePath'] ) `
                -ConfigFileName     ( $manifestRecordData | Select-Object -ExpandProperty $SCRIPT:CONFIG:ManifestDictionary['ConfigFileName'] )  

            $traceRecord = Use-ManifestRecord `
                -Apply:$Apply `
                -TargetSearchProvider     $SearchProvider `
                -Webroot                  $Webroot `
                -ManifestRecord           $manifestRecord `
                -SCDisableExtensionsList  $SCRIPT:CONFIG:DisableFileExtensions `
                -SCEnableExtensionsList   $SCRIPT:CONFIG:EnableFileExtensions

            if ($traceRecord -ne $null) {
                $executionTrace += $traceRecord
                $screenMsg = "[$($traceRecord.Status)][$($traceRecord.StatusDetails)] $($traceRecord.RealConfigFilePath)"
                if ($traceRecord.Status -eq [SC.Config.Trace.Status]::FAIL ) {
                    Trace -Err $screenMsg 
                } elseif ($traceRecord.Status -eq [SC.Config.Trace.Status]::ACTION ) {
                    Trace -Highlight $screenMsg
                } else {
                    Trace -Info $screenMsg
                }
            }
        } catch { 
            Trace -Err -Message $_.Exception.Message
            $_.Exception | Write-Error
        } 
    }

    return $executionTrace
}

<# ONLY EXPORTING MODULE MEMBERS WHICH ARE INTENDED TO BE USED OUTSIDE OF THE MODULE #>
Export-ModuleMember -Function Use-Manifest