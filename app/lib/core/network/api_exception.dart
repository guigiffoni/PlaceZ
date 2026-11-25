class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final dynamic details;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$status [$code]: $message';
  }
}
