enum StoragePermissionStatus {
  /// An error occurred while checking the permission status
  /// or requesting permission.
  unknown,

  /// The user has explicitly denied access to storage.
  denied,

  /// The user has explicitly granted access to storage.
  granted,
}
