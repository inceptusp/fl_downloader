#include "fl_downloader_plugin.h"

#include <windows.h>
#include <winrt/windows.foundation.h>
#include <winrt/windows.networking.backgroundtransfer.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace fl_downloader {

// static
void FlDownloaderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.inceptusp.fl_downloader",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlDownloaderPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlDownloaderPlugin::FlDownloaderPlugin() {}

FlDownloaderPlugin::~FlDownloaderPlugin() {}

void FlDownloaderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("download") == 0) {
      download();
    result->Success(flutter::EncodableValue(1));
  } else {
    result->NotImplemented();
  }
}

void FlDownloaderPlugin::download() {
    std::cout << "teste" << std::endl;
}

}  // namespace fl_downloader
