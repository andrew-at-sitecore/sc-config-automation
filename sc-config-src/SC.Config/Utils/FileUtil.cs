﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Text.RegularExpressions;

namespace SC.Config.Utils
{
  public class FileUtil
  {
    public static string TryGetMatchingConfigFile(string webrootFullPath, string manifestRelativeLocationPath, string manifestConfigFileName, string[] configDisabledExtensions, string[] configEnabledExtensions)
    {
      var manifestFilePath = Path.Combine(manifestRelativeLocationPath, manifestConfigFileName);
      var configFileBaseName = GetExtentionlessConfigFileName(manifestConfigFileName, configDisabledExtensions, configEnabledExtensions);

      //A bit of trickery to
      //  - remove '\website' or 'website' entry from the manifest ( since the script operates in the context of webroot folder )
      var adjustedConfigFileRelativePath = Regex.Replace(manifestRelativeLocationPath, "^\\?website", "");
      //  - add '.*' to config file base name ( to get file system search pattern )
      var configFileBaseSearchPath = $"{configFileBaseName}.*";
      //As a result we end up with '\relative\path\file.base.name.*' ( so that later on we can get all files from file system, get their base names and fetch the one that corresponds to the manifest entry )

      var configFileLocationPath = Path.Combine(webrootFullPath, adjustedConfigFileRelativePath);

      //Check that target location exists
      if (!Directory.Exists(configFileLocationPath)) {
        throw new Exception($"Target location directory '{configFileLocationPath}' does not exist ( processing '{manifestFilePath}' entry from the configuration manifest )");
      }

      //Now we try to match the config file from the manifest to the actual config file by comparing their base names
      string matchedConfigFile = null;
      var targetConfigFileCandidates = Directory.GetFiles(configFileLocationPath, configFileBaseSearchPath);
      foreach ( var candidateConfigFile in targetConfigFileCandidates) {
        var candidateFileName = Path.GetFileName(candidateConfigFile);
        var candidateBaseFileName = GetExtentionlessConfigFileName(candidateFileName, configDisabledExtensions, configEnabledExtensions);

        if (candidateBaseFileName.Equals(configFileBaseName, StringComparison.CurrentCultureIgnoreCase)) {
          //The match had been found
          matchedConfigFile = candidateConfigFile;
          break;
        }
      }

      if (matchedConfigFile  == null) {
        throw new Exception($"Failed to find match for '{manifestFilePath}' ( attempt: '{Path.Combine(configFileLocationPath, configFileBaseSearchPath)}' )");
      }

      return matchedConfigFile;
    }

    public static string GetExtentionlessConfigFileName(string configFileName, string[] configDisabledExtensions, string[] configEnabledExtensions)
    {
      var fileNameElements = configFileName.Trim().Split('.');

      //process the collection from the tail
      var cutoffElementIndex = 0;
      for ( var i=-1; i > (fileNameElements.Length * -1); i-- ) {
        //each iteration tries to match element as an extension
        var extensionMatched = false;
        var currentIterationFileNameSegment = $".{fileNameElements[i].ToLower()}";
        if ( configDisabledExtensions.Contains(currentIterationFileNameSegment)) { extensionMatched = true; }
        if ( configEnabledExtensions.Contains(currentIterationFileNameSegment)) { extensionMatched = true; }

        if ( ! extensionMatched ) {
          //if no extension can be matched from the "tail" - what's left is to be considered the config file base name
          cutoffElementIndex = fileNameElements.Length + i; //$i is negative since the collection had been processed from the "tail"
          break;
        }
      }

      var extentionlessFileNameSegments = new ArraySegment<string>(fileNameElements, 0, cutoffElementIndex);
      return String.Join(".", extentionlessFileNameSegments.ToArray());
    }
  }
}