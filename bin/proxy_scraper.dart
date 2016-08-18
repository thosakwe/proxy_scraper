library proxy_scraper.tool;

import "dart:io";
import "package:merge_map/merge_map.dart";
import "package:proxy_scraper/proxy_scraper.dart";
import "package:yaml/yaml.dart" as yaml;

main(List<String> args) async {
  print("Proxy Scraper v1.0.0-dev - Tobe O. All rights reserved.\n");

  var config = {"urls": [], "check": [], "timeout": 5000, "pokemon": null};
  Uri configFileUri = Directory.current.uri.resolve("proxy_scraper.yaml");

  var configFile = new File.fromUri(configFileUri);

  if (args.isNotEmpty)
    configFile = new File(args[0]);

  if (await configFile.exists()) {
    var loadedConfig = yaml.loadYaml(await configFile.readAsString());
    config = loadedConfig is Map ? mergeMap([config, loadedConfig]) : config;
  }

  print("Collecting URL's...");
  var scraper = new ProxyScraper(config["urls"] ?? [])..fetch();

  print("Checking proxies...");
  var checker =
      new ProxyChecker(config["check"], config["timeout"], config["pokemon"]);

  var working = await scraper.stream.transform(checker).toList();
  print("${working.length}/${checker.totalProxies} proxy(ies) are functional.");

  for (ProxyDef proxy in working) {
    print("Found proxy: ${proxy.ip}:${proxy.port}");
  }

  exit(0);
}
