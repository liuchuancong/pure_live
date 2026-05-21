import 'package:drift/drift.dart';

/// Drift table definitions for clubTivi local database.

/// IPTV service providers (M3U or Xtream Codes).
class Providers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'm3u', 'xtream'
  TextColumn get url => text().nullable()(); // M3U URL or Xtream base URL
  TextColumn get username => text().nullable()(); // Xtream
  TextColumn get password => text().nullable()(); // Xtream
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastRefresh => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Channels from all providers.
class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get providerId => text().references(Providers, #id)();
  TextColumn get name => text()();
  TextColumn get tvgId => text().nullable()();
  TextColumn get tvgName => text().nullable()();
  TextColumn get tvgLogo => text().nullable()();
  TextColumn get groupTitle => text().nullable()();
  IntColumn get channelNumber => integer().nullable()();
  TextColumn get streamUrl => text()();
  TextColumn get streamType => text().withDefault(const Constant('live'))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// EPG data sources (XMLTV feeds).
class EpgSources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get url => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get refreshIntervalHours =>
      integer().withDefault(const Constant(12))();
  DateTimeColumn get lastRefresh => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// EPG channels from XMLTV feeds.
class EpgChannels extends Table {
  TextColumn get id => text()(); // compound: sourceId_channelId
  TextColumn get sourceId => text().references(EpgSources, #id)();
  TextColumn get channelId => text()(); // Original channel ID from XMLTV
  TextColumn get displayName => text()();
  TextColumn get iconUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// EPG programmes (TV listings).
class EpgProgrammes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get epgChannelId => text()();
  TextColumn get sourceId => text().references(EpgSources, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get episodeNum => text().nullable()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get stop => dateTime()();
}

/// Channel ↔ EPG mapping table.
class EpgMappings extends Table {
  TextColumn get channelId => text().references(Channels, #id)();
  TextColumn get providerId => text()();
  TextColumn get epgChannelId => text()();
  TextColumn get epgSourceId => text().references(EpgSources, #id)();
  RealColumn get confidence => real().withDefault(const Constant(0.0))();
  TextColumn get source =>
      text().withDefault(const Constant('auto'))(); // auto, manual, suggested
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {channelId, providerId};
}

/// User-defined channel groups.
class ChannelGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Named favorite lists (e.g., "Sports", "News", "Kids").
class FavoriteLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('star'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join table: channels in a favorite list.
class FavoriteListChannels extends Table {
  TextColumn get listId => text().references(FavoriteLists, #id)();
  TextColumn get channelId => text().references(Channels, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {listId, channelId};
}

/// EPG reminders — notify user before a programme starts.
class EpgReminders extends Table {
  TextColumn get id => text()();
  TextColumn get epgChannelId => text()();
  TextColumn get channelId => text().nullable()(); // link to Channels table
  TextColumn get programmeTitle => text()();
  DateTimeColumn get programmeStart => dateTime()();
  DateTimeColumn get programmeStop => dateTime()();
  IntColumn get minutesBefore => integer().withDefault(const Constant(5))();
  BoolColumn get fired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-defined failover groups — manually curated sets of interchangeable channels.
class FailoverGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Channels belonging to a failover group, ordered by priority.
class FailoverGroupChannels extends Table {
  IntColumn get groupId => integer().references(FailoverGroups, #id)();
  TextColumn get channelId => text().references(Channels, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {groupId, channelId};
}

/// Scheduled recordings — record a programme when it airs.
class ScheduledRecordings extends Table {
  TextColumn get id => text()();
  TextColumn get epgChannelId => text()();
  TextColumn get channelId => text().nullable()();
  TextColumn get programmeTitle => text()();
  DateTimeColumn get programmeStart => dateTime()();
  DateTimeColumn get programmeStop => dateTime()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))(); // scheduled, recording, completed, failed
  TextColumn get outputPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
