import 'package:pure_live/core/interface/live_input_recipe.dart';

import 'fc2_link.dart';

final class Fc2InputRecipe implements LiveInputRecipe {
  Fc2InputRecipe(String channelId) : channelId = Fc2Link.requireChannelId(channelId);

  final String channelId;

  @override
  String get identity => 'fc2live:$channelId:auto';
}
