class DnsResponse {
  //原始数据
  final String origin;
  String? web;
  String? host;
  String? aff;
  String? api;

  DnsResponse(this.origin, {this.web, this.host, this.aff, this.api});
}