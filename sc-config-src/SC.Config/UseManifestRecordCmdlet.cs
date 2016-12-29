using SC.Config.Manifest;
using SC.Config.Trace;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  [Cmdlet(VerbsOther.Use, "ManifestRecord")]
  [OutputType(typeof(TraceRecord))]
  public class UseManifestRecordCmdlet : Cmdlet
  {
    [Parameter(ParameterSetName = "Apply")]
    public bool ApplyManifest { get; set; }
    [Parameter(ParameterSetName = "Verify")]
    public bool Verify { get; set; }
    [Parameter(Mandatory = true)]
    public string Role { get; set; }
    [Parameter(Mandatory = true)]
    public string SearchProvider { get; set; }
    [Parameter(Mandatory = true)]
    public string Webroot { get; set; }
    [Parameter(Mandatory = true)]
    public ManifestRecord ManifestRecord { get; set; }

    protected override void ProcessRecord()
    {
      //$realConfigFile = Get - MatchingConfigFile - Webroot $Webroot - ManifestConfigFilePath $manifestRelativeFilePath
      //$realConfigFileName = Split - Path - Path $realConfigFile - Leaf
      //$realConfigFileIsEnabled = ( $SCRIPT: CONFIG: EnabledFileExtensions.Contains([System.IO.Path]::GetExtension($realConfigFileName).ToLower()) )

      //$manifestRecordSearchProvider = $LOCAL: SEARCH: ManifestProvider
      //$manifestRecordSearchProviderDisplayName = $LOCAL: MNFST: SearchProviderUsed

      //$traceRecord = new- object psobject - Property @{
      //    ManifestRecord = $LOCAL: MNFST: ManifestStr;
      //    ManifestRelativePath = $manifestRelativeFilePath;
      //    ManifestSearchProvider = $manifestRecordSearchProviderDisplayName;
      //    RealConfigFile = $realConfigFile;
      //    ProcessingTrace = @();
      //    Status = 'N\A'
      //  }

      //$roleConfigSetting = $LOCAL: MNFST: RoleAction
      //if ($roleConfigSetting - eq $null) {
      //    $msg = "Failed to read '$Role' configuration on the manifest record  [$($LOCAL:MNFST:ManifestStr)]"
      //     $traceRecord.Status = 'Failed'
      //     $traceRecord.ProcessingTrace += $msg
      //     return $traceRecord
      // }

      //  if (($manifestRecordSearchProvider.ToLower() - ne 'any') -and($manifestRecordSearchProvider.ToLower() - ne $LOCAL: SEARCH:TargetProvider.ToLower()) ) {
      //    if (-not $realConfigFileIsEnabled) {
      //        # Search provider does not match the target search provider ( but the config file is already disabled )
      //        $traceRecord.ProcessingTrace += " > File has to be ( and already is ) disabled due to mismatching search providers ( Target:'$($LOCAL:SEARCH:TargetProvider)'; Manifest:'$manifestRecordSearchProvider'). No further action required"
      //        $traceRecord.Status = 'OK'
      //    } else {
      //        # Search provider does not match the target search provider ( and the config file is still enabled - needs to be disabled )
      //        $traceRecord.ProcessingTrace += "The manifest record is for '$manifestRecordSearchProvider' ($manifestRecordSearchProviderDisplayName) search provider whereas target search provider for the operation is set to '$($LOCAL:SEARCH:TargetProvider)'. The configuration file needs to be disabled"
      //        if ($PSCmdlet.ParameterSetName - eq 'Apply') {
      //        Do - DisableConfigFile - ConfigFile $realConfigFile - TraceRecord $traceRecord
      //         } else {
      //            $traceRecord.Status = 'Needs to be disabled'
      //        }
      //    }
      //    return $traceRecord

    }
  }
}
