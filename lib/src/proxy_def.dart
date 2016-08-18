/// Match IP addresses.
final RegExp rgxIp = new RegExp(r"([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(:|;)([0-9]+)");

/// Defines a proxy endpoint.
class ProxyDef {
  String ip;
  int port;

  ProxyDef(this.ip, this.port);
  ProxyDef.blank();

  @override String toString() => "$ip:$port";
}