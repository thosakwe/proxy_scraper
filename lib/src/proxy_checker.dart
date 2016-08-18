import "dart:async";
import "dart:io";
import "proxy_client.dart";
import "proxy_def.dart";

/// Selects only working proxies from a Stream<[ProxyDef]>.
///
/// You can also specify a list of `urlsToCheck` that will all be
/// visited through the proxy. If any is inaccessible, the proxy
/// will not be added to the final Stream.
class ProxyChecker implements StreamTransformer<ProxyDef, ProxyDef> {
  /// URL's to be visited through each proxy.
  List<String> urlsToCheck;

  /// To-be deleted
  Map pokemon;

  /// The maximum amount of time to be spent connecting to any proxy.
  int timeout;

  /// The total number of proxies originally sent through this transformer.
  int totalProxies = 0;

  ProxyChecker(this.urlsToCheck, int timeout, this.pokemon) {
    this.timeout = timeout ?? 5000;
  }

  @override
  Stream<ProxyDef> bind(Stream<ProxyDef> stream) {
    var _stream = new StreamController<ProxyDef>();

    stream.toList().then((proxies) async {
      int i = -1;
      totalProxies = proxies.length;

      await Future.forEach(proxies, (ProxyDef proxy) async {
        if (i == totalProxies - 1)
          stdout.write("100% complete (proxy $totalProxies/$totalProxies)...");
        else stdout.write("\r${(++i * 100.0 / totalProxies).toStringAsFixed(2)}% complete (proxy ${i + 1}/$totalProxies)...");
        bool success = true;

        try {
          ProxyClient _client = new ProxyClient(proxy, timeout);

          // Check each URL
          for (String url in urlsToCheck) {
            var response = await _client.get(url);
            //print("Body: ${response.body}");
          }

          // Pokemon
          if (pokemon != null) {
            //var pkmn = new PokemonClient(_client, pokemon);
          }

          _client.close();
        } catch (_) {
          success = false;
        }

        if (success) {
          _stream.add(proxy);
        }
      });

      stdout.writeln("\r\nFinished checking $totalProxies proxy(ies).");
      _stream.close();
    });

    return _stream.stream;
  }
}
