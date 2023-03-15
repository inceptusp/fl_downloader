#pragma comment(lib, "pathcch.lib")

#include "fl_downloader_plugin.h"
#include "helpers.h"

#include <ppltasks.h>
#include <pathcch.h>
#include <shlobj.h>
#include <windows.h>
#include <bits.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <future>

using namespace concurrency;

namespace fl_downloader {
	IBackgroundCopyManager* g_pbcm = NULL;

	// static
	void FlDownloaderPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		auto channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), "dev.inceptusp.fl_downloader",
				&flutter::StandardMethodCodec::GetInstance());

		auto plugin = std::make_unique<FlDownloaderPlugin>();

		channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
				plugin_pointer->HandleMethodCall(call, std::move(result));
			});

		registrar->AddPlugin(std::move(plugin));
	}

	FlDownloaderPlugin::FlDownloaderPlugin() {
		HRESULT hr;

		hr = CoCreateInstance(__uuidof(BackgroundCopyManager5_0), NULL,
			CLSCTX_LOCAL_SERVER, __uuidof(IBackgroundCopyManager),
			(void**)&g_pbcm);

		if (!SUCCEEDED(hr)) {
			std::wcout << "Failed to initialize BITS instance or BITS 5.0 not found in this system." << std::endl;
			std::wcout << "BITS 5.0 is available on Windows 8.1 and Windows 10 1607 or above (see https://learn.microsoft.com/en-us/windows/win32/bits/what-s-new)" << std::endl;
		}
	}

	FlDownloaderPlugin::~FlDownloaderPlugin() {
		if (g_pbcm) {
			g_pbcm->Release();
			g_pbcm = NULL;
		}
	}

	void FlDownloaderPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
		if (method_call.method_name().compare("download") == 0) {
			const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
			std::string url;
			std::map<std::string, std::string> headers;
			std::string file_name;

			if (args) {
				auto url_it = args->find(flutter::EncodableValue("url"));
				if (url_it != args->end()) {
					url = std::get<std::string>(url_it->second);
				}
				auto headers_it = args->find(flutter::EncodableValue("headers"));
				if (headers_it != args->end() && !headers_it->second.IsNull()) {
					headers = helpers::Converters::EncodableMapToMap<std::string, std::string>(std::get<flutter::EncodableMap>(headers_it->second));
				}
				auto file_name_it = args->find(flutter::EncodableValue("fileName"));
				if (file_name_it != args->end()) {
					file_name = std::get<std::string>(file_name_it->second);
				}
			}

			auto utf16_url = helpers::Converters::Utf16FromUtf8(url);
			auto utf16_file_name = helpers::Converters::Utf16FromUtf8(file_name);
			std::stringstream concat_headers;
			if (!headers.empty()) {
				for (const auto& [key, value] : headers) {
					concat_headers << key << ": " << value << "\r\n";
				}
			}
			auto utf16_headers_string = helpers::Converters::Utf16FromUtf8(concat_headers.str());

			auto job_id = Download(utf16_url.data(), utf16_headers_string.data(), utf16_file_name.data());
			//future<void> ret = async(launch::async, &FlDownloaderPlugin::TrackProgress, this, job_id);
			//TrackProgress(job_id);

			auto utf8_job_id = helpers::Converters::Utf8FromUtf16(job_id);
			result->Success(flutter::EncodableValue(utf8_job_id));
		}
		else if (method_call.method_name().compare("cancel") == 0) {

		}
		else if (method_call.method_name().compare("openFile") == 0) {

		}
		else if (method_call.method_name().compare("attachDownloadTracker") == 0) {

		}
		else {
			result->NotImplemented();
		}
	}

	std::wstring FlDownloaderPlugin::Download(LPCWSTR url, LPCWSTR headers, LPCWSTR file_name) {
		HRESULT hr;
		GUID job_id;
		IBackgroundCopyJob* p_job = NULL;

		PWSTR p_download_folder_path = NULL;

		hr = SHGetKnownFolderPath(FOLDERID_Downloads, 0, NULL, &p_download_folder_path);

		if (SUCCEEDED(hr)) {
			std::wstringstream concat_filename;
			concat_filename << "\\" << file_name;
			hr = PathCchAppend(p_download_folder_path, MAX_PATH, concat_filename.str().c_str());
			if (SUCCEEDED(hr)) {
				hr = g_pbcm->CreateJob(file_name, BG_JOB_TYPE_DOWNLOAD, &job_id, &p_job);
				if (SUCCEEDED(hr)) {
					hr = p_job->AddFile(url, p_download_folder_path);
					if (SUCCEEDED(hr)) {
						if (headers != NULL && headers[0] != 0) {
							std::wcout << L"teste" << std::endl;
							IBackgroundCopyJobHttpOptions* p_http_options;
							hr = p_job->QueryInterface(__uuidof(IBackgroundCopyJobHttpOptions), (void**)&p_http_options);
							if (SUCCEEDED(hr)) {
								p_http_options->SetCustomHeaders(headers);
							}
							if (p_http_options) {
								p_http_options->Release();
							}
						}
						p_job->Resume();
					}
				}
				if (p_job) {
					p_job->Release();
				}
			}
		}

		WCHAR guid_string[40];
		StringFromGUID2(job_id, guid_string, 40);
		return guid_string;
	}

	void FlDownloaderPlugin::TrackProgress(GUID job_id) {
		std::wcout << L"coroutine" << std::endl;
		HRESULT hr;
		IBackgroundCopyJob* p_job;

		hr = g_pbcm->GetJob(job_id, &p_job);

		if (SUCCEEDED(hr)) {
			BG_JOB_STATE state;
			HANDLE h_timer = NULL;
			LARGE_INTEGER due_time;
			IBackgroundCopyError* p_error = NULL;
			BG_JOB_PROGRESS progress;
			//WCHAR *JobStates[] = { L"Queued", L"Connecting", L"Transferring",
			//                       L"Suspended", L"Error", L"Transient Error",
			//                       L"Transferred", L"Acknowledged", L"Canceled"
			//                     };

			due_time.QuadPart = -10000000;  //Poll every 1 second
			h_timer = CreateWaitableTimer(NULL, FALSE, L"ProgressTrackerTimer");
			SetWaitableTimer(h_timer, &due_time, 1000, NULL, NULL, 0);

			std::wcout << L"sucesso" << std::endl;

			do
			{
				WaitForSingleObject(h_timer, INFINITE);

				std::wcout << L"indentro do loop" << std::endl;

				//Use JobStates[State] to set the window text in a user interface.
				hr = p_job->GetState(&state);

				std::wcout << SUCCEEDED(hr) << std::endl;
				
				if (FAILED(hr))
				{
					//Handle error
				}
				
				if (state == BG_JOB_STATE_TRANSFERRED) {
					std::wcout << L"complete" << std::endl;
					p_job->Complete();
				} else if (state == BG_JOB_STATE_ERROR || state == BG_JOB_STATE_TRANSIENT_ERROR) {
					p_job->GetError(&p_error);
				} else if (state == BG_JOB_STATE_TRANSFERRING) {
					p_job->GetProgress(&progress);
					std::wcout << L"progress" << std::endl;
				}
			} while (state != BG_JOB_STATE_TRANSFERRED && state != BG_JOB_STATE_ERROR && state == BG_JOB_STATE_TRANSIENT_ERROR);

			CancelWaitableTimer(h_timer);
			CloseHandle(h_timer);
		}
		else {
			std::wcout << L"faia" << std::endl;
		}

		CoTaskMemFree(p_job);

		std::wcout << L"end coroutine" << std::endl;
	}

}  // namespace fl_downloader
