final RegExp _cookieControlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

/// Converts persisted or pasted browser Cookie header text into one safe value.
String normalizeAccountCookie(String value) {
  return value.replaceAll(_cookieControlCharacters, '').trim();
}
