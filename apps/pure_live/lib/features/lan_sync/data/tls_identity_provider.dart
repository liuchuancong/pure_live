import 'dart:convert' show base64Decode, base64Encode;
import 'dart:math' show Random;
import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pointycastle/ecc/api.dart' show ECPoint;
import 'package:pointycastle/ecc/curves/prime256v1.dart' show ECCurve_prime256v1;
import 'package:pointycastle/export.dart' as pc;

/// This device's long-term TLS identity: an EC P-256 self-signed
/// certificate generated once and kept forever.
///
/// Only the private key's PKCS#8 DER is persisted (in the host's secure
/// storage); the certificate is rebuilt from the key on every load —
/// deterministically, through RFC 6979 signing — so the same key and device
/// name always yield the same DER and the fingerprint a peer pinned at
/// pairing stays valid.
abstract final class DeviceTlsIdentity {
  static const SecureKey _identityKey = SecureKey('tls/identity');

  /// Loads the identity, generating and persisting one on first boot.
  /// Idempotent; every call agrees.
  static Future<TlsIdentity> ensure({
    required SecureCredentialStore credentials,
    required String deviceName,
    Random? random,
  }) async {
    final existing = await credentials.read(_identityKey);
    if (existing != null && existing.isNotEmpty) {
      return build(deviceName: deviceName, fromBundle: existing);
    }
    final identity = build(deviceName: deviceName, random: random);
    await credentials.write(_identityKey, keyBundle(identity));
    return identity;
  }

  /// Builds a fresh identity, or rebuilds one from [fromBundle] — the bytes
  /// `keyBundle` produced. Tests may seed [random]; production leaves it to
  /// `Random.secure`.
  ///
  /// Throws a [LanSyncError] with `configuration` when [fromBundle] is not
  /// a readable PKCS#8 EC key.
  static TlsIdentity build({required String deviceName, Random? random, List<int>? fromBundle}) {
    final name = deviceName.isEmpty ? 'device' : deviceName;
    try {
      final (privateKey, domain) = fromBundle == null ? _generate(random) : _readPkcs8(fromBundle);
      final d = privateKey.d;
      if (d == null) {
        throw const FormatException('ec key: no scalar');
      }
      final publicKey = domain.G * d;
      if (publicKey == null) {
        throw const FormatException('the generated point is at infinity');
      }
      final certificateDer = _CertificateBuilder(subjectCommonName: name, publicKeyPoint: publicKey).build(privateKey);
      return TlsIdentity.fromPem(
        certificateChainPem: _pem('CERTIFICATE', certificateDer),
        privateKeyPem: _pem('PRIVATE KEY', _writePkcs8(privateKey)),
      );
    } on LanSyncError {
      rethrow;
    } on Object catch (error) {
      throw LanSyncError(
        category: LanSyncErrorCategory.configuration,
        code: 'tls_bundle_invalid',
        message: 'The device TLS material could not be read.',
        debugContext: '$error',
      );
    }
  }

  /// The bytes [ensure] persists: the private key's PKCS#8 DER. The
  /// certificate derives from the key, so the bundle is the key.
  static List<int> keyBundle(TlsIdentity identity) => _derOf(identity.privateKeyPem, 'PRIVATE KEY');

  static (pc.ECPrivateKey, ECCurve_prime256v1) _generate(Random? random) {
    final domain = ECCurve_prime256v1();
    final generator = pc.ECKeyGenerator()
      ..init(pc.ParametersWithRandom(pc.ECKeyGeneratorParameters(domain), _SeededRandom(random)));
    final pair = generator.generateKeyPair();
    return (pair.privateKey as pc.ECPrivateKey, domain);
  }

  static (pc.ECPrivateKey, ECCurve_prime256v1) _readPkcs8(List<int> der) {
    final domain = ECCurve_prime256v1();
    final outer = _DerReader(Uint8List.fromList(der));
    if (outer.readTag() != 0x30) {
      throw const FormatException('pkcs8: not a sequence');
    }
    // PrivateKeyInfo ::= SEQUENCE { version INTEGER 0, algorithm
    // AlgorithmIdentifier, privateKey OCTET STRING } (RFC 5958).
    final reader = _DerReader(outer.readContent())
      ..readTlv() // version
      ..readTlv(); // algorithm
    final (octetTag, octet) = reader.readTlv();
    if (octetTag != 0x04) {
      throw const FormatException('pkcs8: no key octet');
    }
    // ECPrivateKey ::= SEQUENCE { version INTEGER 1, privateKey OCTET
    // STRING, [1] publicKey OPTIONAL } (RFC 5915).
    final ecKey = _DerReader(octet);
    if (ecKey.readTag() != 0x30) {
      throw const FormatException('ec key: not a sequence');
    }
    final fields = _DerReader(ecKey.readContent());
    final (versionTag, versionBody) = fields.readTlv();
    if (versionTag != 0x02 || _positive(versionBody) != BigInt.one) {
      throw const FormatException('ec key: unexpected version');
    }
    final (scalarTag, scalarBody) = fields.readTlv();
    if (scalarTag != 0x04) {
      throw const FormatException('ec key: no scalar');
    }
    return (pc.ECPrivateKey(_positive(scalarBody), domain), domain);
  }

