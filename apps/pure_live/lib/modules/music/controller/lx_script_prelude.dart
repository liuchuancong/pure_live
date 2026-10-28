/// The JavaScript surface a lx-music source script expects.
///
/// HTTP is bridged to Dart through `fjs.bridge_call`; buffers, MD5 and zlib
/// use the Node-compatible builtins fjs enables. AES and RSA are implemented
/// here because fjs' crypto builtin follows the Web Crypto API rather than
/// Node's cipher interface, while `lx.utils.crypto` is synchronous.
///
/// The AES/RSA code is the desktop client's semantics: AES-128 CBC/ECB with
/// PKCS#7 padding, and raw RSA (no padding, left-zero-padded to the modulus)
/// over a PEM, base64 DER or DER public key.
const String lxScriptPrelude = r'''
(() => {
  const state = { handler: null, seq: 0 };
  let nodeBuffer = globalThis.Buffer;
  let nodeCrypto = globalThis.crypto || null;
  let zlibModule = null;
  let zlibLoading = null;
  try { if (!nodeBuffer) nodeBuffer = require('buffer').Buffer; } catch (_) {}
  try { if (!nodeCrypto) nodeCrypto = require('crypto'); } catch (_) {}
  const zlibOf = () => {
    if (zlibModule) return Promise.resolve(zlibModule);
    if (!zlibLoading) {
      zlibLoading = Promise.resolve()
        .then(() => import('zlib'))
        .then((module) => (zlibModule = module.default || module))
        .catch((error) => {
          zlibLoading = null;
          throw error;
        });
    }
    return zlibLoading;
  };

  const fail = (message) => { throw new Error(message); };
  const bufferOf = (input, encoding) => {
    if (!nodeBuffer) fail('Buffer is unavailable');
    return nodeBuffer.from(input, encoding);
  };
  globalThis.window = globalThis;
  globalThis.self = globalThis;
  globalThis.btoa = (value) => {
    const text = '' + value;
    const bytes = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i) & 0xff;
    return bufferOf(bytes).toString('base64');
  };
  globalThis.atob = (value) => {
    const bytes = bufferOf('' + value, 'base64');
    let text = '';
    for (let i = 0; i < bytes.length; i++) text += String.fromCharCode(bytes[i]);
    return text;
  };
  const cryptoOf = () => {
    if (!nodeCrypto) fail('crypto is unavailable');
    return nodeCrypto;
  };
  const bridge = (payload) => fjs.bridge_call(payload);

  const SBOX = new Uint8Array([
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ]);
  const RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36];
  const xtime = (a) => ((a << 1) ^ ((a & 0x80) ? 0x1b : 0)) & 0xff;
  const mul = (a, b) => {
    let r = 0;
    while (b) {
      if (b & 1) r ^= a;
      a = xtime(a);
      b >>= 1;
    }
    return r & 0xff;
  };
  const expandKey = (key) => {
    const w = new Uint8Array(176);
    w.set(key);
    for (let i = 16; i < 176; i += 4) {
      let t0 = w[i - 4], t1 = w[i - 3], t2 = w[i - 2], t3 = w[i - 1];
      if (i % 16 === 0) {
        const first = t0;
        t0 = SBOX[t1] ^ RCON[i / 16 - 1];
        t1 = SBOX[t2];
        t2 = SBOX[t3];
        t3 = SBOX[first];
      }
      w[i] = w[i - 16] ^ t0;
      w[i + 1] = w[i - 15] ^ t1;
      w[i + 2] = w[i - 14] ^ t2;
      w[i + 3] = w[i - 13] ^ t3;
    }
    return w;
  };
  const encryptBlock = (input, w, offset, out, outOffset) => {
    const s = new Uint8Array(16);
    for (let i = 0; i < 16; i++) s[i] = input[offset + i] ^ w[i];
    const t = new Uint8Array(16);
    for (let round = 1; round <= 10; round++) {
      for (let c = 0; c < 4; c++) {
        for (let r = 0; r < 4; r++) t[4 * c + r] = SBOX[s[4 * ((c + r) % 4) + r]];
      }
      if (round < 10) {
        for (let c = 0; c < 4; c++) {
          const a0 = t[4 * c], a1 = t[4 * c + 1], a2 = t[4 * c + 2], a3 = t[4 * c + 3];
          s[4 * c] = mul(a0, 2) ^ mul(a1, 3) ^ a2 ^ a3;
          s[4 * c + 1] = a0 ^ mul(a1, 2) ^ mul(a2, 3) ^ a3;
          s[4 * c + 2] = a0 ^ a1 ^ mul(a2, 2) ^ mul(a3, 3);
          s[4 * c + 3] = mul(a0, 3) ^ a1 ^ a2 ^ mul(a3, 2);
        }
      } else {
        s.set(t);
      }
      const keyOffset = round * 16;
      for (let i = 0; i < 16; i++) s[i] ^= w[keyOffset + i];
    }
    for (let i = 0; i < 16; i++) out[outOffset + i] = s[i];
  };
  const aesEncrypt = (data, mode, key, iv) => {
    if (mode !== 'aes-128-cbc' && mode !== 'aes-128-ecb') fail('Unsupported AES mode: ' + mode);
    const keyBytes = bufferOf(key);
    if (keyBytes.length !== 16) fail('AES key must be 16 bytes');
    const input = bufferOf(data);
    const pad = 16 - (input.length % 16);
    const padded = new Uint8Array(input.length + pad);
    padded.set(input);
    padded.fill(pad, input.length);
    const w = expandKey(keyBytes);
    const out = new Uint8Array(padded.length);
    const cbc = mode === 'aes-128-cbc';
    let prev = cbc ? bufferOf(iv) : null;
    if (cbc && prev.length !== 16) fail('AES iv must be 16 bytes');
    for (let offset = 0; offset < padded.length; offset += 16) {
      if (cbc) {
        for (let i = 0; i < 16; i++) padded[offset + i] ^= prev[i];
      }
      encryptBlock(padded, w, offset, out, offset);
      if (cbc) prev = out.subarray(offset, offset + 16);
    }
    return bufferOf(out);
  };

  if (typeof BigInt !== 'function') fail('BigInt is unavailable');
  const parseTlv = (bytes, offset) => {
    let pos = offset;
    const tag = bytes[pos++];
    let length = bytes[pos++];
    if (length & 0x80) {
      const count = length & 0x7f;
      length = 0;
      for (let i = 0; i < count; i++) length = length * 256 + bytes[pos++];
    }
    return { tag, start: pos, end: pos + length };
  };
  const bytesToBig = (bytes) => {
    let value = 0n;
    for (let i = 0; i < bytes.length; i++) value = (value << 8n) | BigInt(bytes[i]);
    return value;
  };
  const bigToBytes = (value, length) => {
    const out = new Uint8Array(length);
    let current = value;
    for (let i = length - 1; i >= 0; i--) {
      out[i] = Number(current & 0xffn);
      current >>= 8n;
    }
    return out;
  };
  const modPow = (base, exponent, modulus) => {
    let result = 1n;
    let square = base % modulus;
    let power = exponent;
    while (power > 0n) {
      if (power & 1n) result = (result * square) % modulus;
      square = (square * square) % modulus;
      power >>= 1n;
    }
    return result;
  };
  const rsaNumbers = (der, offset) => {
    const sequence = parseTlv(der, offset);
    if (sequence.tag !== 0x30) fail('RSA key is not a sequence');
    const modulus = parseTlv(der, sequence.start);
    if (modulus.tag !== 0x02) fail('RSA modulus is missing');
    const exponent = parseTlv(der, modulus.end);
    if (exponent.tag !== 0x02) fail('RSA exponent is missing');
    return {
      n: bytesToBig(der.subarray(modulus.start, modulus.end)),
      e: bytesToBig(der.subarray(exponent.start, exponent.end)),
    };
  };
  const rsaKey = (key) => {
    let der;
    if (typeof key === 'string') {
      const body = key
        .replace(/-----BEGIN [^-]+-----/g, '')
        .replace(/-----END [^-]+-----/g, '')
        .replace(/\s+/g, '');
      der = bufferOf(body, 'base64');
    } else {
      der = bufferOf(key);
    }
    const outer = parseTlv(der, 0);
    if (outer.tag !== 0x30) fail('RSA key is not DER');
    const first = parseTlv(der, outer.start);
    if (first.tag === 0x02) return rsaNumbers(der, 0);
    if (first.tag !== 0x30) fail('RSA key header is unknown');
    const bits = parseTlv(der, first.end);
    if (bits.tag !== 0x03) fail('RSA key bits are missing');
    let start = bits.start;
    if (der[start] === 0) start++;
    return rsaNumbers(der, start);
  };
  const rsaEncrypt = (data, key) => {
    const { n, e } = rsaKey(key);
    const size = Math.ceil(n.toString(16).length / 2);
    let input = bufferOf(data);
    if (input.length > size) fail('RSA input is too large');
    if (input.length < size) input = nodeBuffer.concat([nodeBuffer.alloc(size - input.length), input]);
    return bufferOf(bigToBytes(modPow(bytesToBig(input), e, n), size));
  };

  globalThis.__lxInvoke = async (payload) => {
    if (typeof state.handler !== 'function') fail('Request event is not defined');
    return await state.handler({ source: payload.source, action: payload.action, info: payload.info });
  };

  globalThis.lx = {
    EVENT_NAMES: { inited: 'inited', request: 'request', updateAlert: 'updateAlert' },
    version: '2.0.0',
    env: 'desktop',
    currentScriptInfo: {},
    on(event, handler) {
      if (event !== 'request') return Promise.reject(new Error('The event is not supported: ' + event));
      state.handler = handler;
      return Promise.resolve();
    },
    send(event, data) {
      if (event !== 'inited' && event !== 'updateAlert') {
        return Promise.reject(new Error('The event is not supported: ' + event));
      }
      return bridge({ kind: 'send', event, data }).then(() => undefined);
    },
    request(url, options, callback) {
      const id = 'lx' + (++state.seq);
      let cancelled = false;
      bridge({ kind: 'http', id, url, options: options || {} })
        .then((result) => {
          if (cancelled || !result || result.cancelled) return;
          if (result.error) return callback(new Error(result.error), null, null);
          let body = result.body;
          if (typeof body === 'string') {
            try { body = JSON.parse(body); } catch (_) {}
          }
          const response = result.response || null;
          if (response) {
            response.raw = result.body;
            response.bytes = result.body;
            response.body = body;
          }
          callback(null, response, body);
        })
        .catch((error) => {
          if (!cancelled) callback(error, null, null);
        });
      return () => {
        cancelled = true;
        bridge({ kind: 'cancel', id });
      };
    },
    utils: {
      buffer: {
        from(input, encoding) { return bufferOf(input, encoding); },
        bufToString(buf, format) {
          const target = format === 'binary' ? 'latin1' : (format || 'utf8');
          return bufferOf(buf).toString(target);
        },
      },
      crypto: {
        md5(str) {
          if (typeof str !== 'string') fail('param required a string');
          return cryptoOf().createHash('md5').update(str).digest('hex');
        },
        randomBytes(size) { return cryptoOf().randomBytes(size); },
        aesEncrypt(buffer, mode, key, iv) { return aesEncrypt(buffer, mode, key, iv); },
        rsaEncrypt(buffer, key) { return rsaEncrypt(buffer, key); },
      },
      zlib: {
        inflate(buf) {
          return zlibOf().then(
            (zlib) =>
              new Promise((resolve, reject) => {
                zlib.inflate(bufferOf(buf), (error, data) => (error ? reject(error) : resolve(data)));
              }),
          );
        },
        deflate(data) {
          return zlibOf().then(
            (zlib) =>
              new Promise((resolve, reject) => {
                zlib.deflate(bufferOf(data), (error, buffer) => (error ? reject(error) : resolve(buffer)));
              }),
          );
        },
      },
    },
  };
})();
''';
