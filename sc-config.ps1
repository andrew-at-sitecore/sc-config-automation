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

# END: HELPERS ###############################################



if (-not(Test-Path $Webroot -PathType Container)) {
    throw "'$Webroot' webroot folder not found"
}

if (-not(Test-Path (Join-Path -Path $Webroot -ChildPath "App_Config/Include"))) {
    throw "Sitecore configuration folder (App_Config/Include) not found under the webroot folder ($Webroot)"
}

