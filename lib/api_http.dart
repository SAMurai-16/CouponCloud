import 'package:http/http.dart' as http;

import 'http_client_factory.dart' as http_client_factory;

abstract final class ApiHttp {
  static final http.Client client = http_client_factory.createHttpClient();
}
