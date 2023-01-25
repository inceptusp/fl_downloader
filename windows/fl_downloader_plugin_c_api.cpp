#include "include/fl_downloader/fl_downloader_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "fl_downloader_plugin.h"

void FlDownloaderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  fl_downloader::FlDownloaderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
