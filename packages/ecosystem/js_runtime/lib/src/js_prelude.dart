// Module: lib/src/js_prelude.dart
// Purpose: The host-side bootstrap every JS plugin runs under, before its own code.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/js-plugin.md sections 2-3. The prelude defines the `PureLive` object a plugin sees and
// nothing else: there is no `fetch`, no timers beyond what the engine grants, and no direct host handle. Every
// host reach goes through the fjs bridge as one JSON request, which is what keeps the plugin-sized vocabulary
// (PluginNetwork / kv / log) the only thing a script can touch. Capability calls dispatch over a JSON string
// boundary on purpose: structured object conversion across the bridge is where type confusion would enter.

/// The bootstrap source. Evaluated once per sandbox, before the plugin's own script.
const String jsHostPrelude = '''
var __PureLive = (function () {
  'use strict';
  var registrations = [];

  function callApi(api, payload) {
    var request = { api: api, payload: payload === undefined ? null : payload };
    return fjs.bridge_call(request).then(function (reply) {
      if (reply && reply.error) {
        throw new Error(String(reply.error));
      }
      return reply ? reply.result : undefined;
    });
  }

  var PureLive = {
    registerPlugin: function (definition) {
      if (!definition || typeof definition !== 'object') {
        throw new Error('registerPlugin expects a plugin definition object');
      }
      registrations.push(definition);
    },
    // Every request crosses the host's PluginNetwork: host allowlist, timeout and size limits apply there.
    http: function (options) {
      return callApi('http', options);
    },
    kv: {
      get: function (key) { return callApi('kv.get', { key: key }); },
      set: function (key, value) { return callApi('kv.set', { key: key, value: value === undefined ? null : value }); },
      remove: function (key) { return callApi('kv.remove', { key: key }); },
      keys: function () { return callApi('kv.keys', {}); },
    },
    log: function (level, message) {
      return callApi('log', { level: String(level || 'info'), message: String(message) });
    },
    manifest: function () { return callApi('manifest', {}); },
  };

  return {
    api: PureLive,
    registrations: function () { return registrations; },
    // One registration per plugin script is the documented shape, but the
    // dispatch walks them in order instead of assuming it.
    dispatch: async function (capability, method, argsJson) {
      var args = argsJson ? JSON.parse(argsJson) : undefined;
      for (var index = 0; index < registrations.length; index++) {
        var group = registrations[index][capability];
        if (group && typeof group[method] === 'function') {
          var result = await group[method](args);
          return JSON.stringify(result === undefined ? null : result);
        }
      }
      throw new Error('no registration implements ' + capability + '.' + method);
    },
    describes: function () {
      return JSON.stringify(registrations.map(function (definition) {
        var capabilityNames = [];
        for (var name in definition) {
          if (Object.prototype.hasOwnProperty.call(definition, name) && name !== 'manifest') {
            capabilityNames.push(name);
          }
        }
        return { manifest: definition.manifest || {}, capabilityNames: capabilityNames };
      }));
    },
  };
})();
''';

/// The public name plugin code binds through: `PureLive.registerPlugin({...})`.
const String jsGlobalName = '__PureLive';
