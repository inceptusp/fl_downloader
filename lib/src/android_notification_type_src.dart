/// Notification visibility types for Android platform.
enum AndroidNotificationType {
  /// This download doesn't show in the UI or in the notifications.
  ///
  /// This requires the permission `android.permission.DOWNLOAD_WITHOUT_NOTIFICATION`.
  hidden(2),

  /// This download is visible but only shows in the notifications while it's in progress.
  visible(0),

  /// This download is visible and shows in the notifications while in progress
  /// and after completion.
  ///
  /// This is the default behaviour.
  visibleCompleted(1);

  final int value;

  const AndroidNotificationType(this.value);
}
