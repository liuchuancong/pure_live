// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProvidersTable extends Providers
    with TableInfo<$ProvidersTable, Provider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordMeta = const VerificationMeta(
    'password',
  );
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
    'password',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastRefreshMeta = const VerificationMeta(
    'lastRefresh',
  );
  @override
  late final GeneratedColumn<DateTime> lastRefresh = GeneratedColumn<DateTime>(
    'last_refresh',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    url,
    username,
    password,
    sortOrder,
    enabled,
    lastRefresh,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Provider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('password')) {
      context.handle(
        _passwordMeta,
        password.isAcceptableOrUnknown(data['password']!, _passwordMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_refresh')) {
      context.handle(
        _lastRefreshMeta,
        lastRefresh.isAcceptableOrUnknown(
          data['last_refresh']!,
          _lastRefreshMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Provider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Provider(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      password: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastRefresh: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_refresh'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProvidersTable createAlias(String alias) {
    return $ProvidersTable(attachedDatabase, alias);
  }
}

class Provider extends DataClass implements Insertable<Provider> {
  final String id;
  final String name;
  final String type;
  final String? url;
  final String? username;
  final String? password;
  final int sortOrder;
  final bool enabled;
  final DateTime? lastRefresh;
  final DateTime createdAt;
  const Provider({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.username,
    this.password,
    required this.sortOrder,
    required this.enabled,
    this.lastRefresh,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || password != null) {
      map['password'] = Variable<String>(password);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastRefresh != null) {
      map['last_refresh'] = Variable<DateTime>(lastRefresh);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProvidersCompanion toCompanion(bool nullToAbsent) {
    return ProvidersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      password: password == null && nullToAbsent
          ? const Value.absent()
          : Value(password),
      sortOrder: Value(sortOrder),
      enabled: Value(enabled),
      lastRefresh: lastRefresh == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRefresh),
      createdAt: Value(createdAt),
    );
  }

  factory Provider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Provider(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      url: serializer.fromJson<String?>(json['url']),
      username: serializer.fromJson<String?>(json['username']),
      password: serializer.fromJson<String?>(json['password']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastRefresh: serializer.fromJson<DateTime?>(json['lastRefresh']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'url': serializer.toJson<String?>(url),
      'username': serializer.toJson<String?>(username),
      'password': serializer.toJson<String?>(password),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'enabled': serializer.toJson<bool>(enabled),
      'lastRefresh': serializer.toJson<DateTime?>(lastRefresh),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Provider copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> url = const Value.absent(),
    Value<String?> username = const Value.absent(),
    Value<String?> password = const Value.absent(),
    int? sortOrder,
    bool? enabled,
    Value<DateTime?> lastRefresh = const Value.absent(),
    DateTime? createdAt,
  }) => Provider(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    url: url.present ? url.value : this.url,
    username: username.present ? username.value : this.username,
    password: password.present ? password.value : this.password,
    sortOrder: sortOrder ?? this.sortOrder,
    enabled: enabled ?? this.enabled,
    lastRefresh: lastRefresh.present ? lastRefresh.value : this.lastRefresh,
    createdAt: createdAt ?? this.createdAt,
  );
  Provider copyWithCompanion(ProvidersCompanion data) {
    return Provider(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      url: data.url.present ? data.url.value : this.url,
      username: data.username.present ? data.username.value : this.username,
      password: data.password.present ? data.password.value : this.password,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastRefresh: data.lastRefresh.present
          ? data.lastRefresh.value
          : this.lastRefresh,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Provider(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('enabled: $enabled, ')
          ..write('lastRefresh: $lastRefresh, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    url,
    username,
    password,
    sortOrder,
    enabled,
    lastRefresh,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Provider &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.url == this.url &&
          other.username == this.username &&
          other.password == this.password &&
          other.sortOrder == this.sortOrder &&
          other.enabled == this.enabled &&
          other.lastRefresh == this.lastRefresh &&
          other.createdAt == this.createdAt);
}

class ProvidersCompanion extends UpdateCompanion<Provider> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> url;
  final Value<String?> username;
  final Value<String?> password;
  final Value<int> sortOrder;
  final Value<bool> enabled;
  final Value<DateTime?> lastRefresh;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.url = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastRefresh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProvidersCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.url = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastRefresh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type);
  static Insertable<Provider> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? url,
    Expression<String>? username,
    Expression<String>? password,
    Expression<int>? sortOrder,
    Expression<bool>? enabled,
    Expression<DateTime>? lastRefresh,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (url != null) 'url': url,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (enabled != null) 'enabled': enabled,
      if (lastRefresh != null) 'last_refresh': lastRefresh,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProvidersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? url,
    Value<String?>? username,
    Value<String?>? password,
    Value<int>? sortOrder,
    Value<bool>? enabled,
    Value<DateTime?>? lastRefresh,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastRefresh.present) {
      map['last_refresh'] = Variable<DateTime>(lastRefresh.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('enabled: $enabled, ')
          ..write('lastRefresh: $lastRefresh, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels with TableInfo<$ChannelsTable, Channel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES providers (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tvgIdMeta = const VerificationMeta('tvgId');
  @override
  late final GeneratedColumn<String> tvgId = GeneratedColumn<String>(
    'tvg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tvgNameMeta = const VerificationMeta(
    'tvgName',
  );
  @override
  late final GeneratedColumn<String> tvgName = GeneratedColumn<String>(
    'tvg_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tvgLogoMeta = const VerificationMeta(
    'tvgLogo',
  );
  @override
  late final GeneratedColumn<String> tvgLogo = GeneratedColumn<String>(
    'tvg_logo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupTitleMeta = const VerificationMeta(
    'groupTitle',
  );
  @override
  late final GeneratedColumn<String> groupTitle = GeneratedColumn<String>(
    'group_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelNumberMeta = const VerificationMeta(
    'channelNumber',
  );
  @override
  late final GeneratedColumn<int> channelNumber = GeneratedColumn<int>(
    'channel_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streamTypeMeta = const VerificationMeta(
    'streamType',
  );
  @override
  late final GeneratedColumn<String> streamType = GeneratedColumn<String>(
    'stream_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('live'),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerId,
    name,
    tvgId,
    tvgName,
    tvgLogo,
    groupTitle,
    channelNumber,
    streamUrl,
    streamType,
    favorite,
    hidden,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Channel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tvg_id')) {
      context.handle(
        _tvgIdMeta,
        tvgId.isAcceptableOrUnknown(data['tvg_id']!, _tvgIdMeta),
      );
    }
    if (data.containsKey('tvg_name')) {
      context.handle(
        _tvgNameMeta,
        tvgName.isAcceptableOrUnknown(data['tvg_name']!, _tvgNameMeta),
      );
    }
    if (data.containsKey('tvg_logo')) {
      context.handle(
        _tvgLogoMeta,
        tvgLogo.isAcceptableOrUnknown(data['tvg_logo']!, _tvgLogoMeta),
      );
    }
    if (data.containsKey('group_title')) {
      context.handle(
        _groupTitleMeta,
        groupTitle.isAcceptableOrUnknown(data['group_title']!, _groupTitleMeta),
      );
    }
    if (data.containsKey('channel_number')) {
      context.handle(
        _channelNumberMeta,
        channelNumber.isAcceptableOrUnknown(
          data['channel_number']!,
          _channelNumberMeta,
        ),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('stream_type')) {
      context.handle(
        _streamTypeMeta,
        streamType.isAcceptableOrUnknown(data['stream_type']!, _streamTypeMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Channel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Channel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tvgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tvg_id'],
      ),
      tvgName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tvg_name'],
      ),
      tvgLogo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tvg_logo'],
      ),
      groupTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_title'],
      ),
      channelNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_number'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      )!,
      streamType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_type'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class Channel extends DataClass implements Insertable<Channel> {
  final String id;
  final String providerId;
  final String name;
  final String? tvgId;
  final String? tvgName;
  final String? tvgLogo;
  final String? groupTitle;
  final int? channelNumber;
  final String streamUrl;
  final String streamType;
  final bool favorite;
  final bool hidden;
  final int sortOrder;
  const Channel({
    required this.id,
    required this.providerId,
    required this.name,
    this.tvgId,
    this.tvgName,
    this.tvgLogo,
    this.groupTitle,
    this.channelNumber,
    required this.streamUrl,
    required this.streamType,
    required this.favorite,
    required this.hidden,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || tvgId != null) {
      map['tvg_id'] = Variable<String>(tvgId);
    }
    if (!nullToAbsent || tvgName != null) {
      map['tvg_name'] = Variable<String>(tvgName);
    }
    if (!nullToAbsent || tvgLogo != null) {
      map['tvg_logo'] = Variable<String>(tvgLogo);
    }
    if (!nullToAbsent || groupTitle != null) {
      map['group_title'] = Variable<String>(groupTitle);
    }
    if (!nullToAbsent || channelNumber != null) {
      map['channel_number'] = Variable<int>(channelNumber);
    }
    map['stream_url'] = Variable<String>(streamUrl);
    map['stream_type'] = Variable<String>(streamType);
    map['favorite'] = Variable<bool>(favorite);
    map['hidden'] = Variable<bool>(hidden);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      name: Value(name),
      tvgId: tvgId == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgId),
      tvgName: tvgName == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgName),
      tvgLogo: tvgLogo == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgLogo),
      groupTitle: groupTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(groupTitle),
      channelNumber: channelNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(channelNumber),
      streamUrl: Value(streamUrl),
      streamType: Value(streamType),
      favorite: Value(favorite),
      hidden: Value(hidden),
      sortOrder: Value(sortOrder),
    );
  }

  factory Channel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Channel(
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      name: serializer.fromJson<String>(json['name']),
      tvgId: serializer.fromJson<String?>(json['tvgId']),
      tvgName: serializer.fromJson<String?>(json['tvgName']),
      tvgLogo: serializer.fromJson<String?>(json['tvgLogo']),
      groupTitle: serializer.fromJson<String?>(json['groupTitle']),
      channelNumber: serializer.fromJson<int?>(json['channelNumber']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      streamType: serializer.fromJson<String>(json['streamType']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'name': serializer.toJson<String>(name),
      'tvgId': serializer.toJson<String?>(tvgId),
      'tvgName': serializer.toJson<String?>(tvgName),
      'tvgLogo': serializer.toJson<String?>(tvgLogo),
      'groupTitle': serializer.toJson<String?>(groupTitle),
      'channelNumber': serializer.toJson<int?>(channelNumber),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'streamType': serializer.toJson<String>(streamType),
      'favorite': serializer.toJson<bool>(favorite),
      'hidden': serializer.toJson<bool>(hidden),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Channel copyWith({
    String? id,
    String? providerId,
    String? name,
    Value<String?> tvgId = const Value.absent(),
    Value<String?> tvgName = const Value.absent(),
    Value<String?> tvgLogo = const Value.absent(),
    Value<String?> groupTitle = const Value.absent(),
    Value<int?> channelNumber = const Value.absent(),
    String? streamUrl,
    String? streamType,
    bool? favorite,
    bool? hidden,
    int? sortOrder,
  }) => Channel(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    tvgId: tvgId.present ? tvgId.value : this.tvgId,
    tvgName: tvgName.present ? tvgName.value : this.tvgName,
    tvgLogo: tvgLogo.present ? tvgLogo.value : this.tvgLogo,
    groupTitle: groupTitle.present ? groupTitle.value : this.groupTitle,
    channelNumber: channelNumber.present
        ? channelNumber.value
        : this.channelNumber,
    streamUrl: streamUrl ?? this.streamUrl,
    streamType: streamType ?? this.streamType,
    favorite: favorite ?? this.favorite,
    hidden: hidden ?? this.hidden,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Channel copyWithCompanion(ChannelsCompanion data) {
    return Channel(
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      tvgId: data.tvgId.present ? data.tvgId.value : this.tvgId,
      tvgName: data.tvgName.present ? data.tvgName.value : this.tvgName,
      tvgLogo: data.tvgLogo.present ? data.tvgLogo.value : this.tvgLogo,
      groupTitle: data.groupTitle.present
          ? data.groupTitle.value
          : this.groupTitle,
      channelNumber: data.channelNumber.present
          ? data.channelNumber.value
          : this.channelNumber,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      streamType: data.streamType.present
          ? data.streamType.value
          : this.streamType,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Channel(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('tvgId: $tvgId, ')
          ..write('tvgName: $tvgName, ')
          ..write('tvgLogo: $tvgLogo, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('channelNumber: $channelNumber, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('streamType: $streamType, ')
          ..write('favorite: $favorite, ')
          ..write('hidden: $hidden, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    name,
    tvgId,
    tvgName,
    tvgLogo,
    groupTitle,
    channelNumber,
    streamUrl,
    streamType,
    favorite,
    hidden,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Channel &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.tvgId == this.tvgId &&
          other.tvgName == this.tvgName &&
          other.tvgLogo == this.tvgLogo &&
          other.groupTitle == this.groupTitle &&
          other.channelNumber == this.channelNumber &&
          other.streamUrl == this.streamUrl &&
          other.streamType == this.streamType &&
          other.favorite == this.favorite &&
          other.hidden == this.hidden &&
          other.sortOrder == this.sortOrder);
}

class ChannelsCompanion extends UpdateCompanion<Channel> {
  final Value<String> id;
  final Value<String> providerId;
  final Value<String> name;
  final Value<String?> tvgId;
  final Value<String?> tvgName;
  final Value<String?> tvgLogo;
  final Value<String?> groupTitle;
  final Value<int?> channelNumber;
  final Value<String> streamUrl;
  final Value<String> streamType;
  final Value<bool> favorite;
  final Value<bool> hidden;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.tvgName = const Value.absent(),
    this.tvgLogo = const Value.absent(),
    this.groupTitle = const Value.absent(),
    this.channelNumber = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.streamType = const Value.absent(),
    this.favorite = const Value.absent(),
    this.hidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String id,
    required String providerId,
    required String name,
    this.tvgId = const Value.absent(),
    this.tvgName = const Value.absent(),
    this.tvgLogo = const Value.absent(),
    this.groupTitle = const Value.absent(),
    this.channelNumber = const Value.absent(),
    required String streamUrl,
    this.streamType = const Value.absent(),
    this.favorite = const Value.absent(),
    this.hidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       providerId = Value(providerId),
       name = Value(name),
       streamUrl = Value(streamUrl);
  static Insertable<Channel> custom({
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? tvgId,
    Expression<String>? tvgName,
    Expression<String>? tvgLogo,
    Expression<String>? groupTitle,
    Expression<int>? channelNumber,
    Expression<String>? streamUrl,
    Expression<String>? streamType,
    Expression<bool>? favorite,
    Expression<bool>? hidden,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (tvgId != null) 'tvg_id': tvgId,
      if (tvgName != null) 'tvg_name': tvgName,
      if (tvgLogo != null) 'tvg_logo': tvgLogo,
      if (groupTitle != null) 'group_title': groupTitle,
      if (channelNumber != null) 'channel_number': channelNumber,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (streamType != null) 'stream_type': streamType,
      if (favorite != null) 'favorite': favorite,
      if (hidden != null) 'hidden': hidden,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith({
    Value<String>? id,
    Value<String>? providerId,
    Value<String>? name,
    Value<String?>? tvgId,
    Value<String?>? tvgName,
    Value<String?>? tvgLogo,
    Value<String?>? groupTitle,
    Value<int?>? channelNumber,
    Value<String>? streamUrl,
    Value<String>? streamType,
    Value<bool>? favorite,
    Value<bool>? hidden,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ChannelsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      tvgLogo: tvgLogo ?? this.tvgLogo,
      groupTitle: groupTitle ?? this.groupTitle,
      channelNumber: channelNumber ?? this.channelNumber,
      streamUrl: streamUrl ?? this.streamUrl,
      streamType: streamType ?? this.streamType,
      favorite: favorite ?? this.favorite,
      hidden: hidden ?? this.hidden,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tvgId.present) {
      map['tvg_id'] = Variable<String>(tvgId.value);
    }
    if (tvgName.present) {
      map['tvg_name'] = Variable<String>(tvgName.value);
    }
    if (tvgLogo.present) {
      map['tvg_logo'] = Variable<String>(tvgLogo.value);
    }
    if (groupTitle.present) {
      map['group_title'] = Variable<String>(groupTitle.value);
    }
    if (channelNumber.present) {
      map['channel_number'] = Variable<int>(channelNumber.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (streamType.present) {
      map['stream_type'] = Variable<String>(streamType.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('tvgId: $tvgId, ')
          ..write('tvgName: $tvgName, ')
          ..write('tvgLogo: $tvgLogo, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('channelNumber: $channelNumber, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('streamType: $streamType, ')
          ..write('favorite: $favorite, ')
          ..write('hidden: $hidden, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgSourcesTable extends EpgSources
    with TableInfo<$EpgSourcesTable, EpgSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _refreshIntervalHoursMeta =
      const VerificationMeta('refreshIntervalHours');
  @override
  late final GeneratedColumn<int> refreshIntervalHours = GeneratedColumn<int>(
    'refresh_interval_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _lastRefreshMeta = const VerificationMeta(
    'lastRefresh',
  );
  @override
  late final GeneratedColumn<DateTime> lastRefresh = GeneratedColumn<DateTime>(
    'last_refresh',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    enabled,
    refreshIntervalHours,
    lastRefresh,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('refresh_interval_hours')) {
      context.handle(
        _refreshIntervalHoursMeta,
        refreshIntervalHours.isAcceptableOrUnknown(
          data['refresh_interval_hours']!,
          _refreshIntervalHoursMeta,
        ),
      );
    }
    if (data.containsKey('last_refresh')) {
      context.handle(
        _lastRefreshMeta,
        lastRefresh.isAcceptableOrUnknown(
          data['last_refresh']!,
          _lastRefreshMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      refreshIntervalHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refresh_interval_hours'],
      )!,
      lastRefresh: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_refresh'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EpgSourcesTable createAlias(String alias) {
    return $EpgSourcesTable(attachedDatabase, alias);
  }
}

class EpgSource extends DataClass implements Insertable<EpgSource> {
  final String id;
  final String name;
  final String url;
  final bool enabled;
  final int refreshIntervalHours;
  final DateTime? lastRefresh;
  final DateTime createdAt;
  const EpgSource({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
    required this.refreshIntervalHours,
    this.lastRefresh,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    map['enabled'] = Variable<bool>(enabled);
    map['refresh_interval_hours'] = Variable<int>(refreshIntervalHours);
    if (!nullToAbsent || lastRefresh != null) {
      map['last_refresh'] = Variable<DateTime>(lastRefresh);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EpgSourcesCompanion toCompanion(bool nullToAbsent) {
    return EpgSourcesCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      enabled: Value(enabled),
      refreshIntervalHours: Value(refreshIntervalHours),
      lastRefresh: lastRefresh == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRefresh),
      createdAt: Value(createdAt),
    );
  }

  factory EpgSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgSource(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      refreshIntervalHours: serializer.fromJson<int>(
        json['refreshIntervalHours'],
      ),
      lastRefresh: serializer.fromJson<DateTime?>(json['lastRefresh']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'enabled': serializer.toJson<bool>(enabled),
      'refreshIntervalHours': serializer.toJson<int>(refreshIntervalHours),
      'lastRefresh': serializer.toJson<DateTime?>(lastRefresh),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EpgSource copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
    int? refreshIntervalHours,
    Value<DateTime?> lastRefresh = const Value.absent(),
    DateTime? createdAt,
  }) => EpgSource(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    enabled: enabled ?? this.enabled,
    refreshIntervalHours: refreshIntervalHours ?? this.refreshIntervalHours,
    lastRefresh: lastRefresh.present ? lastRefresh.value : this.lastRefresh,
    createdAt: createdAt ?? this.createdAt,
  );
  EpgSource copyWithCompanion(EpgSourcesCompanion data) {
    return EpgSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      refreshIntervalHours: data.refreshIntervalHours.present
          ? data.refreshIntervalHours.value
          : this.refreshIntervalHours,
      lastRefresh: data.lastRefresh.present
          ? data.lastRefresh.value
          : this.lastRefresh,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('enabled: $enabled, ')
          ..write('refreshIntervalHours: $refreshIntervalHours, ')
          ..write('lastRefresh: $lastRefresh, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    url,
    enabled,
    refreshIntervalHours,
    lastRefresh,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.enabled == this.enabled &&
          other.refreshIntervalHours == this.refreshIntervalHours &&
          other.lastRefresh == this.lastRefresh &&
          other.createdAt == this.createdAt);
}

class EpgSourcesCompanion extends UpdateCompanion<EpgSource> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> url;
  final Value<bool> enabled;
  final Value<int> refreshIntervalHours;
  final Value<DateTime?> lastRefresh;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EpgSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.enabled = const Value.absent(),
    this.refreshIntervalHours = const Value.absent(),
    this.lastRefresh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgSourcesCompanion.insert({
    required String id,
    required String name,
    required String url,
    this.enabled = const Value.absent(),
    this.refreshIntervalHours = const Value.absent(),
    this.lastRefresh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       url = Value(url);
  static Insertable<EpgSource> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<bool>? enabled,
    Expression<int>? refreshIntervalHours,
    Expression<DateTime>? lastRefresh,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (enabled != null) 'enabled': enabled,
      if (refreshIntervalHours != null)
        'refresh_interval_hours': refreshIntervalHours,
      if (lastRefresh != null) 'last_refresh': lastRefresh,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? url,
    Value<bool>? enabled,
    Value<int>? refreshIntervalHours,
    Value<DateTime?>? lastRefresh,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EpgSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      refreshIntervalHours: refreshIntervalHours ?? this.refreshIntervalHours,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (refreshIntervalHours.present) {
      map['refresh_interval_hours'] = Variable<int>(refreshIntervalHours.value);
    }
    if (lastRefresh.present) {
      map['last_refresh'] = Variable<DateTime>(lastRefresh.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('enabled: $enabled, ')
          ..write('refreshIntervalHours: $refreshIntervalHours, ')
          ..write('lastRefresh: $lastRefresh, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsTable extends EpgChannels
    with TableInfo<$EpgChannelsTable, EpgChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES epg_sources (id)',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    channelId,
    displayName,
    iconUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
    );
  }

  @override
  $EpgChannelsTable createAlias(String alias) {
    return $EpgChannelsTable(attachedDatabase, alias);
  }
}

class EpgChannel extends DataClass implements Insertable<EpgChannel> {
  final String id;
  final String sourceId;
  final String channelId;
  final String displayName;
  final String? iconUrl;
  const EpgChannel({
    required this.id,
    required this.sourceId,
    required this.channelId,
    required this.displayName,
    this.iconUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['channel_id'] = Variable<String>(channelId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    return map;
  }

  EpgChannelsCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      channelId: Value(channelId),
      displayName: Value(displayName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
    );
  }

  factory EpgChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannel(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'channelId': serializer.toJson<String>(channelId),
      'displayName': serializer.toJson<String>(displayName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
    };
  }

  EpgChannel copyWith({
    String? id,
    String? sourceId,
    String? channelId,
    String? displayName,
    Value<String?> iconUrl = const Value.absent(),
  }) => EpgChannel(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    channelId: channelId ?? this.channelId,
    displayName: displayName ?? this.displayName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
  );
  EpgChannel copyWithCompanion(EpgChannelsCompanion data) {
    return EpgChannel(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannel(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sourceId, channelId, displayName, iconUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannel &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.channelId == this.channelId &&
          other.displayName == this.displayName &&
          other.iconUrl == this.iconUrl);
}

class EpgChannelsCompanion extends UpdateCompanion<EpgChannel> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> channelId;
  final Value<String> displayName;
  final Value<String?> iconUrl;
  final Value<int> rowid;
  const EpgChannelsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgChannelsCompanion.insert({
    required String id,
    required String sourceId,
    required String channelId,
    required String displayName,
    this.iconUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       channelId = Value(channelId),
       displayName = Value(displayName);
  static Insertable<EpgChannel> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? channelId,
    Expression<String>? displayName,
    Expression<String>? iconUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (channelId != null) 'channel_id': channelId,
      if (displayName != null) 'display_name': displayName,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgChannelsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? channelId,
    Value<String>? displayName,
    Value<String?>? iconUrl,
    Value<int>? rowid,
  }) {
    return EpgChannelsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      channelId: channelId ?? this.channelId,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('channelId: $channelId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgrammesTable extends EpgProgrammes
    with TableInfo<$EpgProgrammesTable, EpgProgramme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgrammesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES epg_sources (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumMeta = const VerificationMeta(
    'episodeNum',
  );
  @override
  late final GeneratedColumn<String> episodeNum = GeneratedColumn<String>(
    'episode_num',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumn<DateTime> stop = GeneratedColumn<DateTime>(
    'stop',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    epgChannelId,
    sourceId,
    title,
    description,
    subtitle,
    episodeNum,
    category,
    start,
    stop,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programmes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgramme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('episode_num')) {
      context.handle(
        _episodeNumMeta,
        episodeNum.isAcceptableOrUnknown(data['episode_num']!, _episodeNumMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('stop')) {
      context.handle(
        _stopMeta,
        stop.isAcceptableOrUnknown(data['stop']!, _stopMeta),
      );
    } else if (isInserting) {
      context.missing(_stopMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgProgramme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      ),
      episodeNum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_num'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      )!,
      stop: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stop'],
      )!,
    );
  }

  @override
  $EpgProgrammesTable createAlias(String alias) {
    return $EpgProgrammesTable(attachedDatabase, alias);
  }
}

class EpgProgramme extends DataClass implements Insertable<EpgProgramme> {
  final int id;
  final String epgChannelId;
  final String sourceId;
  final String title;
  final String? description;
  final String? subtitle;
  final String? episodeNum;
  final String? category;
  final DateTime start;
  final DateTime stop;
  const EpgProgramme({
    required this.id,
    required this.epgChannelId,
    required this.sourceId,
    required this.title,
    this.description,
    this.subtitle,
    this.episodeNum,
    this.category,
    required this.start,
    required this.stop,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    if (!nullToAbsent || episodeNum != null) {
      map['episode_num'] = Variable<String>(episodeNum);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['start'] = Variable<DateTime>(start);
    map['stop'] = Variable<DateTime>(stop);
    return map;
  }

  EpgProgrammesCompanion toCompanion(bool nullToAbsent) {
    return EpgProgrammesCompanion(
      id: Value(id),
      epgChannelId: Value(epgChannelId),
      sourceId: Value(sourceId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      episodeNum: episodeNum == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNum),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      start: Value(start),
      stop: Value(stop),
    );
  }

  factory EpgProgramme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramme(
      id: serializer.fromJson<int>(json['id']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      episodeNum: serializer.fromJson<String?>(json['episodeNum']),
      category: serializer.fromJson<String?>(json['category']),
      start: serializer.fromJson<DateTime>(json['start']),
      stop: serializer.fromJson<DateTime>(json['stop']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'subtitle': serializer.toJson<String?>(subtitle),
      'episodeNum': serializer.toJson<String?>(episodeNum),
      'category': serializer.toJson<String?>(category),
      'start': serializer.toJson<DateTime>(start),
      'stop': serializer.toJson<DateTime>(stop),
    };
  }

  EpgProgramme copyWith({
    int? id,
    String? epgChannelId,
    String? sourceId,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> subtitle = const Value.absent(),
    Value<String?> episodeNum = const Value.absent(),
    Value<String?> category = const Value.absent(),
    DateTime? start,
    DateTime? stop,
  }) => EpgProgramme(
    id: id ?? this.id,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    sourceId: sourceId ?? this.sourceId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    subtitle: subtitle.present ? subtitle.value : this.subtitle,
    episodeNum: episodeNum.present ? episodeNum.value : this.episodeNum,
    category: category.present ? category.value : this.category,
    start: start ?? this.start,
    stop: stop ?? this.stop,
  );
  EpgProgramme copyWithCompanion(EpgProgrammesCompanion data) {
    return EpgProgramme(
      id: data.id.present ? data.id.value : this.id,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      episodeNum: data.episodeNum.present
          ? data.episodeNum.value
          : this.episodeNum,
      category: data.category.present ? data.category.value : this.category,
      start: data.start.present ? data.start.value : this.start,
      stop: data.stop.present ? data.stop.value : this.stop,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramme(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('subtitle: $subtitle, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('category: $category, ')
          ..write('start: $start, ')
          ..write('stop: $stop')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    epgChannelId,
    sourceId,
    title,
    description,
    subtitle,
    episodeNum,
    category,
    start,
    stop,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramme &&
          other.id == this.id &&
          other.epgChannelId == this.epgChannelId &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.description == this.description &&
          other.subtitle == this.subtitle &&
          other.episodeNum == this.episodeNum &&
          other.category == this.category &&
          other.start == this.start &&
          other.stop == this.stop);
}

class EpgProgrammesCompanion extends UpdateCompanion<EpgProgramme> {
  final Value<int> id;
  final Value<String> epgChannelId;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> subtitle;
  final Value<String?> episodeNum;
  final Value<String?> category;
  final Value<DateTime> start;
  final Value<DateTime> stop;
  const EpgProgrammesCompanion({
    this.id = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.category = const Value.absent(),
    this.start = const Value.absent(),
    this.stop = const Value.absent(),
  });
  EpgProgrammesCompanion.insert({
    this.id = const Value.absent(),
    required String epgChannelId,
    required String sourceId,
    required String title,
    this.description = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.category = const Value.absent(),
    required DateTime start,
    required DateTime stop,
  }) : epgChannelId = Value(epgChannelId),
       sourceId = Value(sourceId),
       title = Value(title),
       start = Value(start),
       stop = Value(stop);
  static Insertable<EpgProgramme> custom({
    Expression<int>? id,
    Expression<String>? epgChannelId,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? subtitle,
    Expression<String>? episodeNum,
    Expression<String>? category,
    Expression<DateTime>? start,
    Expression<DateTime>? stop,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (subtitle != null) 'subtitle': subtitle,
      if (episodeNum != null) 'episode_num': episodeNum,
      if (category != null) 'category': category,
      if (start != null) 'start': start,
      if (stop != null) 'stop': stop,
    });
  }

  EpgProgrammesCompanion copyWith({
    Value<int>? id,
    Value<String>? epgChannelId,
    Value<String>? sourceId,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? subtitle,
    Value<String?>? episodeNum,
    Value<String?>? category,
    Value<DateTime>? start,
    Value<DateTime>? stop,
  }) {
    return EpgProgrammesCompanion(
      id: id ?? this.id,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      description: description ?? this.description,
      subtitle: subtitle ?? this.subtitle,
      episodeNum: episodeNum ?? this.episodeNum,
      category: category ?? this.category,
      start: start ?? this.start,
      stop: stop ?? this.stop,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (episodeNum.present) {
      map['episode_num'] = Variable<String>(episodeNum.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (stop.present) {
      map['stop'] = Variable<DateTime>(stop.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgrammesCompanion(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('subtitle: $subtitle, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('category: $category, ')
          ..write('start: $start, ')
          ..write('stop: $stop')
          ..write(')'))
        .toString();
  }
}

class $EpgMappingsTable extends EpgMappings
    with TableInfo<$EpgMappingsTable, EpgMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id)',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgSourceIdMeta = const VerificationMeta(
    'epgSourceId',
  );
  @override
  late final GeneratedColumn<String> epgSourceId = GeneratedColumn<String>(
    'epg_source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES epg_sources (id)',
    ),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    channelId,
    providerId,
    epgChannelId,
    epgSourceId,
    confidence,
    source,
    locked,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('epg_source_id')) {
      context.handle(
        _epgSourceIdMeta,
        epgSourceId.isAcceptableOrUnknown(
          data['epg_source_id']!,
          _epgSourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgSourceIdMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {channelId, providerId};
  @override
  EpgMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgMapping(
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      epgSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_source_id'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EpgMappingsTable createAlias(String alias) {
    return $EpgMappingsTable(attachedDatabase, alias);
  }
}

class EpgMapping extends DataClass implements Insertable<EpgMapping> {
  final String channelId;
  final String providerId;
  final String epgChannelId;
  final String epgSourceId;
  final double confidence;
  final String source;
  final bool locked;
  final DateTime updatedAt;
  const EpgMapping({
    required this.channelId,
    required this.providerId,
    required this.epgChannelId,
    required this.epgSourceId,
    required this.confidence,
    required this.source,
    required this.locked,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['channel_id'] = Variable<String>(channelId);
    map['provider_id'] = Variable<String>(providerId);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    map['epg_source_id'] = Variable<String>(epgSourceId);
    map['confidence'] = Variable<double>(confidence);
    map['source'] = Variable<String>(source);
    map['locked'] = Variable<bool>(locked);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EpgMappingsCompanion toCompanion(bool nullToAbsent) {
    return EpgMappingsCompanion(
      channelId: Value(channelId),
      providerId: Value(providerId),
      epgChannelId: Value(epgChannelId),
      epgSourceId: Value(epgSourceId),
      confidence: Value(confidence),
      source: Value(source),
      locked: Value(locked),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpgMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgMapping(
      channelId: serializer.fromJson<String>(json['channelId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      epgSourceId: serializer.fromJson<String>(json['epgSourceId']),
      confidence: serializer.fromJson<double>(json['confidence']),
      source: serializer.fromJson<String>(json['source']),
      locked: serializer.fromJson<bool>(json['locked']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'channelId': serializer.toJson<String>(channelId),
      'providerId': serializer.toJson<String>(providerId),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'epgSourceId': serializer.toJson<String>(epgSourceId),
      'confidence': serializer.toJson<double>(confidence),
      'source': serializer.toJson<String>(source),
      'locked': serializer.toJson<bool>(locked),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EpgMapping copyWith({
    String? channelId,
    String? providerId,
    String? epgChannelId,
    String? epgSourceId,
    double? confidence,
    String? source,
    bool? locked,
    DateTime? updatedAt,
  }) => EpgMapping(
    channelId: channelId ?? this.channelId,
    providerId: providerId ?? this.providerId,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    epgSourceId: epgSourceId ?? this.epgSourceId,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
    locked: locked ?? this.locked,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EpgMapping copyWithCompanion(EpgMappingsCompanion data) {
    return EpgMapping(
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      epgSourceId: data.epgSourceId.present
          ? data.epgSourceId.value
          : this.epgSourceId,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      source: data.source.present ? data.source.value : this.source,
      locked: data.locked.present ? data.locked.value : this.locked,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgMapping(')
          ..write('channelId: $channelId, ')
          ..write('providerId: $providerId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('epgSourceId: $epgSourceId, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('locked: $locked, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    channelId,
    providerId,
    epgChannelId,
    epgSourceId,
    confidence,
    source,
    locked,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgMapping &&
          other.channelId == this.channelId &&
          other.providerId == this.providerId &&
          other.epgChannelId == this.epgChannelId &&
          other.epgSourceId == this.epgSourceId &&
          other.confidence == this.confidence &&
          other.source == this.source &&
          other.locked == this.locked &&
          other.updatedAt == this.updatedAt);
}

class EpgMappingsCompanion extends UpdateCompanion<EpgMapping> {
  final Value<String> channelId;
  final Value<String> providerId;
  final Value<String> epgChannelId;
  final Value<String> epgSourceId;
  final Value<double> confidence;
  final Value<String> source;
  final Value<bool> locked;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EpgMappingsCompanion({
    this.channelId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.epgSourceId = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.locked = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgMappingsCompanion.insert({
    required String channelId,
    required String providerId,
    required String epgChannelId,
    required String epgSourceId,
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.locked = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : channelId = Value(channelId),
       providerId = Value(providerId),
       epgChannelId = Value(epgChannelId),
       epgSourceId = Value(epgSourceId);
  static Insertable<EpgMapping> custom({
    Expression<String>? channelId,
    Expression<String>? providerId,
    Expression<String>? epgChannelId,
    Expression<String>? epgSourceId,
    Expression<double>? confidence,
    Expression<String>? source,
    Expression<bool>? locked,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (channelId != null) 'channel_id': channelId,
      if (providerId != null) 'provider_id': providerId,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (epgSourceId != null) 'epg_source_id': epgSourceId,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (locked != null) 'locked': locked,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgMappingsCompanion copyWith({
    Value<String>? channelId,
    Value<String>? providerId,
    Value<String>? epgChannelId,
    Value<String>? epgSourceId,
    Value<double>? confidence,
    Value<String>? source,
    Value<bool>? locked,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EpgMappingsCompanion(
      channelId: channelId ?? this.channelId,
      providerId: providerId ?? this.providerId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      epgSourceId: epgSourceId ?? this.epgSourceId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      locked: locked ?? this.locked,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (epgSourceId.present) {
      map['epg_source_id'] = Variable<String>(epgSourceId.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgMappingsCompanion(')
          ..write('channelId: $channelId, ')
          ..write('providerId: $providerId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('epgSourceId: $epgSourceId, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('locked: $locked, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelGroupsTable extends ChannelGroups
    with TableInfo<$ChannelGroupsTable, ChannelGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder, hidden];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channel_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChannelGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
    );
  }

  @override
  $ChannelGroupsTable createAlias(String alias) {
    return $ChannelGroupsTable(attachedDatabase, alias);
  }
}

class ChannelGroup extends DataClass implements Insertable<ChannelGroup> {
  final String id;
  final String name;
  final int sortOrder;
  final bool hidden;
  const ChannelGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  ChannelGroupsCompanion toCompanion(bool nullToAbsent) {
    return ChannelGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      hidden: Value(hidden),
    );
  }

  factory ChannelGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  ChannelGroup copyWith({
    String? id,
    String? name,
    int? sortOrder,
    bool? hidden,
  }) => ChannelGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    hidden: hidden ?? this.hidden,
  );
  ChannelGroup copyWithCompanion(ChannelGroupsCompanion data) {
    return ChannelGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, hidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.hidden == this.hidden);
}

class ChannelGroupsCompanion extends UpdateCompanion<ChannelGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> hidden;
  final Value<int> rowid;
  const ChannelGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelGroupsCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<ChannelGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return ChannelGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      hidden: hidden ?? this.hidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('hidden: $hidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteListsTable extends FavoriteLists
    with TableInfo<$FavoriteListsTable, FavoriteList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('star'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, icon, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoriteListsTable createAlias(String alias) {
    return $FavoriteListsTable(attachedDatabase, alias);
  }
}

class FavoriteList extends DataClass implements Insertable<FavoriteList> {
  final String id;
  final String name;
  final String icon;
  final int sortOrder;
  final DateTime createdAt;
  const FavoriteList({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoriteListsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteListsCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteList(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteList copyWith({
    String? id,
    String? name,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
  }) => FavoriteList(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteList copyWithCompanion(FavoriteListsCompanion data) {
    return FavoriteList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteList(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, icon, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteList &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class FavoriteListsCompanion extends UpdateCompanion<FavoriteList> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoriteListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteListsCompanion.insert({
    required String id,
    required String name,
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<FavoriteList> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoriteListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteListChannelsTable extends FavoriteListChannels
    with TableInfo<$FavoriteListChannelsTable, FavoriteListChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteListChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorite_lists (id)',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [listId, channelId, sortOrder, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_list_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteListChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId, channelId};
  @override
  FavoriteListChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteListChannel(
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoriteListChannelsTable createAlias(String alias) {
    return $FavoriteListChannelsTable(attachedDatabase, alias);
  }
}

class FavoriteListChannel extends DataClass
    implements Insertable<FavoriteListChannel> {
  final String listId;
  final String channelId;
  final int sortOrder;
  final DateTime addedAt;
  const FavoriteListChannel({
    required this.listId,
    required this.channelId,
    required this.sortOrder,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<String>(listId);
    map['channel_id'] = Variable<String>(channelId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteListChannelsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteListChannelsCompanion(
      listId: Value(listId),
      channelId: Value(channelId),
      sortOrder: Value(sortOrder),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteListChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteListChannel(
      listId: serializer.fromJson<String>(json['listId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<String>(listId),
      'channelId': serializer.toJson<String>(channelId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteListChannel copyWith({
    String? listId,
    String? channelId,
    int? sortOrder,
    DateTime? addedAt,
  }) => FavoriteListChannel(
    listId: listId ?? this.listId,
    channelId: channelId ?? this.channelId,
    sortOrder: sortOrder ?? this.sortOrder,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteListChannel copyWithCompanion(FavoriteListChannelsCompanion data) {
    return FavoriteListChannel(
      listId: data.listId.present ? data.listId.value : this.listId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteListChannel(')
          ..write('listId: $listId, ')
          ..write('channelId: $channelId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(listId, channelId, sortOrder, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteListChannel &&
          other.listId == this.listId &&
          other.channelId == this.channelId &&
          other.sortOrder == this.sortOrder &&
          other.addedAt == this.addedAt);
}

class FavoriteListChannelsCompanion
    extends UpdateCompanion<FavoriteListChannel> {
  final Value<String> listId;
  final Value<String> channelId;
  final Value<int> sortOrder;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteListChannelsCompanion({
    this.listId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteListChannelsCompanion.insert({
    required String listId,
    required String channelId,
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       channelId = Value(channelId);
  static Insertable<FavoriteListChannel> custom({
    Expression<String>? listId,
    Expression<String>? channelId,
    Expression<int>? sortOrder,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (channelId != null) 'channel_id': channelId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteListChannelsCompanion copyWith({
    Value<String>? listId,
    Value<String>? channelId,
    Value<int>? sortOrder,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoriteListChannelsCompanion(
      listId: listId ?? this.listId,
      channelId: channelId ?? this.channelId,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteListChannelsCompanion(')
          ..write('listId: $listId, ')
          ..write('channelId: $channelId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgRemindersTable extends EpgReminders
    with TableInfo<$EpgRemindersTable, EpgReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _programmeTitleMeta = const VerificationMeta(
    'programmeTitle',
  );
  @override
  late final GeneratedColumn<String> programmeTitle = GeneratedColumn<String>(
    'programme_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programmeStartMeta = const VerificationMeta(
    'programmeStart',
  );
  @override
  late final GeneratedColumn<DateTime> programmeStart =
      GeneratedColumn<DateTime>(
        'programme_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _programmeStopMeta = const VerificationMeta(
    'programmeStop',
  );
  @override
  late final GeneratedColumn<DateTime> programmeStop =
      GeneratedColumn<DateTime>(
        'programme_stop',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _minutesBeforeMeta = const VerificationMeta(
    'minutesBefore',
  );
  @override
  late final GeneratedColumn<int> minutesBefore = GeneratedColumn<int>(
    'minutes_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _firedMeta = const VerificationMeta('fired');
  @override
  late final GeneratedColumn<bool> fired = GeneratedColumn<bool>(
    'fired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fired" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    epgChannelId,
    channelId,
    programmeTitle,
    programmeStart,
    programmeStop,
    minutesBefore,
    fired,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('programme_title')) {
      context.handle(
        _programmeTitleMeta,
        programmeTitle.isAcceptableOrUnknown(
          data['programme_title']!,
          _programmeTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeTitleMeta);
    }
    if (data.containsKey('programme_start')) {
      context.handle(
        _programmeStartMeta,
        programmeStart.isAcceptableOrUnknown(
          data['programme_start']!,
          _programmeStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeStartMeta);
    }
    if (data.containsKey('programme_stop')) {
      context.handle(
        _programmeStopMeta,
        programmeStop.isAcceptableOrUnknown(
          data['programme_stop']!,
          _programmeStopMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeStopMeta);
    }
    if (data.containsKey('minutes_before')) {
      context.handle(
        _minutesBeforeMeta,
        minutesBefore.isAcceptableOrUnknown(
          data['minutes_before']!,
          _minutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('fired')) {
      context.handle(
        _firedMeta,
        fired.isAcceptableOrUnknown(data['fired']!, _firedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      ),
      programmeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}programme_title'],
      )!,
      programmeStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}programme_start'],
      )!,
      programmeStop: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}programme_stop'],
      )!,
      minutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes_before'],
      )!,
      fired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fired'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EpgRemindersTable createAlias(String alias) {
    return $EpgRemindersTable(attachedDatabase, alias);
  }
}

class EpgReminder extends DataClass implements Insertable<EpgReminder> {
  final String id;
  final String epgChannelId;
  final String? channelId;
  final String programmeTitle;
  final DateTime programmeStart;
  final DateTime programmeStop;
  final int minutesBefore;
  final bool fired;
  final DateTime createdAt;
  const EpgReminder({
    required this.id,
    required this.epgChannelId,
    this.channelId,
    required this.programmeTitle,
    required this.programmeStart,
    required this.programmeStop,
    required this.minutesBefore,
    required this.fired,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<String>(channelId);
    }
    map['programme_title'] = Variable<String>(programmeTitle);
    map['programme_start'] = Variable<DateTime>(programmeStart);
    map['programme_stop'] = Variable<DateTime>(programmeStop);
    map['minutes_before'] = Variable<int>(minutesBefore);
    map['fired'] = Variable<bool>(fired);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EpgRemindersCompanion toCompanion(bool nullToAbsent) {
    return EpgRemindersCompanion(
      id: Value(id),
      epgChannelId: Value(epgChannelId),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      programmeTitle: Value(programmeTitle),
      programmeStart: Value(programmeStart),
      programmeStop: Value(programmeStop),
      minutesBefore: Value(minutesBefore),
      fired: Value(fired),
      createdAt: Value(createdAt),
    );
  }

  factory EpgReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgReminder(
      id: serializer.fromJson<String>(json['id']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      channelId: serializer.fromJson<String?>(json['channelId']),
      programmeTitle: serializer.fromJson<String>(json['programmeTitle']),
      programmeStart: serializer.fromJson<DateTime>(json['programmeStart']),
      programmeStop: serializer.fromJson<DateTime>(json['programmeStop']),
      minutesBefore: serializer.fromJson<int>(json['minutesBefore']),
      fired: serializer.fromJson<bool>(json['fired']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'channelId': serializer.toJson<String?>(channelId),
      'programmeTitle': serializer.toJson<String>(programmeTitle),
      'programmeStart': serializer.toJson<DateTime>(programmeStart),
      'programmeStop': serializer.toJson<DateTime>(programmeStop),
      'minutesBefore': serializer.toJson<int>(minutesBefore),
      'fired': serializer.toJson<bool>(fired),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EpgReminder copyWith({
    String? id,
    String? epgChannelId,
    Value<String?> channelId = const Value.absent(),
    String? programmeTitle,
    DateTime? programmeStart,
    DateTime? programmeStop,
    int? minutesBefore,
    bool? fired,
    DateTime? createdAt,
  }) => EpgReminder(
    id: id ?? this.id,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    channelId: channelId.present ? channelId.value : this.channelId,
    programmeTitle: programmeTitle ?? this.programmeTitle,
    programmeStart: programmeStart ?? this.programmeStart,
    programmeStop: programmeStop ?? this.programmeStop,
    minutesBefore: minutesBefore ?? this.minutesBefore,
    fired: fired ?? this.fired,
    createdAt: createdAt ?? this.createdAt,
  );
  EpgReminder copyWithCompanion(EpgRemindersCompanion data) {
    return EpgReminder(
      id: data.id.present ? data.id.value : this.id,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      programmeTitle: data.programmeTitle.present
          ? data.programmeTitle.value
          : this.programmeTitle,
      programmeStart: data.programmeStart.present
          ? data.programmeStart.value
          : this.programmeStart,
      programmeStop: data.programmeStop.present
          ? data.programmeStop.value
          : this.programmeStop,
      minutesBefore: data.minutesBefore.present
          ? data.minutesBefore.value
          : this.minutesBefore,
      fired: data.fired.present ? data.fired.value : this.fired,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgReminder(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('channelId: $channelId, ')
          ..write('programmeTitle: $programmeTitle, ')
          ..write('programmeStart: $programmeStart, ')
          ..write('programmeStop: $programmeStop, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('fired: $fired, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    epgChannelId,
    channelId,
    programmeTitle,
    programmeStart,
    programmeStop,
    minutesBefore,
    fired,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgReminder &&
          other.id == this.id &&
          other.epgChannelId == this.epgChannelId &&
          other.channelId == this.channelId &&
          other.programmeTitle == this.programmeTitle &&
          other.programmeStart == this.programmeStart &&
          other.programmeStop == this.programmeStop &&
          other.minutesBefore == this.minutesBefore &&
          other.fired == this.fired &&
          other.createdAt == this.createdAt);
}

class EpgRemindersCompanion extends UpdateCompanion<EpgReminder> {
  final Value<String> id;
  final Value<String> epgChannelId;
  final Value<String?> channelId;
  final Value<String> programmeTitle;
  final Value<DateTime> programmeStart;
  final Value<DateTime> programmeStop;
  final Value<int> minutesBefore;
  final Value<bool> fired;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EpgRemindersCompanion({
    this.id = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.programmeTitle = const Value.absent(),
    this.programmeStart = const Value.absent(),
    this.programmeStop = const Value.absent(),
    this.minutesBefore = const Value.absent(),
    this.fired = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgRemindersCompanion.insert({
    required String id,
    required String epgChannelId,
    this.channelId = const Value.absent(),
    required String programmeTitle,
    required DateTime programmeStart,
    required DateTime programmeStop,
    this.minutesBefore = const Value.absent(),
    this.fired = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       epgChannelId = Value(epgChannelId),
       programmeTitle = Value(programmeTitle),
       programmeStart = Value(programmeStart),
       programmeStop = Value(programmeStop);
  static Insertable<EpgReminder> custom({
    Expression<String>? id,
    Expression<String>? epgChannelId,
    Expression<String>? channelId,
    Expression<String>? programmeTitle,
    Expression<DateTime>? programmeStart,
    Expression<DateTime>? programmeStop,
    Expression<int>? minutesBefore,
    Expression<bool>? fired,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (channelId != null) 'channel_id': channelId,
      if (programmeTitle != null) 'programme_title': programmeTitle,
      if (programmeStart != null) 'programme_start': programmeStart,
      if (programmeStop != null) 'programme_stop': programmeStop,
      if (minutesBefore != null) 'minutes_before': minutesBefore,
      if (fired != null) 'fired': fired,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgRemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? epgChannelId,
    Value<String?>? channelId,
    Value<String>? programmeTitle,
    Value<DateTime>? programmeStart,
    Value<DateTime>? programmeStop,
    Value<int>? minutesBefore,
    Value<bool>? fired,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EpgRemindersCompanion(
      id: id ?? this.id,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      channelId: channelId ?? this.channelId,
      programmeTitle: programmeTitle ?? this.programmeTitle,
      programmeStart: programmeStart ?? this.programmeStart,
      programmeStop: programmeStop ?? this.programmeStop,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      fired: fired ?? this.fired,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (programmeTitle.present) {
      map['programme_title'] = Variable<String>(programmeTitle.value);
    }
    if (programmeStart.present) {
      map['programme_start'] = Variable<DateTime>(programmeStart.value);
    }
    if (programmeStop.present) {
      map['programme_stop'] = Variable<DateTime>(programmeStop.value);
    }
    if (minutesBefore.present) {
      map['minutes_before'] = Variable<int>(minutesBefore.value);
    }
    if (fired.present) {
      map['fired'] = Variable<bool>(fired.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgRemindersCompanion(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('channelId: $channelId, ')
          ..write('programmeTitle: $programmeTitle, ')
          ..write('programmeStart: $programmeStart, ')
          ..write('programmeStop: $programmeStop, ')
          ..write('minutesBefore: $minutesBefore, ')
          ..write('fired: $fired, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledRecordingsTable extends ScheduledRecordings
    with TableInfo<$ScheduledRecordingsTable, ScheduledRecording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledRecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _programmeTitleMeta = const VerificationMeta(
    'programmeTitle',
  );
  @override
  late final GeneratedColumn<String> programmeTitle = GeneratedColumn<String>(
    'programme_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programmeStartMeta = const VerificationMeta(
    'programmeStart',
  );
  @override
  late final GeneratedColumn<DateTime> programmeStart =
      GeneratedColumn<DateTime>(
        'programme_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _programmeStopMeta = const VerificationMeta(
    'programmeStop',
  );
  @override
  late final GeneratedColumn<DateTime> programmeStop =
      GeneratedColumn<DateTime>(
        'programme_stop',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    epgChannelId,
    channelId,
    programmeTitle,
    programmeStart,
    programmeStop,
    status,
    outputPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledRecording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('programme_title')) {
      context.handle(
        _programmeTitleMeta,
        programmeTitle.isAcceptableOrUnknown(
          data['programme_title']!,
          _programmeTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeTitleMeta);
    }
    if (data.containsKey('programme_start')) {
      context.handle(
        _programmeStartMeta,
        programmeStart.isAcceptableOrUnknown(
          data['programme_start']!,
          _programmeStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeStartMeta);
    }
    if (data.containsKey('programme_stop')) {
      context.handle(
        _programmeStopMeta,
        programmeStop.isAcceptableOrUnknown(
          data['programme_stop']!,
          _programmeStopMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeStopMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledRecording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledRecording(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      ),
      programmeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}programme_title'],
      )!,
      programmeStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}programme_start'],
      )!,
      programmeStop: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}programme_stop'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScheduledRecordingsTable createAlias(String alias) {
    return $ScheduledRecordingsTable(attachedDatabase, alias);
  }
}

class ScheduledRecording extends DataClass
    implements Insertable<ScheduledRecording> {
  final String id;
  final String epgChannelId;
  final String? channelId;
  final String programmeTitle;
  final DateTime programmeStart;
  final DateTime programmeStop;
  final String status;
  final String? outputPath;
  final DateTime createdAt;
  const ScheduledRecording({
    required this.id,
    required this.epgChannelId,
    this.channelId,
    required this.programmeTitle,
    required this.programmeStart,
    required this.programmeStop,
    required this.status,
    this.outputPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<String>(channelId);
    }
    map['programme_title'] = Variable<String>(programmeTitle);
    map['programme_start'] = Variable<DateTime>(programmeStart);
    map['programme_stop'] = Variable<DateTime>(programmeStop);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScheduledRecordingsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledRecordingsCompanion(
      id: Value(id),
      epgChannelId: Value(epgChannelId),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      programmeTitle: Value(programmeTitle),
      programmeStart: Value(programmeStart),
      programmeStop: Value(programmeStop),
      status: Value(status),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      createdAt: Value(createdAt),
    );
  }

  factory ScheduledRecording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledRecording(
      id: serializer.fromJson<String>(json['id']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      channelId: serializer.fromJson<String?>(json['channelId']),
      programmeTitle: serializer.fromJson<String>(json['programmeTitle']),
      programmeStart: serializer.fromJson<DateTime>(json['programmeStart']),
      programmeStop: serializer.fromJson<DateTime>(json['programmeStop']),
      status: serializer.fromJson<String>(json['status']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'channelId': serializer.toJson<String?>(channelId),
      'programmeTitle': serializer.toJson<String>(programmeTitle),
      'programmeStart': serializer.toJson<DateTime>(programmeStart),
      'programmeStop': serializer.toJson<DateTime>(programmeStop),
      'status': serializer.toJson<String>(status),
      'outputPath': serializer.toJson<String?>(outputPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ScheduledRecording copyWith({
    String? id,
    String? epgChannelId,
    Value<String?> channelId = const Value.absent(),
    String? programmeTitle,
    DateTime? programmeStart,
    DateTime? programmeStop,
    String? status,
    Value<String?> outputPath = const Value.absent(),
    DateTime? createdAt,
  }) => ScheduledRecording(
    id: id ?? this.id,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    channelId: channelId.present ? channelId.value : this.channelId,
    programmeTitle: programmeTitle ?? this.programmeTitle,
    programmeStart: programmeStart ?? this.programmeStart,
    programmeStop: programmeStop ?? this.programmeStop,
    status: status ?? this.status,
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    createdAt: createdAt ?? this.createdAt,
  );
  ScheduledRecording copyWithCompanion(ScheduledRecordingsCompanion data) {
    return ScheduledRecording(
      id: data.id.present ? data.id.value : this.id,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      programmeTitle: data.programmeTitle.present
          ? data.programmeTitle.value
          : this.programmeTitle,
      programmeStart: data.programmeStart.present
          ? data.programmeStart.value
          : this.programmeStart,
      programmeStop: data.programmeStop.present
          ? data.programmeStop.value
          : this.programmeStop,
      status: data.status.present ? data.status.value : this.status,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledRecording(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('channelId: $channelId, ')
          ..write('programmeTitle: $programmeTitle, ')
          ..write('programmeStart: $programmeStart, ')
          ..write('programmeStop: $programmeStop, ')
          ..write('status: $status, ')
          ..write('outputPath: $outputPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    epgChannelId,
    channelId,
    programmeTitle,
    programmeStart,
    programmeStop,
    status,
    outputPath,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledRecording &&
          other.id == this.id &&
          other.epgChannelId == this.epgChannelId &&
          other.channelId == this.channelId &&
          other.programmeTitle == this.programmeTitle &&
          other.programmeStart == this.programmeStart &&
          other.programmeStop == this.programmeStop &&
          other.status == this.status &&
          other.outputPath == this.outputPath &&
          other.createdAt == this.createdAt);
}

class ScheduledRecordingsCompanion extends UpdateCompanion<ScheduledRecording> {
  final Value<String> id;
  final Value<String> epgChannelId;
  final Value<String?> channelId;
  final Value<String> programmeTitle;
  final Value<DateTime> programmeStart;
  final Value<DateTime> programmeStop;
  final Value<String> status;
  final Value<String?> outputPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ScheduledRecordingsCompanion({
    this.id = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.programmeTitle = const Value.absent(),
    this.programmeStart = const Value.absent(),
    this.programmeStop = const Value.absent(),
    this.status = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduledRecordingsCompanion.insert({
    required String id,
    required String epgChannelId,
    this.channelId = const Value.absent(),
    required String programmeTitle,
    required DateTime programmeStart,
    required DateTime programmeStop,
    this.status = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       epgChannelId = Value(epgChannelId),
       programmeTitle = Value(programmeTitle),
       programmeStart = Value(programmeStart),
       programmeStop = Value(programmeStop);
  static Insertable<ScheduledRecording> custom({
    Expression<String>? id,
    Expression<String>? epgChannelId,
    Expression<String>? channelId,
    Expression<String>? programmeTitle,
    Expression<DateTime>? programmeStart,
    Expression<DateTime>? programmeStop,
    Expression<String>? status,
    Expression<String>? outputPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (channelId != null) 'channel_id': channelId,
      if (programmeTitle != null) 'programme_title': programmeTitle,
      if (programmeStart != null) 'programme_start': programmeStart,
      if (programmeStop != null) 'programme_stop': programmeStop,
      if (status != null) 'status': status,
      if (outputPath != null) 'output_path': outputPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduledRecordingsCompanion copyWith({
    Value<String>? id,
    Value<String>? epgChannelId,
    Value<String?>? channelId,
    Value<String>? programmeTitle,
    Value<DateTime>? programmeStart,
    Value<DateTime>? programmeStop,
    Value<String>? status,
    Value<String?>? outputPath,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ScheduledRecordingsCompanion(
      id: id ?? this.id,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      channelId: channelId ?? this.channelId,
      programmeTitle: programmeTitle ?? this.programmeTitle,
      programmeStart: programmeStart ?? this.programmeStart,
      programmeStop: programmeStop ?? this.programmeStop,
      status: status ?? this.status,
      outputPath: outputPath ?? this.outputPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (programmeTitle.present) {
      map['programme_title'] = Variable<String>(programmeTitle.value);
    }
    if (programmeStart.present) {
      map['programme_start'] = Variable<DateTime>(programmeStart.value);
    }
    if (programmeStop.present) {
      map['programme_stop'] = Variable<DateTime>(programmeStop.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledRecordingsCompanion(')
          ..write('id: $id, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('channelId: $channelId, ')
          ..write('programmeTitle: $programmeTitle, ')
          ..write('programmeStart: $programmeStart, ')
          ..write('programmeStop: $programmeStop, ')
          ..write('status: $status, ')
          ..write('outputPath: $outputPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FailoverGroupsTable extends FailoverGroups
    with TableInfo<$FailoverGroupsTable, FailoverGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FailoverGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'failover_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<FailoverGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FailoverGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FailoverGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FailoverGroupsTable createAlias(String alias) {
    return $FailoverGroupsTable(attachedDatabase, alias);
  }
}

class FailoverGroup extends DataClass implements Insertable<FailoverGroup> {
  final int id;
  final String name;
  final DateTime createdAt;
  const FailoverGroup({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FailoverGroupsCompanion toCompanion(bool nullToAbsent) {
    return FailoverGroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory FailoverGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FailoverGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FailoverGroup copyWith({int? id, String? name, DateTime? createdAt}) =>
      FailoverGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  FailoverGroup copyWithCompanion(FailoverGroupsCompanion data) {
    return FailoverGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FailoverGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FailoverGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class FailoverGroupsCompanion extends UpdateCompanion<FailoverGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const FailoverGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FailoverGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<FailoverGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FailoverGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return FailoverGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FailoverGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FailoverGroupChannelsTable extends FailoverGroupChannels
    with TableInfo<$FailoverGroupChannelsTable, FailoverGroupChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FailoverGroupChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES failover_groups (id)',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id)',
    ),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, channelId, priority];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'failover_group_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<FailoverGroupChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, channelId};
  @override
  FailoverGroupChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FailoverGroupChannel(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
    );
  }

  @override
  $FailoverGroupChannelsTable createAlias(String alias) {
    return $FailoverGroupChannelsTable(attachedDatabase, alias);
  }
}

class FailoverGroupChannel extends DataClass
    implements Insertable<FailoverGroupChannel> {
  final int groupId;
  final String channelId;
  final int priority;
  const FailoverGroupChannel({
    required this.groupId,
    required this.channelId,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<int>(groupId);
    map['channel_id'] = Variable<String>(channelId);
    map['priority'] = Variable<int>(priority);
    return map;
  }

  FailoverGroupChannelsCompanion toCompanion(bool nullToAbsent) {
    return FailoverGroupChannelsCompanion(
      groupId: Value(groupId),
      channelId: Value(channelId),
      priority: Value(priority),
    );
  }

  factory FailoverGroupChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FailoverGroupChannel(
      groupId: serializer.fromJson<int>(json['groupId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<int>(groupId),
      'channelId': serializer.toJson<String>(channelId),
      'priority': serializer.toJson<int>(priority),
    };
  }

  FailoverGroupChannel copyWith({
    int? groupId,
    String? channelId,
    int? priority,
  }) => FailoverGroupChannel(
    groupId: groupId ?? this.groupId,
    channelId: channelId ?? this.channelId,
    priority: priority ?? this.priority,
  );
  FailoverGroupChannel copyWithCompanion(FailoverGroupChannelsCompanion data) {
    return FailoverGroupChannel(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FailoverGroupChannel(')
          ..write('groupId: $groupId, ')
          ..write('channelId: $channelId, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, channelId, priority);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FailoverGroupChannel &&
          other.groupId == this.groupId &&
          other.channelId == this.channelId &&
          other.priority == this.priority);
}

class FailoverGroupChannelsCompanion
    extends UpdateCompanion<FailoverGroupChannel> {
  final Value<int> groupId;
  final Value<String> channelId;
  final Value<int> priority;
  final Value<int> rowid;
  const FailoverGroupChannelsCompanion({
    this.groupId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FailoverGroupChannelsCompanion.insert({
    required int groupId,
    required String channelId,
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       channelId = Value(channelId);
  static Insertable<FailoverGroupChannel> custom({
    Expression<int>? groupId,
    Expression<String>? channelId,
    Expression<int>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (channelId != null) 'channel_id': channelId,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FailoverGroupChannelsCompanion copyWith({
    Value<int>? groupId,
    Value<String>? channelId,
    Value<int>? priority,
    Value<int>? rowid,
  }) {
    return FailoverGroupChannelsCompanion(
      groupId: groupId ?? this.groupId,
      channelId: channelId ?? this.channelId,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FailoverGroupChannelsCompanion(')
          ..write('groupId: $groupId, ')
          ..write('channelId: $channelId, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProvidersTable providers = $ProvidersTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $EpgSourcesTable epgSources = $EpgSourcesTable(this);
  late final $EpgChannelsTable epgChannels = $EpgChannelsTable(this);
  late final $EpgProgrammesTable epgProgrammes = $EpgProgrammesTable(this);
  late final $EpgMappingsTable epgMappings = $EpgMappingsTable(this);
  late final $ChannelGroupsTable channelGroups = $ChannelGroupsTable(this);
  late final $FavoriteListsTable favoriteLists = $FavoriteListsTable(this);
  late final $FavoriteListChannelsTable favoriteListChannels =
      $FavoriteListChannelsTable(this);
  late final $EpgRemindersTable epgReminders = $EpgRemindersTable(this);
  late final $ScheduledRecordingsTable scheduledRecordings =
      $ScheduledRecordingsTable(this);
  late final $FailoverGroupsTable failoverGroups = $FailoverGroupsTable(this);
  late final $FailoverGroupChannelsTable failoverGroupChannels =
      $FailoverGroupChannelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    providers,
    channels,
    epgSources,
    epgChannels,
    epgProgrammes,
    epgMappings,
    channelGroups,
    favoriteLists,
    favoriteListChannels,
    epgReminders,
    scheduledRecordings,
    failoverGroups,
    failoverGroupChannels,
  ];
}

typedef $$ProvidersTableCreateCompanionBuilder =
    ProvidersCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> url,
      Value<String?> username,
      Value<String?> password,
      Value<int> sortOrder,
      Value<bool> enabled,
      Value<DateTime?> lastRefresh,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ProvidersTableUpdateCompanionBuilder =
    ProvidersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> url,
      Value<String?> username,
      Value<String?> password,
      Value<int> sortOrder,
      Value<bool> enabled,
      Value<DateTime?> lastRefresh,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProvidersTableReferences
    extends BaseReferences<_$AppDatabase, $ProvidersTable, Provider> {
  $$ProvidersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChannelsTable, List<Channel>> _channelsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: $_aliasNameGenerator(db.providers.id, db.channels.providerId),
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.providerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProvidersTableFilterComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProvidersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProvidersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProvidersTable> {
  $$ProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.providerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProvidersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProvidersTable,
          Provider,
          $$ProvidersTableFilterComposer,
          $$ProvidersTableOrderingComposer,
          $$ProvidersTableAnnotationComposer,
          $$ProvidersTableCreateCompanionBuilder,
          $$ProvidersTableUpdateCompanionBuilder,
          (Provider, $$ProvidersTableReferences),
          Provider,
          PrefetchHooks Function({bool channelsRefs})
        > {
  $$ProvidersTableTableManager(_$AppDatabase db, $ProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> password = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> lastRefresh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion(
                id: id,
                name: name,
                type: type,
                url: url,
                username: username,
                password: password,
                sortOrder: sortOrder,
                enabled: enabled,
                lastRefresh: lastRefresh,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> url = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> password = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> lastRefresh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProvidersCompanion.insert(
                id: id,
                name: name,
                type: type,
                url: url,
                username: username,
                password: password,
                sortOrder: sortOrder,
                enabled: enabled,
                lastRefresh: lastRefresh,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProvidersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({channelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (channelsRefs) db.channels],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (channelsRefs)
                    await $_getPrefetchedData<
                      Provider,
                      $ProvidersTable,
                      Channel
                    >(
                      currentTable: table,
                      referencedTable: $$ProvidersTableReferences
                          ._channelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProvidersTableReferences(
                            db,
                            table,
                            p0,
                          ).channelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.providerId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProvidersTable,
      Provider,
      $$ProvidersTableFilterComposer,
      $$ProvidersTableOrderingComposer,
      $$ProvidersTableAnnotationComposer,
      $$ProvidersTableCreateCompanionBuilder,
      $$ProvidersTableUpdateCompanionBuilder,
      (Provider, $$ProvidersTableReferences),
      Provider,
      PrefetchHooks Function({bool channelsRefs})
    >;
typedef $$ChannelsTableCreateCompanionBuilder =
    ChannelsCompanion Function({
      required String id,
      required String providerId,
      required String name,
      Value<String?> tvgId,
      Value<String?> tvgName,
      Value<String?> tvgLogo,
      Value<String?> groupTitle,
      Value<int?> channelNumber,
      required String streamUrl,
      Value<String> streamType,
      Value<bool> favorite,
      Value<bool> hidden,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$ChannelsTableUpdateCompanionBuilder =
    ChannelsCompanion Function({
      Value<String> id,
      Value<String> providerId,
      Value<String> name,
      Value<String?> tvgId,
      Value<String?> tvgName,
      Value<String?> tvgLogo,
      Value<String?> groupTitle,
      Value<int?> channelNumber,
      Value<String> streamUrl,
      Value<String> streamType,
      Value<bool> favorite,
      Value<bool> hidden,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$ChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $ChannelsTable, Channel> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProvidersTable _providerIdTable(_$AppDatabase db) =>
      db.providers.createAlias(
        $_aliasNameGenerator(db.channels.providerId, db.providers.id),
      );

  $$ProvidersTableProcessedTableManager get providerId {
    final $_column = $_itemColumn<String>('provider_id')!;

    final manager = $$ProvidersTableTableManager(
      $_db,
      $_db.providers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EpgMappingsTable, List<EpgMapping>>
  _epgMappingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgMappings,
    aliasName: $_aliasNameGenerator(db.channels.id, db.epgMappings.channelId),
  );

  $$EpgMappingsTableProcessedTableManager get epgMappingsRefs {
    final manager = $$EpgMappingsTableTableManager(
      $_db,
      $_db.epgMappings,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgMappingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FavoriteListChannelsTable,
    List<FavoriteListChannel>
  >
  _favoriteListChannelsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.favoriteListChannels,
        aliasName: $_aliasNameGenerator(
          db.channels.id,
          db.favoriteListChannels.channelId,
        ),
      );

  $$FavoriteListChannelsTableProcessedTableManager
  get favoriteListChannelsRefs {
    final manager = $$FavoriteListChannelsTableTableManager(
      $_db,
      $_db.favoriteListChannels,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteListChannelsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FailoverGroupChannelsTable,
    List<FailoverGroupChannel>
  >
  _failoverGroupChannelsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.failoverGroupChannels,
        aliasName: $_aliasNameGenerator(
          db.channels.id,
          db.failoverGroupChannels.channelId,
        ),
      );

  $$FailoverGroupChannelsTableProcessedTableManager
  get failoverGroupChannelsRefs {
    final manager = $$FailoverGroupChannelsTableTableManager(
      $_db,
      $_db.failoverGroupChannels,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _failoverGroupChannelsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tvgName => $composableBuilder(
    column: $table.tvgName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tvgLogo => $composableBuilder(
    column: $table.tvgLogo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamType => $composableBuilder(
    column: $table.streamType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ProvidersTableFilterComposer get providerId {
    final $$ProvidersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableFilterComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> epgMappingsRefs(
    Expression<bool> Function($$EpgMappingsTableFilterComposer f) f,
  ) {
    final $$EpgMappingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableFilterComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoriteListChannelsRefs(
    Expression<bool> Function($$FavoriteListChannelsTableFilterComposer f) f,
  ) {
    final $$FavoriteListChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteListChannels,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteListChannelsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteListChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> failoverGroupChannelsRefs(
    Expression<bool> Function($$FailoverGroupChannelsTableFilterComposer f) f,
  ) {
    final $$FailoverGroupChannelsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.failoverGroupChannels,
          getReferencedColumn: (t) => t.channelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FailoverGroupChannelsTableFilterComposer(
                $db: $db,
                $table: $db.failoverGroupChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tvgName => $composableBuilder(
    column: $table.tvgName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tvgLogo => $composableBuilder(
    column: $table.tvgLogo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamType => $composableBuilder(
    column: $table.streamType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProvidersTableOrderingComposer get providerId {
    final $$ProvidersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableOrderingComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tvgId =>
      $composableBuilder(column: $table.tvgId, builder: (column) => column);

  GeneratedColumn<String> get tvgName =>
      $composableBuilder(column: $table.tvgName, builder: (column) => column);

  GeneratedColumn<String> get tvgLogo =>
      $composableBuilder(column: $table.tvgLogo, builder: (column) => column);

  GeneratedColumn<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channelNumber => $composableBuilder(
    column: $table.channelNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get streamType => $composableBuilder(
    column: $table.streamType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ProvidersTableAnnotationComposer get providerId {
    final $$ProvidersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerId,
      referencedTable: $db.providers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProvidersTableAnnotationComposer(
            $db: $db,
            $table: $db.providers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> epgMappingsRefs<T extends Object>(
    Expression<T> Function($$EpgMappingsTableAnnotationComposer a) f,
  ) {
    final $$EpgMappingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoriteListChannelsRefs<T extends Object>(
    Expression<T> Function($$FavoriteListChannelsTableAnnotationComposer a) f,
  ) {
    final $$FavoriteListChannelsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteListChannels,
          getReferencedColumn: (t) => t.channelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteListChannelsTableAnnotationComposer(
                $db: $db,
                $table: $db.favoriteListChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> failoverGroupChannelsRefs<T extends Object>(
    Expression<T> Function($$FailoverGroupChannelsTableAnnotationComposer a) f,
  ) {
    final $$FailoverGroupChannelsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.failoverGroupChannels,
          getReferencedColumn: (t) => t.channelId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FailoverGroupChannelsTableAnnotationComposer(
                $db: $db,
                $table: $db.failoverGroupChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          Channel,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (Channel, $$ChannelsTableReferences),
          Channel,
          PrefetchHooks Function({
            bool providerId,
            bool epgMappingsRefs,
            bool favoriteListChannelsRefs,
            bool failoverGroupChannelsRefs,
          })
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> tvgId = const Value.absent(),
                Value<String?> tvgName = const Value.absent(),
                Value<String?> tvgLogo = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                Value<int?> channelNumber = const Value.absent(),
                Value<String> streamUrl = const Value.absent(),
                Value<String> streamType = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion(
                id: id,
                providerId: providerId,
                name: name,
                tvgId: tvgId,
                tvgName: tvgName,
                tvgLogo: tvgLogo,
                groupTitle: groupTitle,
                channelNumber: channelNumber,
                streamUrl: streamUrl,
                streamType: streamType,
                favorite: favorite,
                hidden: hidden,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String providerId,
                required String name,
                Value<String?> tvgId = const Value.absent(),
                Value<String?> tvgName = const Value.absent(),
                Value<String?> tvgLogo = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                Value<int?> channelNumber = const Value.absent(),
                required String streamUrl,
                Value<String> streamType = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion.insert(
                id: id,
                providerId: providerId,
                name: name,
                tvgId: tvgId,
                tvgName: tvgName,
                tvgLogo: tvgLogo,
                groupTitle: groupTitle,
                channelNumber: channelNumber,
                streamUrl: streamUrl,
                streamType: streamType,
                favorite: favorite,
                hidden: hidden,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                providerId = false,
                epgMappingsRefs = false,
                favoriteListChannelsRefs = false,
                failoverGroupChannelsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (epgMappingsRefs) db.epgMappings,
                    if (favoriteListChannelsRefs) db.favoriteListChannels,
                    if (failoverGroupChannelsRefs) db.failoverGroupChannels,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (providerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.providerId,
                                    referencedTable: $$ChannelsTableReferences
                                        ._providerIdTable(db),
                                    referencedColumn: $$ChannelsTableReferences
                                        ._providerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (epgMappingsRefs)
                        await $_getPrefetchedData<
                          Channel,
                          $ChannelsTable,
                          EpgMapping
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._epgMappingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).epgMappingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoriteListChannelsRefs)
                        await $_getPrefetchedData<
                          Channel,
                          $ChannelsTable,
                          FavoriteListChannel
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._favoriteListChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteListChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (failoverGroupChannelsRefs)
                        await $_getPrefetchedData<
                          Channel,
                          $ChannelsTable,
                          FailoverGroupChannel
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._failoverGroupChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).failoverGroupChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      Channel,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (Channel, $$ChannelsTableReferences),
      Channel,
      PrefetchHooks Function({
        bool providerId,
        bool epgMappingsRefs,
        bool favoriteListChannelsRefs,
        bool failoverGroupChannelsRefs,
      })
    >;
typedef $$EpgSourcesTableCreateCompanionBuilder =
    EpgSourcesCompanion Function({
      required String id,
      required String name,
      required String url,
      Value<bool> enabled,
      Value<int> refreshIntervalHours,
      Value<DateTime?> lastRefresh,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$EpgSourcesTableUpdateCompanionBuilder =
    EpgSourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> url,
      Value<bool> enabled,
      Value<int> refreshIntervalHours,
      Value<DateTime?> lastRefresh,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$EpgSourcesTableReferences
    extends BaseReferences<_$AppDatabase, $EpgSourcesTable, EpgSource> {
  $$EpgSourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpgChannelsTable, List<EpgChannel>>
  _epgChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgChannels,
    aliasName: $_aliasNameGenerator(db.epgSources.id, db.epgChannels.sourceId),
  );

  $$EpgChannelsTableProcessedTableManager get epgChannelsRefs {
    final manager = $$EpgChannelsTableTableManager(
      $_db,
      $_db.epgChannels,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgProgrammesTable, List<EpgProgramme>>
  _epgProgrammesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgProgrammes,
    aliasName: $_aliasNameGenerator(
      db.epgSources.id,
      db.epgProgrammes.sourceId,
    ),
  );

  $$EpgProgrammesTableProcessedTableManager get epgProgrammesRefs {
    final manager = $$EpgProgrammesTableTableManager(
      $_db,
      $_db.epgProgrammes,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgProgrammesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgMappingsTable, List<EpgMapping>>
  _epgMappingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgMappings,
    aliasName: $_aliasNameGenerator(
      db.epgSources.id,
      db.epgMappings.epgSourceId,
    ),
  );

  $$EpgMappingsTableProcessedTableManager get epgMappingsRefs {
    final manager = $$EpgMappingsTableTableManager(
      $_db,
      $_db.epgMappings,
    ).filter((f) => f.epgSourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgMappingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EpgSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $EpgSourcesTable> {
  $$EpgSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refreshIntervalHours => $composableBuilder(
    column: $table.refreshIntervalHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> epgChannelsRefs(
    Expression<bool> Function($$EpgChannelsTableFilterComposer f) f,
  ) {
    final $$EpgChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableFilterComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgProgrammesRefs(
    Expression<bool> Function($$EpgProgrammesTableFilterComposer f) f,
  ) {
    final $$EpgProgrammesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgProgrammes,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgProgrammesTableFilterComposer(
            $db: $db,
            $table: $db.epgProgrammes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgMappingsRefs(
    Expression<bool> Function($$EpgMappingsTableFilterComposer f) f,
  ) {
    final $$EpgMappingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.epgSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableFilterComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EpgSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgSourcesTable> {
  $$EpgSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshIntervalHours => $composableBuilder(
    column: $table.refreshIntervalHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgSourcesTable> {
  $$EpgSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get refreshIntervalHours => $composableBuilder(
    column: $table.refreshIntervalHours,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRefresh => $composableBuilder(
    column: $table.lastRefresh,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> epgChannelsRefs<T extends Object>(
    Expression<T> Function($$EpgChannelsTableAnnotationComposer a) f,
  ) {
    final $$EpgChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgProgrammesRefs<T extends Object>(
    Expression<T> Function($$EpgProgrammesTableAnnotationComposer a) f,
  ) {
    final $$EpgProgrammesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgProgrammes,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgProgrammesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgProgrammes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgMappingsRefs<T extends Object>(
    Expression<T> Function($$EpgMappingsTableAnnotationComposer a) f,
  ) {
    final $$EpgMappingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.epgSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EpgSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgSourcesTable,
          EpgSource,
          $$EpgSourcesTableFilterComposer,
          $$EpgSourcesTableOrderingComposer,
          $$EpgSourcesTableAnnotationComposer,
          $$EpgSourcesTableCreateCompanionBuilder,
          $$EpgSourcesTableUpdateCompanionBuilder,
          (EpgSource, $$EpgSourcesTableReferences),
          EpgSource,
          PrefetchHooks Function({
            bool epgChannelsRefs,
            bool epgProgrammesRefs,
            bool epgMappingsRefs,
          })
        > {
  $$EpgSourcesTableTableManager(_$AppDatabase db, $EpgSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> refreshIntervalHours = const Value.absent(),
                Value<DateTime?> lastRefresh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgSourcesCompanion(
                id: id,
                name: name,
                url: url,
                enabled: enabled,
                refreshIntervalHours: refreshIntervalHours,
                lastRefresh: lastRefresh,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String url,
                Value<bool> enabled = const Value.absent(),
                Value<int> refreshIntervalHours = const Value.absent(),
                Value<DateTime?> lastRefresh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgSourcesCompanion.insert(
                id: id,
                name: name,
                url: url,
                enabled: enabled,
                refreshIntervalHours: refreshIntervalHours,
                lastRefresh: lastRefresh,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpgSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                epgChannelsRefs = false,
                epgProgrammesRefs = false,
                epgMappingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (epgChannelsRefs) db.epgChannels,
                    if (epgProgrammesRefs) db.epgProgrammes,
                    if (epgMappingsRefs) db.epgMappings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (epgChannelsRefs)
                        await $_getPrefetchedData<
                          EpgSource,
                          $EpgSourcesTable,
                          EpgChannel
                        >(
                          currentTable: table,
                          referencedTable: $$EpgSourcesTableReferences
                              ._epgChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpgSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgProgrammesRefs)
                        await $_getPrefetchedData<
                          EpgSource,
                          $EpgSourcesTable,
                          EpgProgramme
                        >(
                          currentTable: table,
                          referencedTable: $$EpgSourcesTableReferences
                              ._epgProgrammesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpgSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgProgrammesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgMappingsRefs)
                        await $_getPrefetchedData<
                          EpgSource,
                          $EpgSourcesTable,
                          EpgMapping
                        >(
                          currentTable: table,
                          referencedTable: $$EpgSourcesTableReferences
                              ._epgMappingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpgSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgMappingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.epgSourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EpgSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgSourcesTable,
      EpgSource,
      $$EpgSourcesTableFilterComposer,
      $$EpgSourcesTableOrderingComposer,
      $$EpgSourcesTableAnnotationComposer,
      $$EpgSourcesTableCreateCompanionBuilder,
      $$EpgSourcesTableUpdateCompanionBuilder,
      (EpgSource, $$EpgSourcesTableReferences),
      EpgSource,
      PrefetchHooks Function({
        bool epgChannelsRefs,
        bool epgProgrammesRefs,
        bool epgMappingsRefs,
      })
    >;
typedef $$EpgChannelsTableCreateCompanionBuilder =
    EpgChannelsCompanion Function({
      required String id,
      required String sourceId,
      required String channelId,
      required String displayName,
      Value<String?> iconUrl,
      Value<int> rowid,
    });
typedef $$EpgChannelsTableUpdateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> channelId,
      Value<String> displayName,
      Value<String?> iconUrl,
      Value<int> rowid,
    });

final class $$EpgChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgChannelsTable, EpgChannel> {
  $$EpgChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EpgSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.epgSources.createAlias(
        $_aliasNameGenerator(db.epgChannels.sourceId, db.epgSources.id),
      );

  $$EpgSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$EpgSourcesTableTableManager(
      $_db,
      $_db.epgSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$EpgSourcesTableFilterComposer get sourceId {
    final $$EpgSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableFilterComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpgSourcesTableOrderingComposer get sourceId {
    final $$EpgSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  $$EpgSourcesTableAnnotationComposer get sourceId {
    final $$EpgSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgChannelsTable,
          EpgChannel,
          $$EpgChannelsTableFilterComposer,
          $$EpgChannelsTableOrderingComposer,
          $$EpgChannelsTableAnnotationComposer,
          $$EpgChannelsTableCreateCompanionBuilder,
          $$EpgChannelsTableUpdateCompanionBuilder,
          (EpgChannel, $$EpgChannelsTableReferences),
          EpgChannel,
          PrefetchHooks Function({bool sourceId})
        > {
  $$EpgChannelsTableTableManager(_$AppDatabase db, $EpgChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion(
                id: id,
                sourceId: sourceId,
                channelId: channelId,
                displayName: displayName,
                iconUrl: iconUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String channelId,
                required String displayName,
                Value<String?> iconUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgChannelsCompanion.insert(
                id: id,
                sourceId: sourceId,
                channelId: channelId,
                displayName: displayName,
                iconUrl: iconUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpgChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$EpgChannelsTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn: $$EpgChannelsTableReferences
                                    ._sourceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgChannelsTable,
      EpgChannel,
      $$EpgChannelsTableFilterComposer,
      $$EpgChannelsTableOrderingComposer,
      $$EpgChannelsTableAnnotationComposer,
      $$EpgChannelsTableCreateCompanionBuilder,
      $$EpgChannelsTableUpdateCompanionBuilder,
      (EpgChannel, $$EpgChannelsTableReferences),
      EpgChannel,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$EpgProgrammesTableCreateCompanionBuilder =
    EpgProgrammesCompanion Function({
      Value<int> id,
      required String epgChannelId,
      required String sourceId,
      required String title,
      Value<String?> description,
      Value<String?> subtitle,
      Value<String?> episodeNum,
      Value<String?> category,
      required DateTime start,
      required DateTime stop,
    });
typedef $$EpgProgrammesTableUpdateCompanionBuilder =
    EpgProgrammesCompanion Function({
      Value<int> id,
      Value<String> epgChannelId,
      Value<String> sourceId,
      Value<String> title,
      Value<String?> description,
      Value<String?> subtitle,
      Value<String?> episodeNum,
      Value<String?> category,
      Value<DateTime> start,
      Value<DateTime> stop,
    });

final class $$EpgProgrammesTableReferences
    extends BaseReferences<_$AppDatabase, $EpgProgrammesTable, EpgProgramme> {
  $$EpgProgrammesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpgSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.epgSources.createAlias(
        $_aliasNameGenerator(db.epgProgrammes.sourceId, db.epgSources.id),
      );

  $$EpgSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$EpgSourcesTableTableManager(
      $_db,
      $_db.epgSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgProgrammesTableFilterComposer
    extends Composer<_$AppDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnFilters(column),
  );

  $$EpgSourcesTableFilterComposer get sourceId {
    final $$EpgSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableFilterComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgrammesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpgSourcesTableOrderingComposer get sourceId {
    final $$EpgSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgrammesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgProgrammesTable> {
  $$EpgProgrammesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  $$EpgSourcesTableAnnotationComposer get sourceId {
    final $$EpgSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgrammesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgProgrammesTable,
          EpgProgramme,
          $$EpgProgrammesTableFilterComposer,
          $$EpgProgrammesTableOrderingComposer,
          $$EpgProgrammesTableAnnotationComposer,
          $$EpgProgrammesTableCreateCompanionBuilder,
          $$EpgProgrammesTableUpdateCompanionBuilder,
          (EpgProgramme, $$EpgProgrammesTableReferences),
          EpgProgramme,
          PrefetchHooks Function({bool sourceId})
        > {
  $$EpgProgrammesTableTableManager(_$AppDatabase db, $EpgProgrammesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgrammesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgrammesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgrammesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> episodeNum = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<DateTime> stop = const Value.absent(),
              }) => EpgProgrammesCompanion(
                id: id,
                epgChannelId: epgChannelId,
                sourceId: sourceId,
                title: title,
                description: description,
                subtitle: subtitle,
                episodeNum: episodeNum,
                category: category,
                start: start,
                stop: stop,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String epgChannelId,
                required String sourceId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> episodeNum = const Value.absent(),
                Value<String?> category = const Value.absent(),
                required DateTime start,
                required DateTime stop,
              }) => EpgProgrammesCompanion.insert(
                id: id,
                epgChannelId: epgChannelId,
                sourceId: sourceId,
                title: title,
                description: description,
                subtitle: subtitle,
                episodeNum: episodeNum,
                category: category,
                start: start,
                stop: stop,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpgProgrammesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable: $$EpgProgrammesTableReferences
                                    ._sourceIdTable(db),
                                referencedColumn: $$EpgProgrammesTableReferences
                                    ._sourceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgProgrammesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgProgrammesTable,
      EpgProgramme,
      $$EpgProgrammesTableFilterComposer,
      $$EpgProgrammesTableOrderingComposer,
      $$EpgProgrammesTableAnnotationComposer,
      $$EpgProgrammesTableCreateCompanionBuilder,
      $$EpgProgrammesTableUpdateCompanionBuilder,
      (EpgProgramme, $$EpgProgrammesTableReferences),
      EpgProgramme,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$EpgMappingsTableCreateCompanionBuilder =
    EpgMappingsCompanion Function({
      required String channelId,
      required String providerId,
      required String epgChannelId,
      required String epgSourceId,
      Value<double> confidence,
      Value<String> source,
      Value<bool> locked,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$EpgMappingsTableUpdateCompanionBuilder =
    EpgMappingsCompanion Function({
      Value<String> channelId,
      Value<String> providerId,
      Value<String> epgChannelId,
      Value<String> epgSourceId,
      Value<double> confidence,
      Value<String> source,
      Value<bool> locked,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$EpgMappingsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgMappingsTable, EpgMapping> {
  $$EpgMappingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChannelsTable _channelIdTable(_$AppDatabase db) =>
      db.channels.createAlias(
        $_aliasNameGenerator(db.epgMappings.channelId, db.channels.id),
      );

  $$ChannelsTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<String>('channel_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EpgSourcesTable _epgSourceIdTable(_$AppDatabase db) =>
      db.epgSources.createAlias(
        $_aliasNameGenerator(db.epgMappings.epgSourceId, db.epgSources.id),
      );

  $$EpgSourcesTableProcessedTableManager get epgSourceId {
    final $_column = $_itemColumn<String>('epg_source_id')!;

    final manager = $$EpgSourcesTableTableManager(
      $_db,
      $_db.epgSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_epgSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChannelsTableFilterComposer get channelId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpgSourcesTableFilterComposer get epgSourceId {
    final $$EpgSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.epgSourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableFilterComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChannelsTableOrderingComposer get channelId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpgSourcesTableOrderingComposer get epgSourceId {
    final $$EpgSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.epgSourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChannelsTableAnnotationComposer get channelId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EpgSourcesTableAnnotationComposer get epgSourceId {
    final $$EpgSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.epgSourceId,
      referencedTable: $db.epgSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgMappingsTable,
          EpgMapping,
          $$EpgMappingsTableFilterComposer,
          $$EpgMappingsTableOrderingComposer,
          $$EpgMappingsTableAnnotationComposer,
          $$EpgMappingsTableCreateCompanionBuilder,
          $$EpgMappingsTableUpdateCompanionBuilder,
          (EpgMapping, $$EpgMappingsTableReferences),
          EpgMapping,
          PrefetchHooks Function({bool channelId, bool epgSourceId})
        > {
  $$EpgMappingsTableTableManager(_$AppDatabase db, $EpgMappingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> channelId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<String> epgSourceId = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgMappingsCompanion(
                channelId: channelId,
                providerId: providerId,
                epgChannelId: epgChannelId,
                epgSourceId: epgSourceId,
                confidence: confidence,
                source: source,
                locked: locked,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String channelId,
                required String providerId,
                required String epgChannelId,
                required String epgSourceId,
                Value<double> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgMappingsCompanion.insert(
                channelId: channelId,
                providerId: providerId,
                epgChannelId: epgChannelId,
                epgSourceId: epgSourceId,
                confidence: confidence,
                source: source,
                locked: locked,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpgMappingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({channelId = false, epgSourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (channelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.channelId,
                                referencedTable: $$EpgMappingsTableReferences
                                    ._channelIdTable(db),
                                referencedColumn: $$EpgMappingsTableReferences
                                    ._channelIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (epgSourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.epgSourceId,
                                referencedTable: $$EpgMappingsTableReferences
                                    ._epgSourceIdTable(db),
                                referencedColumn: $$EpgMappingsTableReferences
                                    ._epgSourceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgMappingsTable,
      EpgMapping,
      $$EpgMappingsTableFilterComposer,
      $$EpgMappingsTableOrderingComposer,
      $$EpgMappingsTableAnnotationComposer,
      $$EpgMappingsTableCreateCompanionBuilder,
      $$EpgMappingsTableUpdateCompanionBuilder,
      (EpgMapping, $$EpgMappingsTableReferences),
      EpgMapping,
      PrefetchHooks Function({bool channelId, bool epgSourceId})
    >;
typedef $$ChannelGroupsTableCreateCompanionBuilder =
    ChannelGroupsCompanion Function({
      required String id,
      required String name,
      Value<int> sortOrder,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$ChannelGroupsTableUpdateCompanionBuilder =
    ChannelGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<bool> hidden,
      Value<int> rowid,
    });

class $$ChannelGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelGroupsTable> {
  $$ChannelGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChannelGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelGroupsTable> {
  $$ChannelGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChannelGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelGroupsTable> {
  $$ChannelGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);
}

class $$ChannelGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelGroupsTable,
          ChannelGroup,
          $$ChannelGroupsTableFilterComposer,
          $$ChannelGroupsTableOrderingComposer,
          $$ChannelGroupsTableAnnotationComposer,
          $$ChannelGroupsTableCreateCompanionBuilder,
          $$ChannelGroupsTableUpdateCompanionBuilder,
          (
            ChannelGroup,
            BaseReferences<_$AppDatabase, $ChannelGroupsTable, ChannelGroup>,
          ),
          ChannelGroup,
          PrefetchHooks Function()
        > {
  $$ChannelGroupsTableTableManager(_$AppDatabase db, $ChannelGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelGroupsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelGroupsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                hidden: hidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChannelGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelGroupsTable,
      ChannelGroup,
      $$ChannelGroupsTableFilterComposer,
      $$ChannelGroupsTableOrderingComposer,
      $$ChannelGroupsTableAnnotationComposer,
      $$ChannelGroupsTableCreateCompanionBuilder,
      $$ChannelGroupsTableUpdateCompanionBuilder,
      (
        ChannelGroup,
        BaseReferences<_$AppDatabase, $ChannelGroupsTable, ChannelGroup>,
      ),
      ChannelGroup,
      PrefetchHooks Function()
    >;
typedef $$FavoriteListsTableCreateCompanionBuilder =
    FavoriteListsCompanion Function({
      required String id,
      required String name,
      Value<String> icon,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FavoriteListsTableUpdateCompanionBuilder =
    FavoriteListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> icon,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FavoriteListsTableReferences
    extends BaseReferences<_$AppDatabase, $FavoriteListsTable, FavoriteList> {
  $$FavoriteListsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $FavoriteListChannelsTable,
    List<FavoriteListChannel>
  >
  _favoriteListChannelsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.favoriteListChannels,
        aliasName: $_aliasNameGenerator(
          db.favoriteLists.id,
          db.favoriteListChannels.listId,
        ),
      );

  $$FavoriteListChannelsTableProcessedTableManager
  get favoriteListChannelsRefs {
    final manager = $$FavoriteListChannelsTableTableManager(
      $_db,
      $_db.favoriteListChannels,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteListChannelsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoriteListsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteListsTable> {
  $$FavoriteListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> favoriteListChannelsRefs(
    Expression<bool> Function($$FavoriteListChannelsTableFilterComposer f) f,
  ) {
    final $$FavoriteListChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteListChannels,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteListChannelsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteListChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteListsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteListsTable> {
  $$FavoriteListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteListsTable> {
  $$FavoriteListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> favoriteListChannelsRefs<T extends Object>(
    Expression<T> Function($$FavoriteListChannelsTableAnnotationComposer a) f,
  ) {
    final $$FavoriteListChannelsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteListChannels,
          getReferencedColumn: (t) => t.listId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteListChannelsTableAnnotationComposer(
                $db: $db,
                $table: $db.favoriteListChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FavoriteListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteListsTable,
          FavoriteList,
          $$FavoriteListsTableFilterComposer,
          $$FavoriteListsTableOrderingComposer,
          $$FavoriteListsTableAnnotationComposer,
          $$FavoriteListsTableCreateCompanionBuilder,
          $$FavoriteListsTableUpdateCompanionBuilder,
          (FavoriteList, $$FavoriteListsTableReferences),
          FavoriteList,
          PrefetchHooks Function({bool favoriteListChannelsRefs})
        > {
  $$FavoriteListsTableTableManager(_$AppDatabase db, $FavoriteListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteListsCompanion(
                id: id,
                name: name,
                icon: icon,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteListsCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoriteListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoriteListChannelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (favoriteListChannelsRefs) db.favoriteListChannels,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoriteListChannelsRefs)
                    await $_getPrefetchedData<
                      FavoriteList,
                      $FavoriteListsTable,
                      FavoriteListChannel
                    >(
                      currentTable: table,
                      referencedTable: $$FavoriteListsTableReferences
                          ._favoriteListChannelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FavoriteListsTableReferences(
                            db,
                            table,
                            p0,
                          ).favoriteListChannelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteListsTable,
      FavoriteList,
      $$FavoriteListsTableFilterComposer,
      $$FavoriteListsTableOrderingComposer,
      $$FavoriteListsTableAnnotationComposer,
      $$FavoriteListsTableCreateCompanionBuilder,
      $$FavoriteListsTableUpdateCompanionBuilder,
      (FavoriteList, $$FavoriteListsTableReferences),
      FavoriteList,
      PrefetchHooks Function({bool favoriteListChannelsRefs})
    >;
typedef $$FavoriteListChannelsTableCreateCompanionBuilder =
    FavoriteListChannelsCompanion Function({
      required String listId,
      required String channelId,
      Value<int> sortOrder,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$FavoriteListChannelsTableUpdateCompanionBuilder =
    FavoriteListChannelsCompanion Function({
      Value<String> listId,
      Value<String> channelId,
      Value<int> sortOrder,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$FavoriteListChannelsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FavoriteListChannelsTable,
          FavoriteListChannel
        > {
  $$FavoriteListChannelsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FavoriteListsTable _listIdTable(_$AppDatabase db) =>
      db.favoriteLists.createAlias(
        $_aliasNameGenerator(
          db.favoriteListChannels.listId,
          db.favoriteLists.id,
        ),
      );

  $$FavoriteListsTableProcessedTableManager get listId {
    final $_column = $_itemColumn<String>('list_id')!;

    final manager = $$FavoriteListsTableTableManager(
      $_db,
      $_db.favoriteLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChannelsTable _channelIdTable(_$AppDatabase db) =>
      db.channels.createAlias(
        $_aliasNameGenerator(db.favoriteListChannels.channelId, db.channels.id),
      );

  $$ChannelsTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<String>('channel_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoriteListChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteListChannelsTable> {
  $$FavoriteListChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FavoriteListsTableFilterComposer get listId {
    final $$FavoriteListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.favoriteLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteListsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableFilterComposer get channelId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteListChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteListChannelsTable> {
  $$FavoriteListChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FavoriteListsTableOrderingComposer get listId {
    final $$FavoriteListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.favoriteLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteListsTableOrderingComposer(
            $db: $db,
            $table: $db.favoriteLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableOrderingComposer get channelId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteListChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteListChannelsTable> {
  $$FavoriteListChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$FavoriteListsTableAnnotationComposer get listId {
    final $$FavoriteListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.favoriteLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteListsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableAnnotationComposer get channelId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteListChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteListChannelsTable,
          FavoriteListChannel,
          $$FavoriteListChannelsTableFilterComposer,
          $$FavoriteListChannelsTableOrderingComposer,
          $$FavoriteListChannelsTableAnnotationComposer,
          $$FavoriteListChannelsTableCreateCompanionBuilder,
          $$FavoriteListChannelsTableUpdateCompanionBuilder,
          (FavoriteListChannel, $$FavoriteListChannelsTableReferences),
          FavoriteListChannel,
          PrefetchHooks Function({bool listId, bool channelId})
        > {
  $$FavoriteListChannelsTableTableManager(
    _$AppDatabase db,
    $FavoriteListChannelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteListChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteListChannelsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FavoriteListChannelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> listId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteListChannelsCompanion(
                listId: listId,
                channelId: channelId,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String listId,
                required String channelId,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteListChannelsCompanion.insert(
                listId: listId,
                channelId: channelId,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoriteListChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false, channelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.listId,
                                referencedTable:
                                    $$FavoriteListChannelsTableReferences
                                        ._listIdTable(db),
                                referencedColumn:
                                    $$FavoriteListChannelsTableReferences
                                        ._listIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (channelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.channelId,
                                referencedTable:
                                    $$FavoriteListChannelsTableReferences
                                        ._channelIdTable(db),
                                referencedColumn:
                                    $$FavoriteListChannelsTableReferences
                                        ._channelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteListChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteListChannelsTable,
      FavoriteListChannel,
      $$FavoriteListChannelsTableFilterComposer,
      $$FavoriteListChannelsTableOrderingComposer,
      $$FavoriteListChannelsTableAnnotationComposer,
      $$FavoriteListChannelsTableCreateCompanionBuilder,
      $$FavoriteListChannelsTableUpdateCompanionBuilder,
      (FavoriteListChannel, $$FavoriteListChannelsTableReferences),
      FavoriteListChannel,
      PrefetchHooks Function({bool listId, bool channelId})
    >;
typedef $$EpgRemindersTableCreateCompanionBuilder =
    EpgRemindersCompanion Function({
      required String id,
      required String epgChannelId,
      Value<String?> channelId,
      required String programmeTitle,
      required DateTime programmeStart,
      required DateTime programmeStop,
      Value<int> minutesBefore,
      Value<bool> fired,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$EpgRemindersTableUpdateCompanionBuilder =
    EpgRemindersCompanion Function({
      Value<String> id,
      Value<String> epgChannelId,
      Value<String?> channelId,
      Value<String> programmeTitle,
      Value<DateTime> programmeStart,
      Value<DateTime> programmeStop,
      Value<int> minutesBefore,
      Value<bool> fired,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$EpgRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $EpgRemindersTable> {
  $$EpgRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fired => $composableBuilder(
    column: $table.fired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpgRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgRemindersTable> {
  $$EpgRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fired => $composableBuilder(
    column: $table.fired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpgRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgRemindersTable> {
  $$EpgRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minutesBefore => $composableBuilder(
    column: $table.minutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get fired =>
      $composableBuilder(column: $table.fired, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EpgRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgRemindersTable,
          EpgReminder,
          $$EpgRemindersTableFilterComposer,
          $$EpgRemindersTableOrderingComposer,
          $$EpgRemindersTableAnnotationComposer,
          $$EpgRemindersTableCreateCompanionBuilder,
          $$EpgRemindersTableUpdateCompanionBuilder,
          (
            EpgReminder,
            BaseReferences<_$AppDatabase, $EpgRemindersTable, EpgReminder>,
          ),
          EpgReminder,
          PrefetchHooks Function()
        > {
  $$EpgRemindersTableTableManager(_$AppDatabase db, $EpgRemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<String> programmeTitle = const Value.absent(),
                Value<DateTime> programmeStart = const Value.absent(),
                Value<DateTime> programmeStop = const Value.absent(),
                Value<int> minutesBefore = const Value.absent(),
                Value<bool> fired = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgRemindersCompanion(
                id: id,
                epgChannelId: epgChannelId,
                channelId: channelId,
                programmeTitle: programmeTitle,
                programmeStart: programmeStart,
                programmeStop: programmeStop,
                minutesBefore: minutesBefore,
                fired: fired,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String epgChannelId,
                Value<String?> channelId = const Value.absent(),
                required String programmeTitle,
                required DateTime programmeStart,
                required DateTime programmeStop,
                Value<int> minutesBefore = const Value.absent(),
                Value<bool> fired = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgRemindersCompanion.insert(
                id: id,
                epgChannelId: epgChannelId,
                channelId: channelId,
                programmeTitle: programmeTitle,
                programmeStart: programmeStart,
                programmeStop: programmeStop,
                minutesBefore: minutesBefore,
                fired: fired,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpgRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgRemindersTable,
      EpgReminder,
      $$EpgRemindersTableFilterComposer,
      $$EpgRemindersTableOrderingComposer,
      $$EpgRemindersTableAnnotationComposer,
      $$EpgRemindersTableCreateCompanionBuilder,
      $$EpgRemindersTableUpdateCompanionBuilder,
      (
        EpgReminder,
        BaseReferences<_$AppDatabase, $EpgRemindersTable, EpgReminder>,
      ),
      EpgReminder,
      PrefetchHooks Function()
    >;
typedef $$ScheduledRecordingsTableCreateCompanionBuilder =
    ScheduledRecordingsCompanion Function({
      required String id,
      required String epgChannelId,
      Value<String?> channelId,
      required String programmeTitle,
      required DateTime programmeStart,
      required DateTime programmeStop,
      Value<String> status,
      Value<String?> outputPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ScheduledRecordingsTableUpdateCompanionBuilder =
    ScheduledRecordingsCompanion Function({
      Value<String> id,
      Value<String> epgChannelId,
      Value<String?> channelId,
      Value<String> programmeTitle,
      Value<DateTime> programmeStart,
      Value<DateTime> programmeStop,
      Value<String> status,
      Value<String?> outputPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ScheduledRecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledRecordingsTable> {
  $$ScheduledRecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduledRecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledRecordingsTable> {
  $$ScheduledRecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduledRecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledRecordingsTable> {
  $$ScheduledRecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get programmeTitle => $composableBuilder(
    column: $table.programmeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get programmeStart => $composableBuilder(
    column: $table.programmeStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get programmeStop => $composableBuilder(
    column: $table.programmeStop,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ScheduledRecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledRecordingsTable,
          ScheduledRecording,
          $$ScheduledRecordingsTableFilterComposer,
          $$ScheduledRecordingsTableOrderingComposer,
          $$ScheduledRecordingsTableAnnotationComposer,
          $$ScheduledRecordingsTableCreateCompanionBuilder,
          $$ScheduledRecordingsTableUpdateCompanionBuilder,
          (
            ScheduledRecording,
            BaseReferences<
              _$AppDatabase,
              $ScheduledRecordingsTable,
              ScheduledRecording
            >,
          ),
          ScheduledRecording,
          PrefetchHooks Function()
        > {
  $$ScheduledRecordingsTableTableManager(
    _$AppDatabase db,
    $ScheduledRecordingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledRecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduledRecordingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledRecordingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<String> programmeTitle = const Value.absent(),
                Value<DateTime> programmeStart = const Value.absent(),
                Value<DateTime> programmeStop = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledRecordingsCompanion(
                id: id,
                epgChannelId: epgChannelId,
                channelId: channelId,
                programmeTitle: programmeTitle,
                programmeStart: programmeStart,
                programmeStop: programmeStop,
                status: status,
                outputPath: outputPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String epgChannelId,
                Value<String?> channelId = const Value.absent(),
                required String programmeTitle,
                required DateTime programmeStart,
                required DateTime programmeStop,
                Value<String> status = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduledRecordingsCompanion.insert(
                id: id,
                epgChannelId: epgChannelId,
                channelId: channelId,
                programmeTitle: programmeTitle,
                programmeStart: programmeStart,
                programmeStop: programmeStop,
                status: status,
                outputPath: outputPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduledRecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledRecordingsTable,
      ScheduledRecording,
      $$ScheduledRecordingsTableFilterComposer,
      $$ScheduledRecordingsTableOrderingComposer,
      $$ScheduledRecordingsTableAnnotationComposer,
      $$ScheduledRecordingsTableCreateCompanionBuilder,
      $$ScheduledRecordingsTableUpdateCompanionBuilder,
      (
        ScheduledRecording,
        BaseReferences<
          _$AppDatabase,
          $ScheduledRecordingsTable,
          ScheduledRecording
        >,
      ),
      ScheduledRecording,
      PrefetchHooks Function()
    >;
typedef $$FailoverGroupsTableCreateCompanionBuilder =
    FailoverGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<DateTime> createdAt,
    });
typedef $$FailoverGroupsTableUpdateCompanionBuilder =
    FailoverGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$FailoverGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $FailoverGroupsTable, FailoverGroup> {
  $$FailoverGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $FailoverGroupChannelsTable,
    List<FailoverGroupChannel>
  >
  _failoverGroupChannelsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.failoverGroupChannels,
        aliasName: $_aliasNameGenerator(
          db.failoverGroups.id,
          db.failoverGroupChannels.groupId,
        ),
      );

  $$FailoverGroupChannelsTableProcessedTableManager
  get failoverGroupChannelsRefs {
    final manager = $$FailoverGroupChannelsTableTableManager(
      $_db,
      $_db.failoverGroupChannels,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _failoverGroupChannelsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FailoverGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $FailoverGroupsTable> {
  $$FailoverGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> failoverGroupChannelsRefs(
    Expression<bool> Function($$FailoverGroupChannelsTableFilterComposer f) f,
  ) {
    final $$FailoverGroupChannelsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.failoverGroupChannels,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FailoverGroupChannelsTableFilterComposer(
                $db: $db,
                $table: $db.failoverGroupChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FailoverGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $FailoverGroupsTable> {
  $$FailoverGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FailoverGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FailoverGroupsTable> {
  $$FailoverGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> failoverGroupChannelsRefs<T extends Object>(
    Expression<T> Function($$FailoverGroupChannelsTableAnnotationComposer a) f,
  ) {
    final $$FailoverGroupChannelsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.failoverGroupChannels,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FailoverGroupChannelsTableAnnotationComposer(
                $db: $db,
                $table: $db.failoverGroupChannels,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FailoverGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FailoverGroupsTable,
          FailoverGroup,
          $$FailoverGroupsTableFilterComposer,
          $$FailoverGroupsTableOrderingComposer,
          $$FailoverGroupsTableAnnotationComposer,
          $$FailoverGroupsTableCreateCompanionBuilder,
          $$FailoverGroupsTableUpdateCompanionBuilder,
          (FailoverGroup, $$FailoverGroupsTableReferences),
          FailoverGroup,
          PrefetchHooks Function({bool failoverGroupChannelsRefs})
        > {
  $$FailoverGroupsTableTableManager(
    _$AppDatabase db,
    $FailoverGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FailoverGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FailoverGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FailoverGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FailoverGroupsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
              }) => FailoverGroupsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FailoverGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({failoverGroupChannelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (failoverGroupChannelsRefs) db.failoverGroupChannels,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (failoverGroupChannelsRefs)
                    await $_getPrefetchedData<
                      FailoverGroup,
                      $FailoverGroupsTable,
                      FailoverGroupChannel
                    >(
                      currentTable: table,
                      referencedTable: $$FailoverGroupsTableReferences
                          ._failoverGroupChannelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FailoverGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).failoverGroupChannelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FailoverGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FailoverGroupsTable,
      FailoverGroup,
      $$FailoverGroupsTableFilterComposer,
      $$FailoverGroupsTableOrderingComposer,
      $$FailoverGroupsTableAnnotationComposer,
      $$FailoverGroupsTableCreateCompanionBuilder,
      $$FailoverGroupsTableUpdateCompanionBuilder,
      (FailoverGroup, $$FailoverGroupsTableReferences),
      FailoverGroup,
      PrefetchHooks Function({bool failoverGroupChannelsRefs})
    >;
typedef $$FailoverGroupChannelsTableCreateCompanionBuilder =
    FailoverGroupChannelsCompanion Function({
      required int groupId,
      required String channelId,
      Value<int> priority,
      Value<int> rowid,
    });
typedef $$FailoverGroupChannelsTableUpdateCompanionBuilder =
    FailoverGroupChannelsCompanion Function({
      Value<int> groupId,
      Value<String> channelId,
      Value<int> priority,
      Value<int> rowid,
    });

final class $$FailoverGroupChannelsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FailoverGroupChannelsTable,
          FailoverGroupChannel
        > {
  $$FailoverGroupChannelsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FailoverGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.failoverGroups.createAlias(
        $_aliasNameGenerator(
          db.failoverGroupChannels.groupId,
          db.failoverGroups.id,
        ),
      );

  $$FailoverGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$FailoverGroupsTableTableManager(
      $_db,
      $_db.failoverGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChannelsTable _channelIdTable(_$AppDatabase db) =>
      db.channels.createAlias(
        $_aliasNameGenerator(
          db.failoverGroupChannels.channelId,
          db.channels.id,
        ),
      );

  $$ChannelsTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<String>('channel_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FailoverGroupChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $FailoverGroupChannelsTable> {
  $$FailoverGroupChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  $$FailoverGroupsTableFilterComposer get groupId {
    final $$FailoverGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.failoverGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FailoverGroupsTableFilterComposer(
            $db: $db,
            $table: $db.failoverGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableFilterComposer get channelId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailoverGroupChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $FailoverGroupChannelsTable> {
  $$FailoverGroupChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  $$FailoverGroupsTableOrderingComposer get groupId {
    final $$FailoverGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.failoverGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FailoverGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.failoverGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableOrderingComposer get channelId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailoverGroupChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FailoverGroupChannelsTable> {
  $$FailoverGroupChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  $$FailoverGroupsTableAnnotationComposer get groupId {
    final $$FailoverGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.failoverGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FailoverGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.failoverGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChannelsTableAnnotationComposer get channelId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailoverGroupChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FailoverGroupChannelsTable,
          FailoverGroupChannel,
          $$FailoverGroupChannelsTableFilterComposer,
          $$FailoverGroupChannelsTableOrderingComposer,
          $$FailoverGroupChannelsTableAnnotationComposer,
          $$FailoverGroupChannelsTableCreateCompanionBuilder,
          $$FailoverGroupChannelsTableUpdateCompanionBuilder,
          (FailoverGroupChannel, $$FailoverGroupChannelsTableReferences),
          FailoverGroupChannel,
          PrefetchHooks Function({bool groupId, bool channelId})
        > {
  $$FailoverGroupChannelsTableTableManager(
    _$AppDatabase db,
    $FailoverGroupChannelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FailoverGroupChannelsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FailoverGroupChannelsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FailoverGroupChannelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FailoverGroupChannelsCompanion(
                groupId: groupId,
                channelId: channelId,
                priority: priority,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int groupId,
                required String channelId,
                Value<int> priority = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FailoverGroupChannelsCompanion.insert(
                groupId: groupId,
                channelId: channelId,
                priority: priority,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FailoverGroupChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false, channelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$FailoverGroupChannelsTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$FailoverGroupChannelsTableReferences
                                        ._groupIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (channelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.channelId,
                                referencedTable:
                                    $$FailoverGroupChannelsTableReferences
                                        ._channelIdTable(db),
                                referencedColumn:
                                    $$FailoverGroupChannelsTableReferences
                                        ._channelIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FailoverGroupChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FailoverGroupChannelsTable,
      FailoverGroupChannel,
      $$FailoverGroupChannelsTableFilterComposer,
      $$FailoverGroupChannelsTableOrderingComposer,
      $$FailoverGroupChannelsTableAnnotationComposer,
      $$FailoverGroupChannelsTableCreateCompanionBuilder,
      $$FailoverGroupChannelsTableUpdateCompanionBuilder,
      (FailoverGroupChannel, $$FailoverGroupChannelsTableReferences),
      FailoverGroupChannel,
      PrefetchHooks Function({bool groupId, bool channelId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProvidersTableTableManager get providers =>
      $$ProvidersTableTableManager(_db, _db.providers);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$EpgSourcesTableTableManager get epgSources =>
      $$EpgSourcesTableTableManager(_db, _db.epgSources);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db, _db.epgChannels);
  $$EpgProgrammesTableTableManager get epgProgrammes =>
      $$EpgProgrammesTableTableManager(_db, _db.epgProgrammes);
  $$EpgMappingsTableTableManager get epgMappings =>
      $$EpgMappingsTableTableManager(_db, _db.epgMappings);
  $$ChannelGroupsTableTableManager get channelGroups =>
      $$ChannelGroupsTableTableManager(_db, _db.channelGroups);
  $$FavoriteListsTableTableManager get favoriteLists =>
      $$FavoriteListsTableTableManager(_db, _db.favoriteLists);
  $$FavoriteListChannelsTableTableManager get favoriteListChannels =>
      $$FavoriteListChannelsTableTableManager(_db, _db.favoriteListChannels);
  $$EpgRemindersTableTableManager get epgReminders =>
      $$EpgRemindersTableTableManager(_db, _db.epgReminders);
  $$ScheduledRecordingsTableTableManager get scheduledRecordings =>
      $$ScheduledRecordingsTableTableManager(_db, _db.scheduledRecordings);
  $$FailoverGroupsTableTableManager get failoverGroups =>
      $$FailoverGroupsTableTableManager(_db, _db.failoverGroups);
  $$FailoverGroupChannelsTableTableManager get failoverGroupChannels =>
      $$FailoverGroupChannelsTableTableManager(_db, _db.failoverGroupChannels);
}
