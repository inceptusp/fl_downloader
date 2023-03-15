#ifndef FL_DOWNLOADER_PLUGIN_STRING_HELPERS_H_
#define FL_DOWNLOADER_PLUGIN_STRING_HELPERS_H_

#include <flutter/encodable_value.h>

#include <string>
#include <map>

namespace helpers {
	class Converters {
	public:
		static std::wstring Utf16FromUtf8(const std::string& utf8_string);

		static std::string Utf8FromUtf16(const std::wstring& utf16_string);

		template<typename T1, typename T2>
		static std::map<T1, T2> EncodableMapToMap(flutter::EncodableMap);
	};

	template<typename T1, typename T2>
	inline std::map<T1, T2> Converters::EncodableMapToMap(flutter::EncodableMap map)
	{
		std::map<T1, T2> return_map;
		for (const auto& [key, value] : map) {
			return_map.insert(std::pair<T1, T2>(std::get<T1>(key), std::get<T2>(value)));
		}
		return return_map;
	}
}

#endif