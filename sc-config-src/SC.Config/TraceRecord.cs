using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config
{
  public class TraceRecord
  {
    public string ManifestRecord { get; set; }
    public string ManifestRelativePath { get; set; }
    public string ManifestSearchProvider { get; set; }
    public string RealConfigFilePath { get; set; }
    public List<string> ProcessingTrace { get; set; }
    public Status Status { get; set; }
  }
}
