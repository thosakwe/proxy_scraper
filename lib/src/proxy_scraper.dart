import "dart:async";
import "dart:io";
import "package:http/http.dart" as http;
import "proxy_def.dart";
import "proxy_stream.dart";

/// Scrapes proxies from either files on disk or the Web.
class ProxyScraper {
  final StreamController<ProxyDef> _stream = new StreamController<ProxyDef>();

  /// A stream of all scraped proxies.
  Stream<ProxyDef> get stream => _stream.stream;

  /// The URL's to fetch proxies from.
  List<String> urls;

  ProxyScraper(this.urls);

  /// Asynchronously grabs proxy URL's.
  Future fetch() async {
    var client = new http.Client();

    for (String url in urls) {
      var file = new File(url), proxyStream = new ProxyStream();
      if (await file.exists()) {
        await for (ProxyDef proxyDef in file.openRead().transform(proxyStream)) {
          _stream.add(proxyDef);
        }
      } else {
        var response = await client.get(url);
        var _ctrl = new StreamController<List<int>>();
        _ctrl
          ..add(response.bodyBytes)
          ..close();
        await _stream.addStream(_ctrl.stream.transform(proxyStream));
      }
    }

    _stream.close();
    client.close();
  }
}
