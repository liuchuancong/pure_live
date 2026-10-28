import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_net/live_net.dart' show ClientProfile;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/app.dart'
    show appProxyEndpoint, networkFactoryProvider, proxySettingsProvider, systemProxyProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoFailureText;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_account.dart'
    show
        HongguoAccountClient,
        HongguoAccountFailure,
        HongguoCloudFavorite,
        HongguoCloudProgress,
        HongguoCloudReservation,
        HongguoCredentials,
        HongguoProfile;
import 'package:pure_live/modules/hongguo/official/hongguo_home_feed.dart' show HongguoHomeFeed, HongguoHomeFeedFailure;
import 'package:pure_live/modules/hongguo/official/hongguo_web_login.dart'
    show HongguoLoginFailure, HongguoQrCode, HongguoWebLogin;

const String _kCredentialsKey = 'hongguo.account.credentials';

/// The account session: the confirmed credentials and the profile they
/// answer, or the signed-out state.
@immutable
final class HongguoAccountState {
  /// Creates the state.
  const HongguoAccountState({this.credentials, this.profile, this.loading = false, this.error});

  /// The confirmed login, or null when signed out.
  final HongguoCredentials? credentials;

  /// The signed-in viewer, once read.
  final HongguoProfile? profile;

  /// Whether a sign-in or profile read is in flight.
  final bool loading;

  /// The last session failure, when one happened.
  final String? error;

  /// Whether a login is held.
  bool get signedIn => credentials != null && credentials!.cookie.isNotEmpty;
}

/// Owns the sign-in: restoring a stored login, settling a fresh QR
/// confirmation, reading the profile, and signing out.
final class HongguoAccountController extends Notifier<HongguoAccountState> {
  @override
  HongguoAccountState build() {
    final stored = _readStored();
    if (stored == null) return const HongguoAccountState();
    return HongguoAccountState(credentials: stored, loading: true);
  }

  static HongguoCredentials? _readStored() {
    try {
      final raw = StoragePrefs.getString(_kCredentialsKey);
      if (raw == null || raw.isEmpty) return null;
      return HongguoCredentials.fromJson(raw);
    } on Object {
      return null;
    }
  }

  /// Reads (or re-reads) the held login's profile; a login the platform
  /// refuses is signed out.
  Future<void> refreshProfile() async {
    final credentials = state.credentials;
    if (credentials == null) return;
    state = HongguoAccountState(credentials: credentials, profile: state.profile, loading: true);
    try {
      final profile = await ref.read(hongguoAccountClientProvider).profile(credentials);
      state = HongguoAccountState(credentials: credentials, profile: profile);
    } on Object catch (error) {
      if (error is HongguoAccountFailure && error.message.contains('重新登录')) {
        await signOut();
        state = HongguoAccountState(error: hongguoFailureText(error));
        return;
      }
      state = HongguoAccountState(credentials: credentials, profile: state.profile, error: hongguoFailureText(error));
    }
  }

  /// A fresh QR confirmation to settle: the website login's cookie becomes
  /// the account credentials, on a device identity of its own.
  Future<void> signIn(HongguoWebLogin login) async {
    state = const HongguoAccountState(loading: true);
    try {
      final cookie = await login.credentials();
      final credentials = HongguoCredentials(cookie: cookie);
      final profile = await ref.read(hongguoAccountClientProvider).profile(credentials);
      state = HongguoAccountState(credentials: credentials, profile: profile);
      try {
        unawaited(StoragePrefs.setString(_kCredentialsKey, credentials.toJson()));
      } on Object {
        // A closed store loses the login; the next sign-in writes again.
      }
    } on Object catch (error) {
      state = HongguoAccountState(error: hongguoFailureText(error));
    }
  }

  /// Signs out; the local shelves stay untouched.
  Future<void> signOut() async {
    state = const HongguoAccountState();
    try {
      unawaited(StoragePrefs.remove(_kCredentialsKey));
    } on Object {
      // A closed store keeps the stale login; the next start re-reads it.
    }
  }
}

/// The account session.
final hongguoAccountProvider = NotifierProvider<HongguoAccountController, HongguoAccountState>(
  HongguoAccountController.new,
);

/// The account client, over the shared transport.
final hongguoAccountClientProvider = Provider<HongguoAccountClient>((ref) {
  return HongguoAccountClient(http: ref.watch(networkFactoryProvider).create(profile: ClientProfile.api));
});

/// One QR login session in flight: the code to show, its expiry, and the
/// poll loop's state. Disposed when the account view leaves.
final class HongguoLoginSessionController extends Notifier<({HongguoQrCode? qr, bool polling, String? error})> {
  HongguoWebLogin? _login;

