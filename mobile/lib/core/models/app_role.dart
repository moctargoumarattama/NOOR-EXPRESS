enum AppRole {
  client,
  driver,
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.client:
        return 'Client';
      case AppRole.driver:
        return 'Driver';
    }
  }

  String get storageValue => name;

  static AppRole? fromStorageValue(String? value) {
    for (final role in AppRole.values) {
      if (role.name == value) {
        return role;
      }
    }
    return null;
  }
}
