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
    public Action ContentDeliveryAction { get; set; }
    public Action ContentManagementAction { get; set; }
    public Action ProcessingAction { get; set; }
    public Action CMAndProcessingAction { get; set; }
    public Action ReportingAction { get; set; }
    public string ProductName { get; set; }
    public string FilePath { get; set; }
    public string ConfigFileName { get; set; }
    public string ConfigType { get; set; }
    public SearchProvider SearchProvider { get; set; }
    public Manifest.Action CurrentAction { get; set; }

    public string RelativeFilePath
    {
      get
      {
        return Path.Combine(this.FilePath, this.ConfigFileName);
      }
    }
  }
}