  @override
  ({HongguoQrCode? qr, bool polling, String? error}) build() => (qr: null, polling: false, error: null);

  /// A fresh login session over the app's proxy, when one is in force.
  HongguoWebLogin _newLogin() {
    final endpoint = appProxyEndpoint(ref.read(proxySettingsProvider), ref.read(systemProxyProvider));
    return HongguoWebLogin(proxy: endpoint == null ? null : '${endpoint.host}:${endpoint.port}');
  }

  HongguoWebLogin _ensureLogin() => _login ??= _newLogin();

  /// Fetches a fresh QR code.
  Future<void> load() async {
    _login?.dispose();
    _login = _newLogin();
    state = (qr: null, polling: false, error: null);
    try {
      final qr = await _login!.qr();
      state = (qr: qr, polling: false, error: null);
    } on Object catch (error) {
      state = (qr: null, polling: false, error: error is HongguoLoginFailure ? error.message : '$error');
    }
  }

  /// Sends the login code to [number] over the same website passport the QR
  /// flow uses — the account's second way in, without a second sign-in path.
  Future<({String maskedMobile, int retrySeconds})> sendCode(String number) async {
    try {
      final sent = await _ensureLogin().sendCode(number);
      state = (qr: null, polling: false, error: null);
      return sent;
    } on Object catch (error) {
      final message = error is HongguoLoginFailure ? error.message : '$error';
      state = (qr: null, polling: false, error: message);
      throw HongguoLoginFailure(message);
    }
  }

  /// Verifies [code]; a settled session signs the account in.
  Future<void> verifyCode(String code) async {
    final login = _ensureLogin();
    state = (qr: null, polling: true, error: null);
    try {
      final settled = await login.verifyCode(code);
      if (!settled) throw const HongguoLoginFailure('登录态没有下发，请重试');
      await ref.read(hongguoAccountProvider.notifier).signIn(login);
      login.dispose();
      if (identical(_login, login)) _login = null;
      state = (qr: null, polling: false, error: null);
    } on Object catch (error) {
      final message = error is HongguoLoginFailure ? error.message : '$error';
      state = (qr: null, polling: false, error: message);
      throw HongguoLoginFailure(message);
    }
  }

  /// Polls the code once; on confirmation the account session is settled.
  /// Answers whether the poll loop may stop.
  Future<bool> poll() async {
    final login = _login;
    if (login == null || state.polling) return true;
    state = (qr: state.qr, polling: true, error: null);
    try {
      final confirmed = await login.poll();
      if (!confirmed) {
        state = (qr: state.qr, polling: false, error: null);
        return false;
      }
      await ref.read(hongguoAccountProvider.notifier).signIn(login);
      login.dispose();
      _login = null;
      state = (qr: null, polling: false, error: null);
      return true;
    } on Object catch (error) {
      state = (qr: state.qr, polling: false, error: error is HongguoLoginFailure ? error.message : '$error');
      return true;
    }
  }
}

/// The QR login session in flight.
final hongguoLoginSessionProvider =
    NotifierProvider<HongguoLoginSessionController, ({HongguoQrCode? qr, bool polling, String? error})>(
      HongguoLoginSessionController.new,
    );

/// One account shelf's state: its rows and the ask's shape.
typedef HongguoAccountListState<T> = ({List<T> items, bool loading, String? error});

const HongguoAccountListState<Object?> _idleList = (items: [], loading: false, error: null);

/// The account favorites shelf.
final class HongguoAccountFavoritesController extends Notifier<HongguoAccountListState<HongguoCloudFavorite>> {
  @override
  HongguoAccountListState<HongguoCloudFavorite> build() => _idleList as HongguoAccountListState<HongguoCloudFavorite>;

  /// Reads the shelf again.
  Future<void> refresh() async {
    final account = ref.read(hongguoAccountProvider);
    final credentials = account.credentials;
    if (credentials == null) {
      state = _idleList as HongguoAccountListState<HongguoCloudFavorite>;
      return;
    }
    state = (items: state.items, loading: true, error: null);
    try {
      final items = await ref.read(hongguoAccountClientProvider).favorites(credentials);
      state = (items: items, loading: false, error: null);
    } on Object catch (error) {
      state = (items: state.items, loading: false, error: hongguoFailureText(error));
    }
  }

  /// Adds or removes the series on the cloud shelf.
  Future<void> setFavorite(HongguoSeries series, {required bool add}) async {
    final credentials = ref.read(hongguoAccountProvider).credentials;
    if (credentials == null) return;
    try {
      await ref.read(hongguoAccountClientProvider).setFavorite(credentials, series.seriesId, add: add);
    } on Object {
      // The platform only acknowledges anyway; the shelf read-back decides.
    }
    await refresh();
  }
}

