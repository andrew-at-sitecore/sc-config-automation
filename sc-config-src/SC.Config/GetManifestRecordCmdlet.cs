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
    public Manifest.Action Action { get; set; }
    [Parameter(Mandatory = true)]
    public SearchProvider SearchProviderUsed { get; set; }
    [Parameter(Mandatory = true)]
    public string FilePath { get; set; }
    [Parameter(Mandatory = true)]
    public string ConfigFileName { get; set; }

    protected override void ProcessRecord()
    {
      WriteObject(new ManifestRecord() {
        Action = this.Action,
        SearchProvider = this.SearchProviderUsed,
        FilePath = this.FilePath,
        ConfigFileName = this.ConfigFileName,
      });
    }
  }
}
