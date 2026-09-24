#include "native_http.h"

#include <windows.h>
#include <winhttp.h>

#include <algorithm>
#include <cwctype>

namespace {

constexpr size_t kMaxResponseBytes = 8 * 1024 * 1024;

std::wstring Widen(const std::string& value) {
  if (value.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0);
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), length);
  return result;
}

std::string LastErrorText(const char* stage) {
  return std::string(stage) + " failed (" + std::to_string(GetLastError()) +
         ")";
}

// Owns one WinHTTP handle.
class Handle {
 public:
  explicit Handle(HINTERNET handle) : handle_(handle) {}
  ~Handle() {
    if (handle_) WinHttpCloseHandle(handle_);
  }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HINTERNET get() const { return handle_; }
  explicit operator bool() const { return handle_ != nullptr; }

 private:
  HINTERNET handle_;
};

bool ContainsLineBreak(const std::string& value) {
  return value.find('\r') != std::string::npos ||
         value.find('\n') != std::string::npos;
}

}  // namespace

bool NativeHttpIsAllowedKickUrl(const std::string& url) {
  std::wstring wide = Widen(url);
  URL_COMPONENTS parts = {};
  parts.dwStructSize = sizeof(parts);
  parts.dwHostNameLength = static_cast<DWORD>(-1);
  parts.dwUrlPathLength = static_cast<DWORD>(-1);
  if (!WinHttpCrackUrl(wide.c_str(), 0, 0, &parts)) return false;
  if (parts.nScheme != INTERNET_SCHEME_HTTPS) return false;
  std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
  std::transform(host.begin(), host.end(), host.begin(), ::towlower);
  return host == L"kick.com";
}

NativeHttpResponse NativeHttpGet(
    const std::string& url,
    const std::vector<std::pair<std::string, std::string>>& headers,
    const std::string& proxy, int timeout_ms) {
  NativeHttpResponse response;
  const std::wstring wide_url = Widen(url);
  URL_COMPONENTS parts = {};
  parts.dwStructSize = sizeof(parts);
  parts.dwHostNameLength = static_cast<DWORD>(-1);
  parts.dwUrlPathLength = static_cast<DWORD>(-1);
  parts.dwExtraInfoLength = static_cast<DWORD>(-1);
  if (!WinHttpCrackUrl(wide_url.c_str(), 0, 0, &parts)) {
    response.error = LastErrorText("WinHttpCrackUrl");
    return response;
  }
  const std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
  std::wstring path(parts.lpszUrlPath, parts.dwUrlPathLength);
  if (parts.lpszExtraInfo) path.append(parts.lpszExtraInfo, parts.dwExtraInfoLength);
  if (path.empty()) path = L"/";

  std::wstring user_agent = L"Mozilla/5.0";
  for (const auto& [name, value] : headers) {
    std::string lower = name;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    if (lower == "user-agent") user_agent = Widen(value);
  }

  const std::wstring wide_proxy = Widen(proxy);
  Handle session(WinHttpOpen(
      user_agent.c_str(),
      wide_proxy.empty() ? WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY
                         : WINHTTP_ACCESS_TYPE_NAMED_PROXY,
      wide_proxy.empty() ? WINHTTP_NO_PROXY_NAME : wide_proxy.c_str(),
      WINHTTP_NO_PROXY_BYPASS, 0));
  if (!session) {
    response.error = LastErrorText("WinHttpOpen");
    return response;
  }
  WinHttpSetTimeouts(session.get(), timeout_ms, timeout_ms, timeout_ms,
                     timeout_ms);
  DWORD decompression = WINHTTP_DECOMPRESSION_FLAG_ALL;
  WinHttpSetOption(session.get(), WINHTTP_OPTION_DECOMPRESSION, &decompression,
                   sizeof(decompression));

  Handle connection(WinHttpConnect(session.get(), host.c_str(), parts.nPort, 0));
  if (!connection) {
    response.error = LastErrorText("WinHttpConnect");
    return response;
  }
  Handle request(WinHttpOpenRequest(
      connection.get(), L"GET", path.c_str(), nullptr, WINHTTP_NO_REFERER,
      WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE));
  if (!request) {
    response.error = LastErrorText("WinHttpOpenRequest");
    return response;
  }
  DWORD no_redirect = WINHTTP_DISABLE_REDIRECTS;
  WinHttpSetOption(request.get(), WINHTTP_OPTION_DISABLE_FEATURE, &no_redirect,
                   sizeof(no_redirect));

  std::wstring header_block;
  for (const auto& [name, value] : headers) {
    std::string lower = name;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    if (lower == "user-agent" || lower == "host" || lower == "content-length" ||
        lower == "connection" || lower == "accept-encoding" ||
        ContainsLineBreak(name) || ContainsLineBreak(value)) {
      continue;
    }
    header_block += Widen(name) + L": " + Widen(value) + L"\r\n";
  }
  if (!WinHttpSendRequest(request.get(),
                          header_block.empty() ? WINHTTP_NO_ADDITIONAL_HEADERS
                                               : header_block.c_str(),
                          header_block.empty() ? 0 : static_cast<DWORD>(-1),
                          WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
      !WinHttpReceiveResponse(request.get(), nullptr)) {
    response.error = LastErrorText("WinHttpSendRequest");
    return response;
  }

  DWORD status = 0;
  DWORD status_size = sizeof(status);
  if (!WinHttpQueryHeaders(request.get(),
                           WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                           WINHTTP_HEADER_NAME_BY_INDEX, &status, &status_size,
                           WINHTTP_NO_HEADER_INDEX)) {
    response.error = LastErrorText("WinHttpQueryHeaders");
    return response;
  }
  response.status = static_cast<int>(status);

  while (true) {
    DWORD available = 0;
    if (!WinHttpQueryDataAvailable(request.get(), &available)) {
      response.error = LastErrorText("WinHttpQueryDataAvailable");
      return response;
    }
    if (available == 0) break;
    if (response.body.size() + available > kMaxResponseBytes) {
      response.error = "response exceeds limit";
      return response;
    }
    const size_t offset = response.body.size();
    response.body.resize(offset + available);
    DWORD read = 0;
    if (!WinHttpReadData(request.get(), response.body.data() + offset,
                         available, &read)) {
      response.error = LastErrorText("WinHttpReadData");
      return response;
    }
    response.body.resize(offset + read);
  }
  return response;
}