/// The account favorites shelf.
final hongguoAccountFavoritesProvider =
    NotifierProvider<HongguoAccountFavoritesController, HongguoAccountListState<HongguoCloudFavorite>>(
      HongguoAccountFavoritesController.new,
    );

/// The cloud watch history.
final class HongguoAccountHistoryController extends Notifier<HongguoAccountListState<HongguoCloudProgress>> {
  @override
  HongguoAccountListState<HongguoCloudProgress> build() => _idleList as HongguoAccountListState<HongguoCloudProgress>;

  /// Reads the history again.
  Future<void> refresh() async {
    final credentials = ref.read(hongguoAccountProvider).credentials;
    if (credentials == null) {
      state = _idleList as HongguoAccountListState<HongguoCloudProgress>;
      return;
    }
    state = (items: state.items, loading: true, error: null);
    try {
      final items = await ref.read(hongguoAccountClientProvider).history(credentials);
      state = (items: items, loading: false, error: null);
    } on Object catch (error) {
      state = (items: state.items, loading: false, error: hongguoFailureText(error));
    }
  }
}

/// The cloud watch history.
final hongguoAccountHistoryProvider =
    NotifierProvider<HongguoAccountHistoryController, HongguoAccountListState<HongguoCloudProgress>>(
      HongguoAccountHistoryController.new,
    );

/// Both reservation shelves at once.
typedef HongguoReservationsState = ({
  List<HongguoCloudReservation> online,
  List<HongguoCloudReservation> upcoming,
  bool loading,
  String? error,
});

/// The account's reservations, premiered and waiting.
final class HongguoReservationsController extends Notifier<HongguoReservationsState> {
  @override
  HongguoReservationsState build() => (online: const [], upcoming: const [], loading: false, error: null);

  /// Reads both shelves again.
  Future<void> refresh() async {
    final credentials = ref.read(hongguoAccountProvider).credentials;
    if (credentials == null) {
      state = (online: const [], upcoming: const [], loading: false, error: null);
      return;
    }
    state = (online: state.online, upcoming: state.upcoming, loading: true, error: null);
    try {
      final client = ref.read(hongguoAccountClientProvider);
      final online = await client.reservations(credentials, online: true);
      final upcoming = await client.reservations(credentials, online: false);
      state = (online: online, upcoming: upcoming, loading: false, error: null);
    } on Object catch (error) {
      state = (online: state.online, upcoming: state.upcoming, loading: false, error: hongguoFailureText(error));
    }
  }
}

/// The account's reservations.
final hongguoReservationsProvider = NotifierProvider<HongguoReservationsController, HongguoReservationsState>(
  HongguoReservationsController.new,
);

/// The home feed: the genre held, its rows and the ask's shape. Switching
/// the genre starts a fresh feed session, as the reference does.
typedef HongguoHomeState = ({HongguoGenre? genre, List<HongguoSeries> items, bool loading, String? error});

/// The 首页 feed: cross-genre by default, one shelf's own feed when a genre
/// is chosen; 换一批 walks the session cursor.
final class HongguoHomeController extends Notifier<HongguoHomeState> {
  HongguoHomeFeed? _feed;
  HongguoGenre? _genre;

  @override
  HongguoHomeState build() => (genre: null, items: const [], loading: false, error: null);

  /// Loads the first batch of the genre (null for the cross-genre feed).
  Future<void> open(HongguoGenre? genre) {
    if (state.genre == genre && (state.items.isNotEmpty || state.loading)) return Future.value();
    return _load(genre);
  }

  /// The next batch of the held feed.
  Future<void> loadMore() {
    if (state.loading || _feed == null) return Future.value();
    return _load(state.genre, keep: true);
  }

  /// Runs the held feed from its first batch.
  Future<void> retry() => _load(state.genre);

  Future<void> _load(HongguoGenre? genre, {bool keep = false}) async {
    if (!keep) {
      _feed = null;
      _genre = genre;
    }
    final feed = _feed ??= HongguoHomeFeed(
      http: ref.read(networkFactoryProvider).create(profile: ClientProfile.api),
      account: ref.read(hongguoAccountProvider).credentials,
    );
    if (_genre != genre) _genre = genre;
    state = (genre: genre, items: keep ? state.items : const [], loading: true, error: null);
    try {
      final items = await feed.page(genre);
      state = (genre: genre, items: keep ? [...state.items, ...items] : items, loading: false, error: null);
    } on Object catch (error) {
      state = (
        genre: genre,
        items: state.items,
        loading: false,
        error: error is HongguoHomeFeedFailure ? error.message : '$error',
      );
    }
  }
}

/// The home feed.
final hongguoHomeProvider = NotifierProvider<HongguoHomeController, HongguoHomeState>(HongguoHomeController.new);
