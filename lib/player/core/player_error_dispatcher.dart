import 'package:rxdart/rxdart.dart';
import '../models/player_exception.dart';

class PlayerErrorDispatcher {
  static final PlayerErrorDispatcher instance = PlayerErrorDispatcher._();

  PlayerErrorDispatcher._();

  final _errorSubject = PublishSubject<PlayerException>();

  Stream<PlayerException> get stream => _errorSubject.stream;

  void dispatch(PlayerException error) {
    _errorSubject.add(error);
  }

  Future<void> dispose() async {
    await _errorSubject.close();
  }
}
