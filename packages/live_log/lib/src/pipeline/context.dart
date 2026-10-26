/// Immutable structured context attached to a `LiveLog` view.
///
/// Context fields are merged into every record the view emits; fields
/// passed at the call site win over context values with the same key. Use
/// it for request ids, task ids or site ids that would otherwise be
/// repeated on every call.
final class LogContext {
  /// A context carrying [fields]; defaults to empty.
  const new([this.fields = const {}]);

  /// The context-free instance.
  static const LogContext empty = LogContext();

  /// The carried key-value pairs.
  final Map<String, Object?> fields;

  /// Whether this context carries no fields.
  bool get isEmpty => fields.isEmpty;

  /// A context with [other]'s fields layered over this one's.
  LogContext merge(LogContext other) {
    if (isEmpty) {
      return other;
    }
    if (other.isEmpty) {
      return this;
    }
    return LogContext({...fields, ...other.fields});
  }

  @override
  String toString() => 'LogContext($fields)';
}
