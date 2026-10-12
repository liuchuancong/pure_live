import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// A Hive CE adapter that bridges a JSON-backed model through its
/// `toJson`/`fromJson`.
///
/// Business packages store their models as typed values with one of
/// these per model, registered at bootstrap through the adapter
/// registry. Two paths lead here:
///
/// - a hand-constructed `JsonBoxAdapter(TipoId.fromJson, (v) => v.toJson())`
///   for models that already speak JSON (freezed + json_serializable);
/// - the `hive_ce_generator` output when a model carries `@HiveType`
///   annotations — run `dart run build_runner build
///   --delete-conflicting-outputs` in the owning package and register
///   its generated registrar the same way.
///
/// Type ids are a workspace-wide registry: assign them once, in one
/// place, and never renumber an id that has shipped.
final class JsonBoxAdapter<T> extends TypeAdapter<T> {
  /// An adapter for [typeId] bridging [T] through JSON.
  const new(this.typeId, {required this.toJson, required this.fromJson});

  @override
  final int typeId;

  /// Serializes the model to its JSON document.
  final Map<String, Object?> Function(T value) toJson;

  /// Restores the model from its JSON document.
  final T Function(Map<String, Object?> json) fromJson;

  @override
  T read(BinaryReader reader) => fromJson(jsonDecode(reader.readString()) as Map<String, Object?>);

  @override
  void write(BinaryWriter writer, T value) => writer.writeString(jsonEncode(toJson(value)));
}
