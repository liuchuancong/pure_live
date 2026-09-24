#ifndef RUNNER_NATIVE_HTTP_H_
#define RUNNER_NATIVE_HTTP_H_

#include <string>
#include <utility>
#include <vector>

// Minimal WinHTTP (Schannel) GET for hosts whose Cloudflare edge rejects the
// dart:io TLS fingerprint, currently kick.com only.
struct NativeHttpResponse {
  int status = 0;
  std::string body;
  std::string error;
};

// |url| and header values are UTF-8. |proxy| is "host:port" or empty to use
// the system proxy configuration.
NativeHttpResponse NativeHttpGet(
    const std::string& url,
    const std::vector<std::pair<std::string, std::string>>& headers,
    const std::string& proxy, int timeout_ms);

// True for https://kick.com/... only; the channel refuses any other target.
bool NativeHttpIsAllowedKickUrl(const std::string& url);

#endif  // RUNNER_NATIVE_HTTP_H_
