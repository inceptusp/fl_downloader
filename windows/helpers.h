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

		static std::vector<std::wstring> Utf8ListFromUtf16List(const std::vector<std::string>& utf8_list);

		template<typename T1, typename T2>
		static std::map<T1, T2> EncodableMapToMap(flutter::EncodableMap);

		template<typename T1>
		static std::vector<T1> EncodableListToList(flutter::EncodableList);
	};

	template<typename T1, typename T2>
	inline std::map<T1, T2> Converters::EncodableMapToMap(flutter::EncodableMap map) {
		std::map<T1, T2> return_map;
		for (const auto& [key, value] : map) {
			return_map.insert(std::pair<T1, T2>(std::get<T1>(key), std::get<T2>(value)));
		}
		return return_map;
	}

	template<typename T1>
	inline std::vector<T1> Converters::EncodableListToList(flutter::EncodableList list) {
		std::vector<T1> return_list;
		for (const auto& value : list) {
			return_list.push_back(std::get<T1>(value));
		}
		return return_list;
	}
}

#endif