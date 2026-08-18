import CoreImage
import Foundation
import Vision

/// Extracts raw content bytes from a QR code's error-corrected payload.
///
/// Apple's Vision framework does not expose the decoded payload bytes directly
/// for most barcode formats. This parser reads the QR bit stream from
/// `CIQRCodeDescriptor.errorCorrectedPayload` and extracts bytes from
/// Byte-mode (0x04) segments.
///
/// When this parser returns `nil` (e.g. for Numeric or Alphanumeric mode QR
/// codes), the caller falls back to the ISO-Latin-1 round-trip on
/// `payloadStringValue`, which correctly recovers ASCII bytes for those modes.
///
/// **Limitations, see README for full details:**
/// - Kanji mode (0x08) is not yet supported and will cause this parser to
///   return `nil`, falling through to the Latin-1 fallback which cannot
///   round-trip Japanese characters.
/// - Aztec, DataMatrix, and PDF417 are handled separately via the ISO-Latin-1
///   round-trip in the plugin, which has its own constraints.
enum BarcodePayloadParser {

    static func parseQRPayload(from descriptor: CIQRCodeDescriptor) -> Data? {
        let payload = descriptor.errorCorrectedPayload
        let version = descriptor.symbolVersion

        // Character count indicator size for Byte mode:
        //   QR version  1–9:  8 bits
        //   QR version 10–40: 16 bits
        let countBits = version > 9 ? 16 : 8

        var stream = BitStream(data: payload)
        var result = Data()

        while stream.bitsRemaining >= 4 {
            guard let mode = stream.readBits(4) else { break }

            switch mode {
            case 0x0: // Terminator
                return result.isEmpty ? nil : result

            case 0x4: // Byte mode
                guard let count = stream.readBits(countBits),
                      let bytes = stream.readBytes(count) else { return nil }
                result.append(bytes)

            default:
                // Numeric (0x1), Alphanumeric (0x2), Kanji (0x8), ECI (0x7),
                // Structured Append (0x3), etc. are not supported.
                // Return whatever Byte-mode bytes were collected so far.
                return result.isEmpty ? nil : result
            }
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - BitStream

    private struct BitStream {
        private let data: Data
        private var bitOffset: Int = 0

        init(data: Data) {
            self.data = data
        }

        var bitsRemaining: Int {
            return data.count * 8 - bitOffset
        }

        mutating func readBits(_ count: Int) -> Int? {
            guard count > 0, bitsRemaining >= count else { return nil }
            var value = 0
            for _ in 0..<count {
                let byteIndex = bitOffset / 8
                let bitIndex = 7 - (bitOffset % 8)
                if (data[byteIndex] >> bitIndex) & 1 == 1 {
                    value = (value << 1) | 1
                } else {
                    value = value << 1
                }
                bitOffset += 1
            }
            return value
        }

        mutating func readBytes(_ count: Int) -> Data? {
            guard bitsRemaining >= count * 8 else { return nil }
            var result = Data(capacity: count)
            for _ in 0..<count {
                guard let byte = readBits(8) else { return nil }
                result.append(UInt8(byte))
            }
            return result
        }
    }
}
