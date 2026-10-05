class ApiEnvelope {
  ApiEnvelope._();

  static dynamic data(dynamic response) {
    if (response is Map) {
      final success = response['isSuccess'] ?? response['IsSuccess'];
      if (success == false) {
        throw _message(response) ?? 'حدث خطأ، حاول مرة تانية.';
      }
      if (response.containsKey('data')) return response['data'];
      if (response.containsKey('Data')) return response['Data'];
    }
    return response;
  }

  static String? message(dynamic response) {
    if (response is Map) return _message(response);
    return null;
  }

  static String? _message(Map<dynamic, dynamic> response) {
    final message = response['message'] ?? response['Message'];
    final text = message?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
