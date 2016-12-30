using SC.Config.Manifest;
using SC.Config.Trace;
using SC.Config.Utils;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  [Cmdlet(VerbsOther.Use, "ManifestRecord")]
  [OutputType(typeof(TraceRecord))]
  public class UseManifestRecordCmdlet : PSCmdlet
  {
    private const string ApplyModeIdentifier = "Apply";
    private const string VerifyModeIdentifier = "Verify";

    [Parameter(Mandatory = true, ParameterSetName = ApplyModeIdentifier)]
    public bool ApplyManifest { get; set; }
    [Parameter(Mandatory = true, ParameterSetName = VerifyModeIdentifier)]
    public bool Verify { get; set; }
    [Parameter(Mandatory = true)]
    public string Role { get; set; }
    [Parameter(Mandatory = true)]
    public SearchProvider TargetSearchProvider { get; set; }
    [Parameter(Mandatory = true)]
    public string Webroot { get; set; }
    [Parameter(Mandatory = true)]
    public ManifestRecord ManifestRecord { get; set; }
    [Parameter(Mandatory = true)]
    public string[] SCDisabledExtensionsList { get; set; }
    [Parameter(Mandatory = true)]
    public string[] SCEnabledExtensionsList { get; set; }

    protected override void ProcessRecord()
    {
      var traceRecord = new TraceRecord()
      {
        ManifestRecord = this.ManifestRecord.ToString(),
        ManifestRelativePath = this.ManifestRecord.RelativeFilePath,
        ManifestSearchProvider = Enum.GetName(typeof(SearchProvider), this.ManifestRecord.SearchProvider),
        Status = Status.NA
      };

      var fileUtil = new FileUtil(this.SCDisabledExtensionsList, this.SCEnabledExtensionsList);

      var realConfigFile = fileUtil.TryGetMatchingConfigFile(this.Webroot, this.ManifestRecord.FilePath, this.ManifestRecord.ConfigFileName);
      traceRecord.RealConfigFilePath = realConfigFile;

      var realConfigFileName = Path.GetFileName(realConfigFile);

      //Case insensitive extension check. If the extension is not in "enabled" it is in "disabled"
      //    In fact - the only enabled extension is .config ( but the implementation was done for more generic case )
      var realConfigFileIsEnabled = this.SCEnabledExtensionsList.Select(x => x.ToLower()).Contains(Path.GetExtension(realConfigFileName).ToLower());

      if ((this.TargetSearchProvider != SearchProvider.Any) &&
            (this.ManifestRecord.SearchProvider != this.TargetSearchProvider))
      {
        if (!realConfigFileIsEnabled)
        {
          //Search provider does not match the target search provider ( but the config file is already disabled )
          traceRecord.ProcessingTrace.Add($" > File has to be ( and already is ) disabled due to mismatching search providers ( Target:'{this.TargetSearchProvider}'; Manifest:'{this.ManifestRecord.SearchProvider}'). No further action required");
          traceRecord.Status = Status.OK;
        }
        else
        {
          //Search provider does not match the target search provider ( and the config file is still enabled - needs to be disabled )
          traceRecord.ProcessingTrace.Add($"The manifest record is for '{this.ManifestRecord.SearchProvider}' search provider whereas target search provider for the operation is '{this.TargetSearchProvider}'. The configuration file needs to be disabled");
          switch (ParameterSetName)
          {
            case ApplyModeIdentifier:
              fileUtil.TryDisableConfigFile(realConfigFile);
              traceRecord.Status = Status.OK;
              traceRecord.StatusDetails = "Had been disabled";
              break;
            case VerifyModeIdentifier:
              traceRecord.Status = Status.ACTION;
              traceRecord.StatusDetails = "Needs to be disabled";
              break;
            default:
              throw new Exception($"Unrecognized parameter set: '{ParameterSetName}'");
          }
        }
        WriteObject(traceRecord);
        return;
      }

      throw new NotImplementedException();
      //# Proceed if search provider is the same
      //switch ($roleConfigSetting.ToLower()) {
      //    "enable" {
      //        if (-not $realConfigFileIsEnabled) {
      //            $traceRecord.ProcessingTrace += " > The configuration file is disabled ( has to be enabled as per manifest )"
      //            if ($PSCmdlet.ParameterSetName -eq 'Apply') {
      //                Do-EnableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
      //            } else {
      //                $traceRecord.Status = 'Needs to be enabled'
      //            }
      //        } else {
      //            $traceRecord.ProcessingTrace += " > File has to be ( and already is ) enabled. No further action required"
      //            $traceRecord.Status = 'OK'
      //        }
      //    }
      //    "disable" { 
      //        if ($realConfigFileIsEnabled) {
      //            $traceRecord.ProcessingTrace += " > The configuration file is enabled ( has to be disabled as per manifest )"
      //            if ($PSCmdlet.ParameterSetName -eq 'Apply') {
      //                Do-DisableConfigFile -ConfigFile $realConfigFile -TraceRecord $traceRecord
      //            } else {
      //                $traceRecord.Status = 'Needs to be disabled'
      //            }
      //        } else {
      //            $traceRecord.ProcessingTrace += " > File has to be ( and already is ) disabled. No further action required"
      //            $traceRecord.Status = 'OK'
      //        }
      //    }
      //    "n/a" {
      //        $traceRecord.ProcessingTrace += " > The current role does not demand the file to be disabled or enabled ( config file is not being used in this configuration ). No action is to be performed"
      //        $traceRecord.Status = 'OK'
      //    }
      //}

      //return $traceRecord
    }
  }
}
