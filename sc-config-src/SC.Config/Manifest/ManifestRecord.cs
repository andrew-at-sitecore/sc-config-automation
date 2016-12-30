using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SC.Config.Manifest
{
  public class ManifestRecord
  {
    public string FilePath { get; set; }
    public string ConfigFileName { get; set; }
    public SearchProvider SearchProvider { get; set; }
    public Manifest.Action Action { get; set; }

    public string RelativeFilePath
    {
      get
      {
        return Path.Combine(this.FilePath, this.ConfigFileName);
      }
    }
  }
}