  static List<int> _writePkcs8(pc.ECPrivateKey key) {
    final d = key.d;
    if (d == null) {
      throw const FormatException('ec key: no scalar');
    }
    final scalar = _Der.octetString(_unsignedBytes(d));
    final ecPrivateKey = _Der.sequence([_Der.integer(BigInt.one), scalar]);
    final algorithm = _Der.sequence([
      _Der.oid('1.2.840.10045.2.1'), // id-ecPublicKey
      _Der.oid('1.2.840.10045.3.1.7'), // prime256v1
    ]);
    return _Der.sequence([_Der.integer(BigInt.zero), algorithm, _Der.octetString(ecPrivateKey)]);
  }

  static List<int> _pem(String label, List<int> der) {
    final base = base64Encode(der);
    final lines = <String>[];
    for (var i = 0; i < base.length; i += 64) {
      lines.add(base.substring(i, i + 64 > base.length ? base.length : i + 64));
    }
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n'.codeUnits;
  }

  static List<int> _derOf(List<int> pem, String label) {
    final text = String.fromCharCodes(pem);
    final begin = '-----BEGIN $label-----';
    final end = '-----END $label-----';
    final start = text.indexOf(begin);
    final stop = text.indexOf(end, start + begin.length);
    if (start < 0 || stop < 0) {
      throw const FormatException('no PEM block');
    }
    return base64Decode(text.substring(start + begin.length, stop).replaceAll(RegExp(r'\s'), ''));
  }

  static BigInt _positive(List<int> bytes) =>
      bytes.fold(BigInt.zero, (value, byte) => (value << 8) | BigInt.from(byte));

  static List<int> _unsignedBytes(BigInt value) {
    if (value == BigInt.zero) return <int>[0];
    final bytes = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      bytes.insert(0, (current & BigInt.from(0xFF)).toInt());
      current >>= 8;
    }
    return bytes;
  }
}

/// Builds the self-signed X.509v3 certificate: version 3, a serial derived
/// from the public key, ecdsa-with-SHA256, subject == issuer == the
/// device's CN, ten-year validity, SKI on. Signed with RFC 6979
/// deterministic k, so the DER is a pure function of (key, name).
final class _CertificateBuilder {
  _CertificateBuilder({required this.subjectCommonName, required this.publicKeyPoint});

  final String subjectCommonName;
  final ECPoint publicKeyPoint;

  Uint8List build(pc.ECPrivateKey signer) {
    final tbs = _tbs();
    // The HMAC switches the signer onto its RFC 6979 deterministic-k path;
    // a plain PrivateKeyParameter would demand a SecureRandom (and a fresh
    // k, hence a fresh certificate, on every rebuild).
    final signer_ = pc.ECDSASigner(pc.SHA256Digest(), pc.HMac(pc.SHA256Digest(), 32))
      ..init(true, pc.PrivateKeyParameter<pc.ECPrivateKey>(signer));
    final signature = signer_.generateSignature(tbs) as pc.ECSignature;
    // ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER }.
    final signatureDer = _Der.sequence([_Der.integer(signature.r), _Der.integer(signature.s)]);
    return _Der.sequence([tbs, _algorithm, _Der.bitString(signatureDer)]);
  }

  late final Uint8List _publicKeyBytes = publicKeyPoint.getEncoded(false);

  /// A positive serial derived from the public key.
  late final Uint8List _serial = () {
    final bytes = Uint8List.fromList(crypto.sha256.convert(_publicKeyBytes).bytes.sublist(0, 15))..[0] &= 0x7F;
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return _Der.integer(value);
  }();

  static final Uint8List _algorithm = _Der.sequence([_Der.oid('1.2.840.10045.4.3.2')]);

  /// Name ::= SEQUENCE OF RDN; RDN ::= SET OF AttributeTypeAndValue — the
  /// SET is the layer parsers reject a certificate over when it is missing.
  late final Uint8List _name = _Der.sequence([
    _Der.setOf([
      _Der.sequence([_Der.oid('2.5.4.3'), _Der.utf8String(subjectCommonName)]),
    ]),
  ]);

  static final Uint8List _validity = _Der.sequence([
    _Der.utcTime(DateTime.utc(2026)),
    _Der.utcTime(DateTime.utc(2036)),
  ]);

  late final Uint8List _subjectPublicKeyInfo = _Der.sequence([
    _Der.sequence([_Der.oid('1.2.840.10045.2.1'), _Der.oid('1.2.840.10045.3.1.7')]),
    _Der.bitString(_publicKeyBytes),
  ]);

