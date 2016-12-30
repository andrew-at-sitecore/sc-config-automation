using SC.Config.Manifest;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  [Cmdlet(VerbsCommon.Get, "ManifestRecord")]
  [OutputType(typeof(ManifestRecord))]
  public class GetManifestRecordCmdlet : Cmdlet
  {
    [Parameter(Mandatory = true)]
    public Manifest.Action CurrentAction { get; set; }
    [Parameter(Mandatory = true)]
    public SearchProvider SearchProviderUsed { get; set; }
    [Parameter(Mandatory =true)]
    public Manifest.Action ContentDeliveryAction { get; set; }
    [Parameter(Mandatory = true)]
    public Manifest.Action ContentManagementAction { get; set; }
    [Parameter(Mandatory = true)]
    public Manifest.Action ProcessingAction { get; set; }
    [Parameter(Mandatory = true)]
    public Manifest.Action CMAndProcessingAction { get; set; }
    [Parameter(Mandatory = true)]
    public Manifest.Action ReportingAction { get; set; }
    [Parameter(Mandatory = true)]
    public string ProductName { get; set; }
    [Parameter(Mandatory = true)]
    public string FilePath { get; set; }
    [Parameter(Mandatory = true)]
    public string ConfigFileName { get; set; }
    [Parameter(Mandatory = true)]
    public string ConfigType { get; set; }

    protected override void ProcessRecord()
    {
      WriteObject(new ManifestRecord() {
        CurrentAction = this.CurrentAction,
        SearchProvider = this.SearchProviderUsed,
        ContentDeliveryAction = this.ContentDeliveryAction,
        ContentManagementAction = this.ContentManagementAction,
        ProcessingAction = this.ProcessingAction,
        CMAndProcessingAction = this.CMAndProcessingAction,
        ReportingAction = this.ReportingAction,
        ProductName = this.ProductName,
        FilePath = this.FilePath,
        ConfigFileName = this.ConfigFileName,
        ConfigType = this.ConfigType
      });
    }
  }
}
