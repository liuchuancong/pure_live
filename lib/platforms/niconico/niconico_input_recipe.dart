import 'package:pure_live/core/interface/live_input_recipe.dart';

import 'niconico_watch.dart';

final class NiconicoInputRecipe implements LiveInputRecipe {
  NiconicoInputRecipe({required String programId, required this.resolution, this.bandwidth})
    : programId = NiconicoWatch.validateProgramId(programId) {
    if (bandwidth != null && (resolution == null || bandwidth! <= 0)) {
      throw ArgumentError('A positive bandwidth selector requires an explicit resolution');
    }
  }

  final String programId;
  final String? resolution;
  final int? bandwidth;

  @override
  String get identity => 'niconico:$programId:${resolution ?? 'auto'}:${bandwidth ?? 'auto'}';
}
