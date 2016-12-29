using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  [Cmdlet(VerbsCommon.Get, "ManifestAction")]
  [OutputType(typeof(Manifest.Action))]
  public class GetManifestActionCmdlet: Cmdlet
  {
    [Parameter(Mandatory =true)]
    public string ManifestActionDescription { get; set; }
    [Parameter(Mandatory = true)]
    public string[] EnableActionDescriptions { get; set; }
    [Parameter(Mandatory = true)]
    public string[] DisableActionDescriptions { get; set; }

    protected override void ProcessRecord()
    {
      if (EnableActionDescriptions.Contains(ManifestActionDescription))
      {
        WriteObject(Manifest.Action.Enable);
      } else if (DisableActionDescriptions.Contains(ManifestActionDescription))
      {
        WriteObject(Manifest.Action.Disable);
      } else
      {
        throw new Exception($"Failed to resolve manifest action by the action description : '{ManifestActionDescription}'");
      }
    }
  }
}
