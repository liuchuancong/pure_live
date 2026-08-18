package dev.steenbakker.mobile_scanner.objects

enum class BarcodeFormats(val intValue: Int) {
    UNKNOWN(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_UNKNOWN),
    ALL_FORMATS(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_ALL_FORMATS),
    CODE_128(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_CODE_128),
    CODE_39(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_CODE_39),
    CODE_93(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_CODE_93),
    CODABAR(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_CODABAR),
    DATA_MATRIX(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_DATA_MATRIX),
    EAN_13(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_EAN_13),
    EAN_8(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_EAN_8),
    ITF(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_ITF),
    QR_CODE(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_QR_CODE),
    UPC_A(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_UPC_A),
    UPC_E(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_UPC_E),
    PDF417(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_PDF417),
    AZTEC(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_AZTEC);

    companion object {
        fun fromRawValue(rawValue: Int): BarcodeFormats {
            return when(rawValue) {
                -1 -> UNKNOWN
                0 -> ALL_FORMATS
                1 -> CODE_128
                2 -> CODE_39
                4 -> CODE_93
                8 -> CODABAR
                16 -> DATA_MATRIX
                32 -> EAN_13
                64 -> EAN_8
                126, 127, 128 -> ITF
                256 -> QR_CODE
                512 -> UPC_A
                1024 -> UPC_E
                2048 -> PDF417
                4096 -> AZTEC
                else -> UNKNOWN
            }
        }
    }
}