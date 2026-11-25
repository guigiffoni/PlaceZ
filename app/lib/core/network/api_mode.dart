enum ApiMode {
  remote,
  mock;

  String get label {
    switch (this) {
      case ApiMode.remote:
        return 'Remoto';
      case ApiMode.mock:
        return 'Mock';
    }
  }

  String get storageValue => name;

  static ApiMode fromStorage(String? value) {
    return value == ApiMode.mock.storageValue ? ApiMode.mock : ApiMode.remote;
  }
}
