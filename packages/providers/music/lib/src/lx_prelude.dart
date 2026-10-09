// Module: lib/src/lx_prelude.dart
// Purpose: The lx-music user-api environment injected before a source script.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: lx-music-desktop src/main/modules/userApi/renderer/preload.js. The
// script sees `lx` (EVENT_NAMES / request / send / on / utils / env) exactly
// as the desktop exposes it; everything heavy - http, crypto, zlib - crosses
// the sandbox bridge, so the permission ceiling holds for music sources too.
// The Buffer emulation covers the encodings lx sources actually use (utf8,
// base64, hex, latin1); anything else fails naming the encoding, not silently
// corrupting bytes.

const String lxApiPrelude = r'''
var __LxBytes = (function () {
  'use strict';
  var b64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function utf8Encode(str) {
    var out = [];
    for (var i = 0; i < str.length; i++) {
      var code = str.charCodeAt(i);
      if (code < 0x80) out.push(code);
      else if (code < 0x800) out.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      else if (code >= 0xd800 && code <= 0xdbff && i + 1 < str.length) {
        var next = str.charCodeAt(++i);
        var cp = 0x10000 + ((code & 0x3ff) << 10) + (next & 0x3ff);
        out.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3f), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
      } else out.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    }
    return out;
  }

  function utf8Decode(bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; ) {
      if (bytes[i] < 0x80) { out += String.fromCharCode(bytes[i++]); }
      else if (bytes[i] < 0xe0) { out += String.fromCharCode(((bytes[i++] & 0x1f) << 6) | (bytes[i++] & 0x3f)); }
      else if (bytes[i] < 0xf0) {
        out += String.fromCharCode(((bytes[i++] & 0x0f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f));
      } else {
        var cp = ((bytes[i++] & 0x07) << 18) | ((bytes[i++] & 0x3f) << 12) | ((bytes[i++] & 0x3f) << 6) | (bytes[i++] & 0x3f);
        cp -= 0x10000;
        out += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
      }
    }
    return out;
  }

  function b64Encode(bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; i += 3) {
      var b0 = bytes[i], b1 = bytes[i + 1], b2 = bytes[i + 2];
      out += b64Chars[b0 >> 2];
      out += b64Chars[((b0 & 3) << 4) | ((b1 === undefined ? 0 : b1) >> 4)];
      out += b1 === undefined ? '=' : b64Chars[((b1 & 15) << 2) | ((b2 === undefined ? 0 : b2) >> 6)];
      out += b2 === undefined ? '=' : b64Chars[b2 & 63];
    }
    return out;
  }

  function b64Decode(text) {
    var clean = String(text).replace(/[^A-Za-z0-9+/]/g, '');
    var out = [];
    for (var i = 0; i < clean.length; i += 4) {
      var n = [0, 2, 1], b = [0, 0, 0];
      for (var j = 0; j < 4; j++) {
        var ch = clean[i + j];
        var v = ch === undefined ? 0 : b64Chars.indexOf(ch);
        b[0] |= v << (18 - j * 6);
        b[1] = (b[0] >> 8) & 255;
        b[2] = (b[0] >> 16) & 255;
      }
      for (var k = 0; k < n[i / 4 | 0]; k++) out.push((b[0] >> (16 - k * 8)) & 255);
    }
    return out;
  }

  function hexEncode(bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; i++) out += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
    return out;
  }

  function hexDecode(text) {
    var out = [];
    for (var i = 0; i + 1 < text.length; i += 2) out.push(parseInt(text.substr(i, 2), 16));
    return out;
  }

  function latin1Decode(bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; i++) out += String.fromCharCode(bytes[i]);
    return out;
  }

  return {
    utf8Encode: utf8Encode,
    utf8Decode: utf8Decode,
    b64Encode: b64Encode,
    b64Decode: b64Decode,
    hexEncode: hexEncode,
    hexDecode: hexDecode,
    latin1Decode: latin1Decode,
  };
})();

var __LxBuffer = (function () {
  'use strict';
  function normalize(value) {
    if (value && value.__isLxBuffer) return value.bytes;
    if (value instanceof Uint8Array) return Array.prototype.slice.call(value);
    return null;
  }

  function LxBuffer(bytes) {
    this.__isLxBuffer = true;
    this.bytes = bytes || [];
    this.length = this.bytes.length;
  }

  LxBuffer.prototype.toString = function (encoding) {
    var enc = (encoding || 'utf8').toLowerCase();
    if (enc === 'utf8' || enc === 'utf-8') return __LxBytes.utf8Decode(this.bytes);
    if (enc === 'base64') return __LxBytes.b64Encode(this.bytes);
    if (enc === 'hex') return __LxBytes.hexEncode(this.bytes);
    if (enc === 'latin1' || enc === 'binary' || enc === 'ascii') return __LxBytes.latin1Decode(this.bytes);
    throw new Error('lx buffer: unsupported encoding ' + encoding);
  };

  LxBuffer.from = function (value, encoding) {
    if (value && value.__isLxBuffer) return new LxBuffer(value.bytes.slice());
    if (value instanceof Uint8Array || Array.isArray(value)) return new LxBuffer(Array.prototype.slice.call(value));
    var enc = (encoding || 'utf8').toLowerCase();
    if (enc === 'utf8' || enc === 'utf-8') return new LxBuffer(__LxBytes.utf8Encode(String(value)));
    if (enc === 'base64') return new LxBuffer(__LxBytes.b64Decode(String(value)));
    if (enc === 'hex') return new LxBuffer(__LxBytes.hexDecode(String(value)));
    if (enc === 'latin1' || enc === 'binary' || enc === 'ascii') {
      var out = [];
      for (var i = 0; i < String(value).length; i++) out.push(String(value).charCodeAt(i) & 0xff);
      return new LxBuffer(out);
    }
    throw new Error('lx buffer.from: unsupported encoding ' + encoding);
  };

  return LxBuffer;
})();

var Buffer = __LxBuffer;

var __LxState = {
  events: { request: null },
  inited: false,
  apiInfo: null,
  updateAlertShown: false,
};

var __LxInvoke = {
  // The host calls this with {data:{action, source, info}}; the script's
  // handler answers through its callback, mirroring the desktop's two-arg
  // (params, callback) shape.
  request: function (payloadJson) {
    return new Promise(function (resolve) {
      if (!__LxState.events.request) {
        resolve(JSON.stringify({ __error__: 'request handler not registered' }));
        return;
      }
      var payload = JSON.parse(payloadJson);
      var settled = false;
      var timer = setTimeout(function () {
        if (!settled) {
          settled = true;
          resolve(JSON.stringify({ __error__: 'source handler timeout' }));
        }
      }, 30000);
      try {
        __LxState.events.request(payload.data, function (err, result) {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          resolve(JSON.stringify(err ? { __error__: String(err.message || err) } : { result: result === undefined ? null : result }));
        });
      } catch (err) {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(JSON.stringify({ __error__: String(err && err.message ? err.message : err) }));
        }
      }
    });
  },
};

var lx = (function () {
  'use strict';
  var EVENT_NAMES = { request: 'request', inited: 'inited', updateAlert: 'updateAlert' };

  function callApi(api, payload) {
    return fjs.bridge_call({ api: api, payload: payload === undefined ? null : payload }).then(function (reply) {
      if (reply && reply.error) throw new Error(String(reply.error));
      return reply ? reply.result : undefined;
    });
  }

  return {
    EVENT_NAMES: EVENT_NAMES,
    version: '2.0.0',
    env: 'desktop',
    request: function (url, options, callback) {
      options = options || {};
      callApi('http', {
        method: options.method || 'GET',
        url: String(url),
        headers: options.headers || {},
        timeoutMs: typeof options.timeout === 'number' && options.timeout > 0 ? Math.min(options.timeout, 60000) : 60000,
      }).then(function (r) {
        var text = (r && r.bodyText) || '';
        var body = text;
        try { body = JSON.parse(text); } catch (_) {}
        var response = { statusCode: (r && r.statusCode) || 0, headers: (r && r.headers) || {}, body: body };
        callback(null, response, body);
      }).catch(function (error) {
        callback(error, null, null);
      });
      return function () {};
    },
    send: function (name, data) {
      if (name === EVENT_NAMES.inited) {
        if (__LxState.inited) return Promise.reject(new Error('Script is inited'));
        __LxState.inited = true;
        __LxState.apiInfo = data || {};
        return callApi('lx.inited', data || {});
      }
      if (name === EVENT_NAMES.updateAlert) {
        if (__LxState.updateAlertShown) return Promise.reject(new Error('The update alert can only be called once.'));
        __LxState.updateAlertShown = true;
        return callApi('lx.updateAlert', data || {});
      }
      return Promise.reject(new Error('The event is not supported: ' + name));
    },
    on: function (name, handler) {
      if (name !== EVENT_NAMES.request) {
        return Promise.reject(new Error('The event is not supported: ' + name));
      }
      __LxState.events.request = handler;
      return Promise.resolve();
    },
    utils: {
      crypto: {
        md5: function (str) { return callApi('crypto.md5', { text: String(str) }); },
        randomBytes: function (size) {
          return callApi('crypto.randomBytes', { size: size }).then(function (b64) { return Buffer.from(b64, 'base64'); });
        },
        aesEncrypt: function (buffer, mode, key, iv) {
          return callApi('crypto.aesEncrypt', {
            dataB64: __LxBytes.b64Encode(normalizeBytes(buffer)),
            mode: String(mode),
            keyB64: __LxBytes.b64Encode(normalizeBytes(key)),
            ivB64: iv === undefined ? '' : __LxBytes.b64Encode(normalizeBytes(iv)),
          }).then(function (b64) { return Buffer.from(b64, 'base64'); });
        },
        rsaEncrypt: function (buffer, key) {
          return callApi('crypto.rsaEncrypt', {
            dataB64: __LxBytes.b64Encode(normalizeBytes(buffer)),
            key: String(key),
          }).then(function (b64) { return Buffer.from(b64, 'base64'); });
        },
      },
      buffer: {
        from: function () { return Buffer.from.apply(Buffer, arguments); },
        bufToString: function (buf, format) { return Buffer.from(buf, 'binary').toString(format || 'utf8'); },
      },
      zlib: {
        inflate: function (buf) {
          return callApi('zlib.inflate', { dataB64: __LxBytes.b64Encode(normalizeBytes(buf)) })
            .then(function (b64) { return Buffer.from(b64, 'base64'); });
        },
        deflate: function (data) {
          return callApi('zlib.deflate', { dataB64: __LxBytes.b64Encode(normalizeBytes(data)) })
            .then(function (b64) { return Buffer.from(b64, 'base64'); });
        },
      },
    },
    currentScriptInfo: globalThis.__LxScriptInfo || {},
  };

  function normalizeBytes(value) {
    if (value && value.__isLxBuffer) return value.bytes;
    if (value instanceof Uint8Array) return Array.prototype.slice.call(value);
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') return __LxBytes.utf8Encode(value);
    throw new Error('expected a Buffer');
  }
})();

globalThis.__lx_dispatch_request = __LxInvoke.request;
''';

/// The name of the dispatcher the host evaluates against.
const String lxDispatchName = '__lx_dispatch_request';
