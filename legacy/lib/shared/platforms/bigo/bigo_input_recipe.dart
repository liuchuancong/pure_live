import 'package:pure_live/shared/platforms/live_input_recipe.dart';

import 'bigo_api.dart';

final class BigoInputRecipe implements LiveInputRecipe {
  BigoInputRecipe(String siteId) : siteId = BigoApi.validateSiteId(siteId);

  final String siteId;

  @override
  String get identity => 'bigo:$siteId:live';
}
