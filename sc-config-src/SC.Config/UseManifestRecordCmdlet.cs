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
    [Parameter()]
    public SwitchParameter Apply { get; set; }
    [Parameter(Mandatory = true)]
    public SearchProvider TargetSearchProvider { get; set; }
    [Parameter(Mandatory = true)]
    public string Webroot { get; set; }
    [Parameter(Mandatory = true)]
    public ManifestRecord ManifestRecord { get; set; }
    [Parameter(Mandatory = true)]
    public string[] SCDisableExtensionsList { get; set; }
    [Parameter(Mandatory = true)]
    public string[] SCEnableExtensionsList { get; set; }

    protected void TryProcessRecord(TraceRecord traceRecord)
    {
      var fileUtil = new FileUtil(this.SCDisableExtensionsList, this.SCEnableExtensionsList);

      var realConfigFileFullPath = fileUtil.TryGetMatchingConfigFile(this.Webroot, this.ManifestRecord.FilePath, this.ManifestRecord.ConfigFileName);
      traceRecord.RealConfigFilePath = realConfigFileFullPath;

      var realConfigFileName = Path.GetFileName(realConfigFileFullPath);

      //Case insensitive extension check. If the extension is not in "enabled" it is in "disabled"
      //    In fact - the only enabled extension is .config ( but the implementation was done for more generic case )
      var realConfigFileIsEnabled = this.SCEnableExtensionsList.Select(x => x.ToLower()).Contains(Path.GetExtension(realConfigFileName).ToLower());

      if ((this.TargetSearchProvider != SearchProvider.Any) &&
            (this.ManifestRecord.SearchProvider != this.TargetSearchProvider))
      {
        if (!realConfigFileIsEnabled)
        {
          //Search provider does not match the target search provider ( but the config file is already disabled )
          traceRecord.ProcessingTrace.Add($"File has to be ( and already is ) disabled due to mismatching search providers ( Target:'{this.TargetSearchProvider}'; Manifest:'{this.ManifestRecord.SearchProvider}'). No further action required");
          traceRecord.StatusDetails = "File has to be ( and already is ) disabled due to mismatching search providers";
          traceRecord.Status = Status.OK;
        }
        else
        {
          //Search provider does not match the target search provider ( and the config file is still enabled - needs to be disabled )
          traceRecord.ProcessingTrace.Add($"The manifest record is for '{this.ManifestRecord.SearchProvider}' search provider whereas target search provider for the operation is '{this.TargetSearchProvider}'. The configuration file needs to be disabled");
          if (this.Apply)
          {
            fileUtil.TryDisableConfigFile(realConfigFileFullPath);
            traceRecord.Status = Status.OK;
            traceRecord.StatusDetails = "Had been disabled";
          }
          else
          {
            traceRecord.Status = Status.ACTION;
            traceRecord.StatusDetails = "Needs to be disabled";
          }
        }
        WriteObject(traceRecord);
        return;
      }

      //Proceed if search provider is the same
      switch (this.ManifestRecord.Action)
      {
        case Manifest.Action.Enable:
          if (!realConfigFileIsEnabled) // IF file has to be ENABLED BUT is DISABLED
          {
            traceRecord.Status = Status.ACTION;
            traceRecord.ProcessingTrace.Add(" > The configuration file is disabled ( has to be enabled as per manifest )");
            if (this.Apply)
            {
              fileUtil.TryEnableConfigFile(realConfigFileFullPath);
              traceRecord.StatusDetails = "Configuration file had been enabled";
            }
            else
            {
              traceRecord.StatusDetails = "Needs to be enabled";
            }
          }
          else // IF file has to be ENABLED and already IS ENABLED
          {
            traceRecord.Status = Status.OK;
            traceRecord.StatusDetails = "File has to be ( and already is ) enabled. No further action required";
          }
          break;

        case Manifest.Action.Disable:
          if (realConfigFileIsEnabled) { // IF file has to be DISABLED BUT is ENABLED
            traceRecord.Status = Status.ACTION;
            traceRecord.ProcessingTrace.Add(" > The configuration file is enabled ( has to be disabled as per manifest )");
            if (this.Apply) {
              fileUtil.TryDisableConfigFile(realConfigFileFullPath);
              traceRecord.StatusDetails = "Configuration file had been disabled";
            } else {
              traceRecord.StatusDetails = "Needs to be disabled";
            }
          } else { // IF file has to be DISABLED and already IS DISABLED
            traceRecord.Status = Status.OK;
            traceRecord.StatusDetails = "File has to be ( and already is ) disabled. No further action required";
          }
          break;

        case Manifest.Action.NA:
          traceRecord.Status = Status.OK;
          traceRecord.StatusDetails = "The current role does not demand the file to be disabled or enabled ( config file is not being used in this configuration ). No action is to be performed";
          break;
      }
    }

    protected override void ProcessRecord()
    {
      var traceRecord = new TraceRecord()
      {
        ManifestRecord = this.ManifestRecord.ToString(),
        ManifestRelativePath = this.ManifestRecord.RelativeFilePath,
        ManifestSearchProvider = Enum.GetName(typeof(SearchProvider), this.ManifestRecord.SearchProvider),
        Status = Status.NA
      };

      try
      {
        TryProcessRecord(traceRecord);
        WriteObject(traceRecord);
      }
      catch (Exception ex)
      {
        traceRecord.Status = Status.FAIL;
        traceRecord.StatusDetails = ex.Message;
        traceRecord.ProcessingTrace.Add(ex.StackTrace);
        WriteObject(traceRecord);
      }

    }

  }
}
