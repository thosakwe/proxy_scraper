import "dart:async";
import "dart:io";
import "package:http/http.dart" as http;
import "package:http/src/streamed_response.dart";
import "package:string_scanner/string_scanner.dart";
import "proxy_def.dart";

/// An [http.BaseClient] class that passes requests through a proxy.
class ProxyClient extends http.BaseClient {
  ProxyDef _proxy;
  int _timeout = 5000;
  Socket _socket;
  int _newLine = "\n".codeUnitAt(0);

  var _rgxHeader = new RegExp(r"([^:]+):\s*([^\n])");
  var _rgxNum = new RegExp(r"[0-9]+");
  var _rgxReason = new RegExp(r"[^\n]+");
  var _rgxVersion = new RegExp(r"HTTP/[0-9]\.[0-9]");
  bool _timedOut = false;

  ProxyClient(this._proxy, this._timeout) {
    this._timeout = _timeout ?? 5000;
  }

  _connect() {
    var completer = new Completer();

    Timer timer = new Timer(new Duration(milliseconds: _timeout), () {
      _timedOut = true;

      if (!completer.isCompleted)
        completer.completeError(_timeoutException());
    });

    Socket.connect(_proxy.ip, _proxy.port).then((socket) {
      this._socket = socket;
      timer.cancel();

      if (!completer.isCompleted) completer.complete();
    }).catchError((err, st) {
      if (!completer.isCompleted) completer.completeError(err, st);
    });

    return completer.future;
  }

  Exception _timeoutException() {
    return new Exception(
        "Connection to ${_proxy.ip}:${_proxy.port} timed out.");
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_timedOut) throw _timeoutException();

    if (_socket == null) {
      try {
        await _connect();
      } catch (_) {
        throw _timeoutException();
      }

      if (_timedOut)
        throw _timeoutException();
    }

    if (request.url.scheme == "https") {
      _socket.writeln("CONNECT ${request.url.host} HTTP/1.1");
      _socket.writeln("Proxy-Connection: Keep-Alive");
      await _socket.flush();
    }

    var stream = request.finalize();
    await stream.pipe(_socket);
    await _socket
      ..writeln()
      ..flush();

    var out = _socket.asBroadcastStream();
    var scanner = new StringScanner(await out.join());

    // Eat version
    scanner.expect(_rgxVersion, name: "HTTP version");
    scanner.readChar();

    // Get status code
    scanner.expect(_rgxNum, name: "HTTP status code");
    int statusCode = int.parse(scanner.lastMatch.group(0));

    scanner.readChar();
    String reasonPhrase = "";

    if (scanner.scan(_rgxReason)) {
      scanner.expect(_rgxReason);
      reasonPhrase = scanner.lastMatch.group(0);
    }

    // Skip to newline
    while (scanner.readChar() != _newLine) {
      //
    }

    // Parse headers :)
    Map<String, String> headers = {HttpHeaders.CONTENT_LENGTH: -1};

    while (true) {
      // Collect lines
      String line = "";
      while (scanner.peekChar() != _newLine) line += scanner.readChar();
      scanner.readChar();

      if (line.isEmpty) break;

      if (_rgxHeader.hasMatch(line)) {
        var match = _rgxHeader.firstMatch(line);
        headers[match.group(1).toLowercase()] = match.group(2);
      }
    }

    //String body = scanner.rest;

    return new StreamedResponse(out, statusCode,
        request: request,
        headers: headers,
        contentLength: headers[HttpHeaders.CONTENT_LENGTH] == -1
            ? null
            : int.parse(HttpHeaders.CONTENT_LENGTH),
        isRedirect: headers[HttpHeaders.LOCATION] != null,
        persistentConnection: headers[HttpHeaders.CONNECTION] != "close",
        reasonPhrase: reasonPhrase);
  }

  @override
  void close() {
    if (_socket != null) _socket.close();
    super.close();
  }
}
