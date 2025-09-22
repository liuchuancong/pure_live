import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dns_response.dart';
import 'package:async/async.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

// use case
// Future<void> main() async {
//   var resp = await DnsHelper.lookupTxt('front.jetstream.site');
//   var host = resp?.host;
//   var web = resp?.web;
//
// }

class DnsHelper {
  static final Logger _logger = kReleaseMode
      ? Logger(
          level: Level.warning,
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            // printTime: true,
            dateTimeFormat: DateTimeFormat.dateAndTime,
          ),
          filter: ProductionFilter(),
        )
      : Logger(
          level: Level.trace,
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            // printTime: true,
            dateTimeFormat: DateTimeFormat.dateAndTime,
          ),
        );

  static var timeoutMilliseconds = 1000;

  static const https = "https://";

  static const List<String> _defaultDnsUrls = [
    "https://doh.pub/dns-query", //腾讯云
    "https://doh.360.cn/resolve", //360
    "https://dns.alidns.com/resolve", //阿里云
  ];

  static final _httpClient = HttpClient();
  static Future<DnsResponse?> lookupTxt(String host, {List<String> dnsUrls = _defaultDnsUrls}) async {
    for (var dnsUrl in dnsUrls) {
      try {
        var request = await _httpClient.getUrl(Uri.parse("$dnsUrl?name=$host&type=TXT"));
        request.headers.set('accept', 'application/dns-json');

        _logger.i('Requesting DNS record for $host from $dnsUrl');
        // Add a timeout to the response
        var response = await request.close().timeout(const Duration(milliseconds: 500));

        var responseBody = await utf8.decodeStream(response);
        var jsonResponse = jsonDecode(responseBody);

        if (jsonResponse['Answer'] != null && jsonResponse['Answer'].isNotEmpty) {
          for (var answer in jsonResponse['Answer']) {
            if (answer['type'] == 16) {
              // TXT record type
              var rdata = answer['data'];
              _logger.i('Parsed TXT record: $rdata');
              return _parseData(rdata);
            }
          }
        }
      } catch (e) {
        if (e is TimeoutException) {
          _logger.w('Request timed out for $dnsUrl');
        } else {
          _logger.w('Error occurred: $e');
        }
      }
    }
    _logger.e('No DNS record found for $host');
    return null;
  }

  static DnsResponse _parseData(String data) {
    // Strip the leading and trailing double quotes from the data
    if (data.startsWith('"') && data.endsWith('"')) {
      data = data.substring(1, data.length - 1);
    }
    //裁切
    var list = data.split(":");
    String? web;
    String? host;
    String? aff;
    String? api;
    for (var element in list) {
      if (element.contains("host")) {
        host = https + element.split("=").last;
      } else if (element.contains("web")) {
        web = https + element.split("=").last;
      } else if (element.contains("aff")) {
        aff = https + element.split("=").last;
      } else if (element.contains("api")) {
        api = element.split("=").last;
      }
    }
    return DnsResponse(data, host: host, web: web, aff: aff, api: api);
  }

  static final Map<String, CachedDnsResult> _dnsCache = {};

  static Future<List<String>> lookupARecords(String domain, {List<String> dnsUrls = _defaultDnsUrls}) async {
    // Skip localhost lookup
    if (domain.toLowerCase() == 'localhost') {
      _logger.i('Skipping DNS lookup for localhost');
      return ['127.0.0.1'];
    }
    // Check cache first
    if (_dnsCache.containsKey(domain)) {
      var cachedResult = _dnsCache[domain]!;
      if (DateTime.now().difference(cachedResult.timestamp).inMinutes < 5) {
        _logger.i('Returning cached A records for $domain');
        _logger.i('Found cached A records: ${cachedResult.ips} for $domain');
        return cachedResult.ips;
      }
    }

    var requestQuery = "name=$domain&type=A";

    var group = FutureGroup<List<String>>();

    for (var dnsUrl in dnsUrls) {
      group.add(_queryDnsServer(dnsUrl, requestQuery));
    }

    group.close();

    List<String> allIps = [];

    try {
      var results = await group.future.timeout(Duration(milliseconds: timeoutMilliseconds * 2));
      for (var ips in results) {
        allIps.addAll(ips);
      }
    } on TimeoutException {
      _logger.w('Timeout occurred while querying DNS servers');
    }

    // Remove duplicates
    var uniqueIps = allIps.toSet().toList();

    // Cache the result
    _dnsCache[domain] = CachedDnsResult(uniqueIps, DateTime.now());

    _logger.i('Found ${uniqueIps.length} unique IP(s) for $domain: $uniqueIps');
    return uniqueIps;
  }

  static Future<List<String>> _queryDnsServer(String dnsUrl, String requestQuery) async {
    try {
      var request = await _httpClient.getUrl(Uri.parse("$dnsUrl?$requestQuery"));
      _logger.i('Requesting A records from $dnsUrl for $requestQuery');

      var response = await request.close().timeout(Duration(milliseconds: timeoutMilliseconds));
      var responseBody = await utf8.decodeStream(response);
      var jsonResponse = jsonDecode(responseBody);

      List<String> ips = [];
      if (jsonResponse['Answer'] != null) {
        for (var answer in jsonResponse['Answer']) {
          if (answer['type'] == 1) {
            // Type 1 is A record
            ips.add(answer['data']);
          }
        }
      }

      _logger.i('Parsed ${ips.length} IP(s) from JSON response from $dnsUrl for $requestQuery');
      return ips;
    } catch (e) {
      if (e is TimeoutException) {
        _logger.w('Timeout querying $dnsUrl for $requestQuery');
      } else {
        _logger.w('Error querying $dnsUrl for $requestQuery: $e');
      }
      return [];
    }
  }
}

class CachedDnsResult {
  final List<String> ips;
  final DateTime timestamp;

  CachedDnsResult(this.ips, this.timestamp);
}
