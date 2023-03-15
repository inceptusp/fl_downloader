#include "helpers.h"

#include <Windows.h>

namespace helpers {
	std::wstring Converters::Utf16FromUtf8(const std::string& utf8_string) {
		if (utf8_string.empty()) {
			return std::wstring();
		}
		int target_length =
			MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
				static_cast<int>(utf8_string.length()), nullptr, 0);
		if (target_length == 0) {
			return std::wstring();
		}
		std::wstring utf16_string;
		utf16_string.resize(target_length);
		int converted_length =
			MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
				static_cast<int>(utf8_string.length()),
				utf16_string.data(), target_length);
		if (converted_length == 0) {
			return std::wstring();
		}
		return utf16_string;
	}

	std::string Converters::Utf8FromUtf16(const std::wstring& utf16_string)
	{
		if (utf16_string.empty()) {
			return std::string();
		}
		int target_length =
			WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string.data(),
				static_cast<int>(utf16_string.length()), nullptr, 0, NULL, NULL);
		if (target_length == 0) {
			return std::string();
		}
		std::string utf8_string;
		utf8_string.resize(target_length);
		int converted_length =
			WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string.data(),
				static_cast<int>(utf8_string.length()),
				utf8_string.data(), target_length, NULL, NULL);
		if (converted_length == 0) {
			return std::string();
		}
		return utf8_string;
	}
}
