// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DesktopPreferences _$DesktopPreferencesFromJson(Map<String, dynamic> json) =>
    _DesktopPreferences(
      closeAction: json['closeAction'] == null
          ? CloseAction.hideToTray
          : _closeActionFromJson(json['closeAction']),
      showTrayIcon: json['showTrayIcon'] as bool? ?? true,
      rememberWindowBounds: json['rememberWindowBounds'] as bool? ?? true,
      launchAtLogin: json['launchAtLogin'] as bool? ?? false,
      startHidden: json['startHidden'] as bool? ?? false,
      reclaimWhenIdle: json['reclaimWhenIdle'] as bool? ?? false,
      idleReclaimAfter: json['idleReclaimAfter'] == null
          ? const Duration(minutes: 30)
          : Duration(microseconds: (json['idleReclaimAfter'] as num).toInt()),
      effects: json['effects'] as bool? ?? true,
      hardwareAcceleration: json['hardwareAcceleration'] as bool? ?? true,
      systemNotifications: json['systemNotifications'] as bool? ?? true,
    );

Map<String, dynamic> _$DesktopPreferencesToJson(_DesktopPreferences instance) =>
    <String, dynamic>{
      'closeAction': _closeActionToJson(instance.closeAction),
      'showTrayIcon': instance.showTrayIcon,
      'rememberWindowBounds': instance.rememberWindowBounds,
      'launchAtLogin': instance.launchAtLogin,
      'startHidden': instance.startHidden,
      'reclaimWhenIdle': instance.reclaimWhenIdle,
      'idleReclaimAfter': instance.idleReclaimAfter.inMicroseconds,
      'effects': instance.effects,
      'hardwareAcceleration': instance.hardwareAcceleration,
      'systemNotifications': instance.systemNotifications,
    };
