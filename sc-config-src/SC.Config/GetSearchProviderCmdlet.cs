using SC.Config.Manifest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  [Cmdlet(VerbsCommon.Get, "SearchProvider")]
  [OutputType(typeof(SearchProvider))]
  public class GetSearchProviderCmdlet: Cmdlet
  {
    [Parameter(Mandatory =true)]
    public string SearchProviderDescription { get; set; }
    [Parameter(Mandatory =true)]
    public string[] LuceneProviderDescriptionSet { get; set; }
    [Parameter(Mandatory = true)]
    public string[] SOLRProviderDescriptionSet { get; set; }
    [Parameter(Mandatory = true)]
    [AllowEmptyString]
    public string[] AnyProviderDescriptionSet { get; set; }

    protected override void ProcessRecord()
    {
      if (LuceneProviderDescriptionSet.Contains(SearchProviderDescription))
      {
        WriteObject(SearchProvider.Lucene);
      }
      else if (SOLRProviderDescriptionSet.Contains(SearchProviderDescription))
      {
        WriteObject(SearchProvider.SOLR);
      }
      else if (AnyProviderDescriptionSet.Contains(SearchProviderDescription))
      {
        WriteObject(SearchProvider.Any);
      }
      else
      {
        throw new Exception($"SearchProvider can not be resolved by the following description: '{SearchProviderDescription}'");
      }
    }
  }
}
