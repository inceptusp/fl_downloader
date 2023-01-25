# fl_downloader
[![Pub Version](https://img.shields.io/pub/v/fl_downloader)](https://pub.dev/packages/fl_downloader)

A plugin to download files using the native capabilities.

On Android it uses the DownloadManager system service to download files to user's **Download** folder and, on iOS, it uses the URLSession to download files to the **App Documents** folder.

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

**NOTE**: This plugins expects that `compileSdkVersion` is the latest Android SDK, eg.:
```groovy
android {
    compileSdkVersion 33

    [...]
}
```
