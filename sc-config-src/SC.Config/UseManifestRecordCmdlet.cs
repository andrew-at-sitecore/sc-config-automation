using SC.Config.Manifest;
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
    [Parameter(ParameterSetName ="Apply")]
    public bool ApplyManifest { get; set; }
    [Parameter(ParameterSetName = "Verify")]
    public bool Verify { get; set; }
    [Parameter(Mandatory =true)]
    public string Role { get; set; }
    [Parameter(Mandatory = true)]
    public string SearchProvider { get; set; }
    [Parameter(Mandatory = true)]
    public string Webroot { get; set; }
    [Parameter(Mandatory = true)]
    public ManifestRecord ManifestRecord { get; set; }
  }
}
