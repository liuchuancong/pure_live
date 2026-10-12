/// Storage infrastructure for Pure Live.
///
/// Layered per the storage architecture spec: business modules depend on
/// the interfaces in `contracts/`, never on drift, sqlite or file
/// plugins. The one database seam is a keyed table store — callers name
/// their tables, every table answers the same CRUD methods, and the
/// package holds no domain logic. Errors are the sealed
/// `StorageException` hierarchy — ten stable categories; adapters
/// translate platform exceptions once, at this boundary. Read failures
/// are failures: nothing here swallows an exception and returns empty
/// data.
///
/// The package is pure Dart. Durable backends plug in at the app shell:
/// directory roots through live_platform's StorageManager, the OS
/// credential vault through `SecureStore`.
library;

export 'src/contracts/file_store.dart';
export 'src/contracts/keyed_store.dart';
export 'src/contracts/secure_store.dart';
export 'src/contracts/storage_exception.dart';
export 'src/database/db_keyed_store.dart';
export 'src/database/pure_live_database.dart';
export 'src/files/platform_file_store.dart';
export 'src/secure/in_memory_secure_store.dart';
export 'src/store/in_memory_keyed_store.dart';
