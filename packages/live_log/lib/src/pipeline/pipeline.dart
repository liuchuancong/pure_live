/// How a record travels: the context it carries, the dispatcher that fans it
/// out, the sanitiser that strips secrets and the reporter that turns a record
/// into a framework error.
library;

export 'context.dart';
export 'dispatcher.dart';
export 'error_reporter.dart';
export 'sanitizer.dart';
