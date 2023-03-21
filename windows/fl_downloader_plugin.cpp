#pragma comment(lib, "pathcch.lib")

#include "fl_downloader_plugin.h"
#include "helpers.h"

#include <ppltasks.h>
#include <pathcch.h>
#include <shlobj.h>
#include <windows.h>
#include <bits.h>
#include <bits5_0.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <future>

using namespace concurrency;

namespace fl_downloader {
	std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>,
		std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>> channel;

	IBackgroundCopyManager* g_pbcm = NULL;

	// static
	void FlDownloaderPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		channel =
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

			IStream* p_stream = NULL;
			HRESULT hr = CoMarshalInterThreadInterfaceInStream(__uuidof(IBackgroundCopyManager),
				g_pbcm, &p_stream);
			if (SUCCEEDED(hr))
			{
				TrackProgress(job_id.c_str(), p_stream);
			}

			auto utf8_job_id = helpers::Converters::Utf8FromUtf16(job_id);
			result->Success(flutter::EncodableValue(utf8_job_id));
		}
		else if (method_call.method_name().compare("attachDownloadTracker") == 0) {
			const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
			std::string job_id;

			if (args) {
				auto job_id_it = args->find(flutter::EncodableValue("url"));
				if (job_id_it != args->end()) {
					job_id = std::get<std::string>(job_id_it->second);
				}
			}

			auto utf16_job_id = helpers::Converters::Utf16FromUtf8(job_id);

			IStream* p_stream = NULL;
			HRESULT hr = CoMarshalInterThreadInterfaceInStream(__uuidof(IBackgroundCopyManager),
				g_pbcm, &p_stream);
			if (SUCCEEDED(hr))
			{
				TrackProgress(utf16_job_id.c_str(), p_stream);
			}

			result->Success();
		}
		else if (method_call.method_name().compare("openFile") == 0) {
			const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
			std::string file_path;

			if (args) {
				auto file_path_it = args->find(flutter::EncodableValue("filePath"));
				if (file_path_it != args->end()) {
					file_path = std::get<std::string>(file_path_it->second);
				}
			}

			auto utf16_file_path = helpers::Converters::Utf16FromUtf8(file_path);

			OpenFile(utf16_file_path.data());

			result->Success();
		}
		else if (method_call.method_name().compare("cancel") == 0) {
			const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
			std::vector<std::string> download_guids;

			if (args) {
				auto download_ids_it = args->find(flutter::EncodableValue("downloadIds"));
				if (download_ids_it != args->end()) {
					download_guids = helpers::Converters::EncodableListToList<std::string>(std::get<flutter::EncodableList>(download_ids_it->second));
				}
			}

			auto utf16_download_guids = helpers::Converters::Utf8ListFromUtf16List(download_guids);

			auto cancelled_downloads = Cancel(utf16_download_guids);

			result->Success(flutter::EncodableValue(cancelled_downloads));
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
			PWSTR p_full_file_path = (PWSTR)CoTaskMemAlloc(MAX_PATH);
			lstrcpy(p_full_file_path, p_download_folder_path);
			hr = PathCchAppend(p_full_file_path, MAX_PATH, file_name);
			if (SUCCEEDED(hr)) {
				hr = g_pbcm->CreateJob(file_name, BG_JOB_TYPE_DOWNLOAD, &job_id, &p_job);
				if (SUCCEEDED(hr)) {
					hr = p_job->AddFile(url, p_full_file_path);
					if (SUCCEEDED(hr)) {
						if (headers != NULL && headers[0] != 0) {
							IBackgroundCopyJobHttpOptions* p_http_options = NULL;

							hr = p_job->QueryInterface(__uuidof(IBackgroundCopyJobHttpOptions), (void**)&p_http_options);
							if (SUCCEEDED(hr)) {
								p_http_options->SetCustomHeaders(headers);
							}

							if (p_http_options) {
								p_http_options->Release();
								p_http_options = NULL;
							}
						}
						p_job->Resume();
					}
				}

				if (p_job) {
					p_job->Release();
					p_job = NULL;
				}
			}
			if (p_full_file_path) CoTaskMemFree(p_full_file_path);
		}

		if(p_download_folder_path) CoTaskMemFree(p_download_folder_path);

		LPWSTR guid_string;
		StringFromCLSID(job_id, &guid_string);
		std::wstring rt = guid_string;
		if (guid_string) CoTaskMemFree(guid_string);
		return rt;
	}

	concurrency::task<void> FlDownloaderPlugin::TrackProgress(LPCWSTR job_id, LPSTREAM p_stream) {
		return create_task([this, job_id, p_stream] {
			HRESULT hr;
			IBackgroundCopyManager* l_pbcm = NULL;
			IBackgroundCopyJob* p_job = NULL;
			GUID guid;

			CLSIDFromString(job_id, &guid);
			auto utf8_guid_string = helpers::Converters::Utf8FromUtf16(job_id);

			hr = CoGetInterfaceAndReleaseStream(p_stream,
				__uuidof(IBackgroundCopyManager), (void**)&l_pbcm);
			p_stream->Release();

			hr = l_pbcm->GetJob(guid, &p_job);

			if (SUCCEEDED(hr)) {
				BG_JOB_STATE state;
				HANDLE h_timer = NULL;
				LARGE_INTEGER due_time;
				BG_JOB_PROGRESS progress;

				due_time.QuadPart = -(10000000 / 10);  //Poll every 1/10 of a second
				h_timer = CreateWaitableTimer(NULL, FALSE, L"ProgressTrackerTimer");
				SetWaitableTimer(h_timer, &due_time, 1000, NULL, NULL, 0);

				do
				{
					WaitForSingleObject(h_timer, INFINITE);

					hr = p_job->GetState(&state);
					if (FAILED(hr))
					{
						//Handle error
					}

					if (state == BG_JOB_STATE_TRANSFERRED)
					{
						IEnumBackgroundCopyFiles* p_files = NULL;
						IBackgroundCopyFile* p_file = NULL;
						LPWSTR file_name;

						p_job->EnumFiles(&p_files);
						p_files->Next(1, &p_file, NULL);
						p_file->GetLocalName(&file_name);

						auto utf8_file_name = helpers::Converters::Utf8FromUtf16(file_name);

						int pgr = 100;
						flutter::EncodableMap progress_map = {
							{flutter::EncodableValue("downloadId"), flutter::EncodableValue(utf8_guid_string)},
							{flutter::EncodableValue("progress"), flutter::EncodableValue(pgr)},
							{flutter::EncodableValue("status"), flutter::EncodableValue(0)},
							{flutter::EncodableValue("filePath"), flutter::EncodableValue(utf8_file_name)},
						};

						if (file_name) CoTaskMemFree(file_name);
						if (p_file) {
							p_file->Release();
							p_file = NULL;
						}
						if (p_files) {
							p_files->Release();
							p_files = NULL;
						}

						p_job->Complete();

						channel->InvokeMethod("notifyProgress",
							std::make_unique<flutter::EncodableValue>(progress_map));
						break;
					}
					else if (state == BG_JOB_STATE_ERROR || state == BG_JOB_STATE_TRANSIENT_ERROR)
					{
						IBackgroundCopyError* p_error = NULL;

						p_job->GetError(&p_error);
						//p_error->

						flutter::EncodableMap progress_map = {
							{flutter::EncodableValue("downloadId"), flutter::EncodableValue(utf8_guid_string)},
							{flutter::EncodableValue("progress"), flutter::EncodableValue(0)},
							{flutter::EncodableValue("status"), flutter::EncodableValue(4)},
							{flutter::EncodableValue("reason"), flutter::EncodableValue(4)},
						};
						channel->InvokeMethod("notifyProgress",
							std::make_unique<flutter::EncodableValue>(progress_map));

						if (p_error) {
							p_error->Release();
							p_error = NULL;
						}

						p_job->Cancel();
						break;
					}
					else if (state == BG_JOB_STATE_SUSPENDED)
					{

					}
					else if (state == BG_JOB_STATE_TRANSFERRING)
					{
						p_job->GetProgress(&progress);
						int64_t pgr = (progress.BytesTransferred * 100) / progress.BytesTotal;
						flutter::EncodableMap progress_map = {
							{flutter::EncodableValue("downloadId"), flutter::EncodableValue(utf8_guid_string)},
							{flutter::EncodableValue("progress"), flutter::EncodableValue(pgr)},
							{flutter::EncodableValue("status"), flutter::EncodableValue(1)},
						};
						channel->InvokeMethod("notifyProgress",
							std::make_unique<flutter::EncodableValue>(progress_map));
					}
					else if (state == BG_JOB_STATE_CONNECTING)
					{
						flutter::EncodableMap progress_map = {
							{flutter::EncodableValue("downloadId"), flutter::EncodableValue(utf8_guid_string)},
							{flutter::EncodableValue("progress"), flutter::EncodableValue(0)},
							{flutter::EncodableValue("status"), flutter::EncodableValue(2)},
						};
						channel->InvokeMethod("notifyProgress",
							std::make_unique<flutter::EncodableValue>(progress_map));
					}
				} while (state == BG_JOB_STATE_CONNECTING ||
						 state == BG_JOB_STATE_TRANSFERRING ||
						 state == BG_JOB_STATE_SUSPENDED ||
						 state == BG_JOB_STATE_ERROR ||
						 state == BG_JOB_STATE_TRANSIENT_ERROR ||
						 state == BG_JOB_STATE_TRANSFERRED);

				CancelWaitableTimer(h_timer);
				CloseHandle(h_timer);
			}

			if (p_job) {
				p_job->Release();
				p_job = NULL;
			}
			return; 
		});
	}

	void FlDownloaderPlugin::OpenFile(LPCWSTR file_path) {
		ShellExecute(NULL, NULL, file_path, NULL, NULL, SW_SHOWNORMAL);
	}

	int FlDownloaderPlugin::Cancel(std::vector<std::wstring> download_ids) {
		HRESULT hr;
		IBackgroundCopyJob* p_job = NULL;
		int successful_canceled_downloads = 0;

		for (const auto& guid_string : download_ids) {
			GUID guid;

			hr = CLSIDFromString(guid_string.c_str(), &guid);
			if (SUCCEEDED(hr)) {
				hr = g_pbcm->GetJobW(guid, &p_job);
				if (SUCCEEDED(hr)) {
					hr = p_job->Cancel();
					if (SUCCEEDED(hr)) {
						successful_canceled_downloads++;
					}
				}
			}

			if (p_job) {
				p_job->Release();
				p_job = NULL;
			}
		}

		return successful_canceled_downloads;
	}

}  // namespace fl_downloader
