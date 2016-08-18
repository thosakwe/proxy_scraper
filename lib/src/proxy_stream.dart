import "dart:async";
import "proxy_def.dart";

/// Scrapes all proxies from an input text stream.
class ProxyStream implements StreamTransformer<List<int>, ProxyDef> {
  @override
  Stream<ProxyDef> bind(Stream<List<int>> stream) async* {
    await for (List<int> packet in stream) {
      var str = new String.fromCharCodes(packet);
      for (Match match in rgxIp.allMatches(str)) {
        yield new ProxyDef(match.group(1), int.parse(match.group(3)));
      }
    }
  }
}