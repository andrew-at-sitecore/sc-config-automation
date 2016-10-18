<#
    sc-config-manifest -ListProducts -Manifest ...
    sc-config-manifest -ListRoles -Manifest ...
#>
param (
    [xml]$Manifest
)

#XML manifest properties that define functional aspects of each record 
#   ( all other properties are to be considered Role properties )
$SCRIPT:CONFIG:FunctionalProperties = @('Product', 'FilePath', 'ConfigFileName', 'ConfigType')
$SCRIPT:CONFIG:ManifestDefinitionsXPath = "/scconfigmanifest/record"

function Get-Roles {
    param ( [xml]$Manifest )

    $record = $Manifest.SelectSingleNode($SCRIPT:CONFIG:ManifestDefinitionsXPath)

    $roleList = @()

    foreach ( $node in $record.ChildNodes ) {
        if (-not ($SCRIPT:CONFIG:FunctionalProperties.Contains($node.Name))) {
            $roleList += $node.Name
        }
    }

    return $roleList
}


function Get-Products {
    param ( [switch]$WithNumberOfConfigs, [xml]$Manifest )

    $manifestDefinitions = $Manifest.SelectNodes($SCRIPT:CONFIG:ManifestDefinitionsXPath)

    $productList = $manifestDefinitions | select -ExpandProperty Product | sort | Get-Unique

    if (-not $WithNumberOfConfigs ) {
        return $productList
    }

    $productInfo = @{}

    foreach ($product in $productList) {
        $numberOfConfigFiles = $manifestDefinitions | ? { $_.Product -eq $product } | % { "{0}\{1}" -f $_.FilePath, $_.ConfigFileName } | measure | select -ExpandProperty Count
        
        $productInfo.Add($product, $numberOfConfigFiles)
    }

    return $productInfo.GetEnumerator() | sort -Property Name
}

function Get-ProductConfigs {
    param ( [string]$Product , [xml]$Manifest)

    $manifestDefinitions = $Manifest.SelectNodes($SCRIPT:CONFIG:ManifestDefinitionsXPath)

    $listOfConfigFiles = $manifestDefinitions | ? { $_.Product -eq $product } | % { Join-Path -Path $_.FilePath -ChildPath $_.ConfigFileName }

    return $listOfConfigFiles
}

