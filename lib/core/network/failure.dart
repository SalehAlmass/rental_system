class ApiFailure implements Exception {
  ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => "ApiFailure(statusCode: $statusCode, message: $message)";
}
