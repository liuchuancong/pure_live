import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';

void main() {
  test('a failed room load shows the retry placeholder instead of spinning forever', () {
    // isLiving defaults to true; before, this state kept the loading spinner.
    expect(livePlayPlaceholderFor(const RoomState(loadError: 'Kick access')), LivePlayPlaceholder.loadFailed);
    expect(livePlayPlaceholderFor(const RoomState(isLoading: true, loadError: 'old')), LivePlayPlaceholder.loading);
    expect(livePlayPlaceholderFor(const RoomState()), LivePlayPlaceholder.loading);
    expect(livePlayPlaceholderFor(const RoomState(isLiving: false)), LivePlayPlaceholder.notLiving);
  });
}
