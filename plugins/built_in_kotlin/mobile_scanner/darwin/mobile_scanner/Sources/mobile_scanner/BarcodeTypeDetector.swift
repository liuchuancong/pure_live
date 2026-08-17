import Foundation

/// Extension to detect barcode type from raw string value using heuristics.
/// This matches the behavior of MLKit's valueType property.
extension String {
    /// Detects the barcode type from the raw string value using heuristic pattern matching.
    /// Returns the raw integer value matching the BarcodeType enum (0-12).
    ///
    /// Detection order matters - more specific patterns are checked first.
    ///
    /// If any error occurs during detection, returns 0 (BarcodeType.unknown).
    func detectBarcodeType() -> Int {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Return unknown if empty
        if trimmed.isEmpty {
            return 0 // BarcodeType.unknown
        }
        
        let uppercased = trimmed.uppercased()
        
        // Check for ContactInfo (VCARD) - most specific structured format
        if uppercased.hasPrefix("BEGIN:VCARD") {
            return 1 // BarcodeType.contactInfo
        }
    
        // Check for CalendarEvent (VCALENDAR) - iCalendar format
        if uppercased.hasPrefix("BEGIN:VCALENDAR") {
            return 11 // BarcodeType.calendarEvent
        }
        
        // Check for WiFi
        if uppercased.hasPrefix("WIFI:") {
            return 9 // BarcodeType.wifi
        }
        
        // Check for Email
        if uppercased.hasPrefix("MAILTO:") {
            return 2 // BarcodeType.email
        }
        
        // Check for Phone
        if uppercased.hasPrefix("TEL:") {
            return 4 // BarcodeType.phone
        }
        
        // Check for SMS
        if uppercased.hasPrefix("SMS:") {
            return 6 // BarcodeType.sms
        }
        
        // Check for Geo
        if uppercased.hasPrefix("GEO:") {
            return 10 // BarcodeType.geo
        }
        
        // Check for URL bookmark (MEBKM format)
        if uppercased.hasPrefix("MEBKM:") {
            return 8 // BarcodeType.url
        }
        
        // Check for HTTP/HTTPS URLs
        if uppercased.hasPrefix("HTTP://") || uppercased.hasPrefix("HTTPS://") {
            return 8 // BarcodeType.url
        }
        
        // Check for ISBN
        if isISBN() {
            return 3 // BarcodeType.isbn
        }
        
        // Check for Product codes (EAN/UPC)
        if isProductCode() {
            return 5 // BarcodeType.product
        }
        
        // Default to text for unrecognized patterns
        return 7 // BarcodeType.text
    }
    
    /// Checks if the string matches ISBN-10 or ISBN-13 format.
    /// ISBN-10: 10 digits (with optional hyphens)
    /// ISBN-13: 13 digits starting with 978 or 979 (with optional hyphens)
    private func isISBN() -> Bool {
        // Remove hyphens and spaces for validation
        let digitsOnly = self.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "ISBN", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for ISBN-13 (13 digits, starting with 978 or 979)
        if digitsOnly.count == 13,
           let _ = Int(digitsOnly),
           digitsOnly.hasPrefix("978") || digitsOnly.hasPrefix("979") {
            return true
        }
        
        // Check for ISBN-10 (10 digits)
        if digitsOnly.count == 10,
           let _ = Int(digitsOnly) {
            return true
        }
        
        return false
    }
    
    /// Checks if the string matches product code format (EAN/UPC).
    /// EAN-8: 8 digits
    /// UPC-A: 12 digits
    /// EAN-13: 13 digits
    private func isProductCode() -> Bool {
        // Remove any non-digit characters
        let digitsOnly = self.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Check for EAN-8 (8 digits), UPC-A (12 digits), or EAN-13 (13 digits)
        let length = digitsOnly.count
        if length == 8 || length == 12 || length == 13 {
            // Verify all characters are digits
            return digitsOnly.allSatisfy { $0.isNumber }
        }
        
        return false
    }
}

