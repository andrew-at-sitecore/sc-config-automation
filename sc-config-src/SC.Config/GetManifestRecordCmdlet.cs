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
  }
}
