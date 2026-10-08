library;

final RegExp _invisiblePlaceholders = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F￹-￼￾￿]');

String stripInvisiblePlaceholders(String text) =>
    _invisiblePlaceholders.hasMatch(text) ? text.replaceAll(_invisiblePlaceholders, '') : text;

String? stripInvisiblePlaceholdersOrNull(String? text) => text == null ? null : stripInvisiblePlaceholders(text);
