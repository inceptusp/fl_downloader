#ifndef FLUTTER_PLUGIN_FL_DOWNLOADER_PLUGIN_H_
#define FLUTTER_PLUGIN_FL_DOWNLOADER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <ppltasks.h>

#include <memory>

namespace fl_downloader {

	class FlDownloaderPlugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		FlDownloaderPlugin();
		virtual ~FlDownloaderPlugin();

		FlDownloaderPlugin(const FlDownloaderPlugin&) = delete;
		FlDownloaderPlugin& operator=(const FlDownloaderPlugin&) = delete;

	private:
		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		std::wstring Download(LPCWSTR url, LPCWSTR headers, LPCWSTR file_name);

		concurrency::task<void> TrackProgress(LPCWSTR jobId, LPSTREAM p_stream);

		void OpenFile(LPCWSTR file_path);

		int Cancel(std::vector<std::wstring> download_ids);
	};

}  // namespace fl_downloader

#endif  // FLUTTER_PLUGIN_FL_DOWNLOADER_PLUGIN_H_
