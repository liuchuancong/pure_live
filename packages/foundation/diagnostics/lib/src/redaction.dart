// Module: lib/src/redaction.dart
// Purpose: The text scrubbing every diagnostic surface shares, so a report can leave the device.
// Author: liuchuancong
// Created: 2026-10-11
//
// A diagnostics attachment is the one artefact in this app that is written by the machine and read by a
// stranger, and the fields it collects - urls, headers, failure messages - are exactly where a session token
// lives. Each surface used to scrub its own subset, which means each one had a case it missed; one function
// with named patterns is the only version that can be reviewed once.

/// What a redaction rule does to a match.
final class RedactionRule {
  const RedactionRule(this.name, this.pattern, this.replacement);

  /// Reported in [RedactionReport.appliedRules], so a reader knows a value was hidden rather than absent.
  final String name;
  final RegExp pattern;
  final String replacement;
}

/// The rules that always apply: a credential-shaped assignment, userinfo in a url, and a bare long token.
///
/// `final` rather than `const` because a RegExp is not a constant expression; it is still one shared list, and
/// a caller that needs different rules passes its own.
final List<RedactionRule> kDefaultRedactions = <RedactionRule>[
  RedactionRule(
    'credential-field',
    RegExp(
      // The tail group is what an `Authorization: Bearer <token>` needs: masking only the first word would
      // leave the credential standing behind its own redaction. A `&` or a quote ends the value, so a query
      // string keeps its other parameters.
      r"""\b(authorization|proxy-authorization|cookie|set-cookie|api[_-]?key|apikey|access[_-]?token|token|secret|password|passwd|sign|wts)\b(\s*[=:]\s*)([^\s&,;"']{3,})((?:[ \t]+[^\s&,;"']+)*)""",
      caseSensitive: false,
    ),
    r'$1$2***',
  ),
  RedactionRule('url-userinfo', RegExp(r'(\bhttps?://)[^\s/@:]+:[^\s/@]+@', caseSensitive: false), r'$1***@'),
  RedactionRule('bare-token', RegExp(r'\b[0-9a-fA-F]{32,}\b'), '***'),
];

/// What a scrub pass changed.
final class RedactionReport {
  const RedactionReport({required this.text, required this.appliedRules, required this.hits});

  final String text;

  /// Rule names that matched, in rule order. Empty means the text left untouched.
  final List<String> appliedRules;

  /// Total replacements.
  final int hits;

  bool get isClean => hits == 0;

  @override
  String toString() => 'RedactionReport(${appliedRules.join(', ')}: $hits replaced)';
}

/// Replaces every credential shape in [text] that one of [rules] matches.
///
/// Applied repeatedly until a pass changes nothing: a token that survives one rule's boundary can land inside
/// the next one's match, and a report is not "mostly" scrubbed.
RedactionReport scrub(String text, {List<RedactionRule>? rules, int maxPasses = 4}) {
  final active = rules ?? kDefaultRedactions;
  var current = text;
  var hits = 0;
  final applied = <String>{};
  for (var pass = 0; pass < maxPasses; pass++) {
    var changedThisPass = 0;
    for (final rule in active) {
      final replaced = current.replaceAllMapped(rule.pattern, (match) {
        changedThisPass++;
        applied.add(rule.name);
        return _expand(rule, match);
      });
      current = replaced;
    }
    hits += changedThisPass;
    if (changedThisPass == 0) {
      break;
    }
  }
  return RedactionReport(text: current, appliedRules: applied.toList(growable: false), hits: hits);
}

/// One replacement, with the rule's `$1`-style back references filled from the match.
String _expand(RedactionRule rule, Match match) {
  var out = rule.replacement;
  for (var group = match.groupCount; group >= 1; group--) {
    out = out.replaceAll('\$$group', match.group(group) ?? '');
  }
  return out;
}

/// The single-string form most callers want: scrubbed text, no ceremony.
String redactSecrets(String text) => scrub(text).text;
