import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

final http.Client _sharedClient = BrowserClient()..withCredentials = true;

http.Client createHttpClient() {
  return _sharedClient;
}