  late final Uint8List _ski = Uint8List.fromList(crypto.sha256.convert(_publicKeyBytes).bytes.sublist(0, 20));

  Uint8List _tbs() => _Der.sequence([
    _Der.context(0, _Der.integer(BigInt.two)), // version: v3
    _serial,
    _algorithm,
    _name,
    _validity,
    _name,
    _subjectPublicKeyInfo,
    _Der.context(
      3,
      _Der.sequence([
        _Der.sequence([_Der.oid('2.5.29.14'), _Der.octetString(_Der.octetString(_ski))]),
      ]),
    ),
  ]);
}

/// A minimal DER writer for the shapes this file builds.
abstract final class _Der {
  static Uint8List sequence(List<Uint8List> children) => _container(0x30, children);

  static Uint8List setOf(List<Uint8List> children) => _container(0x31, children);

  static Uint8List integer(BigInt value) {
    if (value == BigInt.zero) return encode(0x02, <int>[0]);
    final bytes = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      bytes.insert(0, (current & BigInt.from(0xFF)).toInt());
      current >>= 8;
    }
    if (bytes.first & 0x80 != 0) bytes.insert(0, 0);
    return encode(0x02, bytes);
  }

  static Uint8List oid(String dotted) {
    final parts = dotted.split('.').map(int.parse).toList(growable: false);
    final content = <int>[parts[0] * 40 + parts[1]];
    for (final part in parts.skip(2)) {
      if (part < 0x80) {
        content.add(part);
        continue;
      }
      final chunk = <int>[];
      var value = part;
      while (value > 0) {
        chunk.insert(0, value & 0x7F);
        value >>= 7;
      }
      for (var i = 0; i < chunk.length - 1; i++) {
        content.add(chunk[i] | 0x80);
      }
      content.add(chunk.last);
    }
    return encode(0x06, content);
  }

  static Uint8List bitString(List<int> bytes) => encode(0x03, <int>[0, ...bytes]);

  static Uint8List octetString(List<int> bytes) => encode(0x04, bytes);

  static Uint8List utf8String(String text) => encode(0x0C, text.codeUnits);

  static Uint8List utcTime(DateTime time) {
    final utc = time.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return encode(
      0x17,
      '${two(utc.year % 100)}${two(utc.month)}${two(utc.day)}'
              '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z'
          .codeUnits,
    );
  }

  static Uint8List context(int number, Uint8List content) => encode(0xA0 | number, content);

  static Uint8List encode(int tag, List<int> content) {
    final builder = BytesBuilder(copy: false)
      ..add([tag])
      ..add(_length(content.length))
      ..add(content);
    return builder.takeBytes();
  }

  static Uint8List _container(int tag, List<Uint8List> children) {
    final builder = BytesBuilder(copy: false);
    children.forEach(builder.add);
    return encode(tag, builder.takeBytes());
  }

  static List<int> _length(int length) {
    if (length < 0x80) return <int>[length];
    final bytes = <int>[];
    var value = length;
    while (value > 0) {
      bytes.insert(0, value & 0xFF);
      value >>= 8;
    }
    return <int>[0x80 | bytes.length, ...bytes];
  }
}

/// A cursor over DER bytes: reads tag-length-value triples (a private copy
/// of the reader music_sync's codec carries, keeping the feature folder
/// self-contained).
final class _DerReader {
  _DerReader(this.buffer);

  final Uint8List buffer;
  var _offset = 0;

  int readTag() => buffer[_offset++];

  Uint8List readContent() {
    var length = buffer[_offset++];
    if (length & 0x80 != 0) {
      final bytes = length & 0x7F;
      length = 0;
      for (var i = 0; i < bytes; i++) {
        length = (length << 8) | buffer[_offset++];
      }
    }
    final content = Uint8List.sublistView(buffer, _offset, _offset + length);
    _offset += length;
    return content;
  }

  (int, Uint8List) readTlv() {
    final tag = readTag();
    final content = readContent();
    return (tag, content);
  }
}

/// pointycastle's `SecureRandom` over the caller's [Random]: production
/// passes `Random.secure` (the default), tests a fixed seed for
/// reproducibility.
final class _SeededRandom implements pc.SecureRandom {
  _SeededRandom([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String get algorithmName => 'live_lan_sync.seeded';

  @override
  void seed(pc.CipherParameters params) {}

  @override
  Uint8List nextBytes(int count) => Uint8List.fromList([for (var i = 0; i < count; i++) _random.nextInt(256)]);

  @override
  int nextUint8() => _random.nextInt(256);

  @override
  int nextUint16() => (_random.nextInt(256) << 8) | _random.nextInt(256);

  @override
  int nextUint32() => (nextUint16() << 16) | nextUint16();

  @override
  BigInt nextBigInteger(int bitLength) {
    var value = BigInt.zero;
    for (var i = 0; i < bitLength; i += 8) {
      value = (value << 8) | BigInt.from(_random.nextInt(256));
    }
    return value;
  }
}
