# fl_downloader
[![Pub Version](https://img.shields.io/pub/v/fl_downloader)](https://pub.dev/packages/fl_downloader)

A plugin to download files using the native capabilities.

On Android it uses the [DownloadManager](https://developer.android.com/reference/android/app/DownloadManager) system service and, on Windows, it uses [BITS](https://learn.microsoft.com/en-us/windows/win32/bits/background-intelligent-transfer-service-portal) to download files to user's **Downloads** folder and, on iOS, it uses the [URLSession](https://developer.apple.com/documentation/foundation/urlsession) to download files to the **App Documents** folder.

## iOS Configuration

If you don`t want to show downloaded files to the user on the Files app, there is no need for special configuration.

If you want to show downloaded files to the user on the Files app, add the following lines to your **info.plist** file:

``` xml
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UIFileSharingEnabled</key>
<true/>
```

## Android Configuration

There is no need for special configuration on Android 10+.

If your app supports Android 9 (API 28) or bellow it is mandatory to call `requestPermission()` before `download()` and check the permission status.<br><br>

**NOTE**: This plugins expects that `compileSdk` is the latest Android SDK, eg.:
```groovy
android {
    compileSdk 34

    [...]
}
```

## Windows Configuration

There is no need for special configuration on Windows.

**NOTE**: The following pages are important to know the limitations and to test the use of BITS:<br><br>
[About BITS](https://learn.microsoft.com/en-us/windows/win32/bits/about-bits)<br>
[HTTP Requirements for BITS Downloads](https://learn.microsoft.com/en-us/windows/win32/bits/http-requirements-for-bits-downloads)<br>
[BITSAdmin tool](https://learn.microsoft.com/en-us/windows/win32/bits/bitsadmin-tool)
