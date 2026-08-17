package dev.steenbakker.mobile_scanner

import android.graphics.ImageFormat
import android.graphics.Point
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import com.google.mlkit.vision.barcode.common.Barcode
import java.io.ByteArrayOutputStream

fun Image.toByteArray(): ByteArray {
    val yBuffer = planes[0].buffer // Y
    val vuBuffer = planes[2].buffer // VU

    val ySize = yBuffer.remaining()
    val vuSize = vuBuffer.remaining()

    val nv21 = ByteArray(ySize + vuSize)

    yBuffer.get(nv21, 0, ySize)
    vuBuffer.get(nv21, ySize, vuSize)

    val yuvImage = YuvImage(nv21, ImageFormat.NV21, this.width, this.height, null)
    val out = ByteArrayOutputStream()
    yuvImage.compressToJpeg(Rect(0, 0, yuvImage.width, yuvImage.height), 50, out)
    return out.toByteArray()
}

val Barcode.data: Map<String, Any?>
    get() = mapOf(
        "calendarEvent" to calendarEvent?.data,
        "contactInfo" to contactInfo?.data,
        "corners" to cornerPoints?.map { corner -> corner.data },
        "displayValue" to displayValue,
        "driverLicense" to driverLicense?.data,
        "email" to email?.data,
        "format" to format,
        "geoPoint" to geoPoint?.data,
        "phone" to phone?.data,
        "rawBytes" to rawBytes,
        "rawValue" to rawValue,
        "size" to boundingBox?.size,
        "sms" to sms?.data,
        "type" to valueType,
        "url" to url?.data,
        "wifi" to wifi?.data,
    )

private val Point.data: Map<String, Double>
    get() = mapOf("x" to x.toDouble(), "y" to y.toDouble())

private val Barcode.CalendarEvent.data: Map<String, Any?>
    get() = mapOf(
        "description" to description, "end" to end?.rawValue, "location" to location,
        "organizer" to organizer, "start" to start?.rawValue, "status" to status,
        "summary" to summary
    )

private val Barcode.ContactInfo.data: Map<String, Any?>
    get() = mapOf(
        "addresses" to addresses.map { address -> address.data },
        "emails" to emails.map { email -> email.data }, "name" to name?.data,
        "organization" to organization, "phones" to phones.map { phone -> phone.data },
        "title" to title, "urls" to urls
    )

private val Barcode.Address.data: Map<String, Any?>
    get() = mapOf(
        "addressLines" to addressLines.map { addressLine -> addressLine.toString() },
        "type" to type
    )

private val Barcode.PersonName.data: Map<String, Any?>
    get() = mapOf(
        "first" to first, "formattedName" to formattedName, "last" to last,
        "middle" to middle, "prefix" to prefix, "pronunciation" to pronunciation,
        "suffix" to suffix
    )

private val Barcode.DriverLicense.data: Map<String, Any?>
    get() = mapOf(
        "addressCity" to addressCity, "addressState" to addressState,
        "addressStreet" to addressStreet, "addressZip" to addressZip, "birthDate" to birthDate,
        "documentType" to documentType, "expiryDate" to expiryDate, "firstName" to firstName,
        "gender" to gender, "issueDate" to issueDate, "issuingCountry" to issuingCountry,
        "lastName" to lastName, "licenseNumber" to licenseNumber, "middleName" to middleName
    )

private val Barcode.Email.data: Map<String, Any?>
    get() = mapOf("address" to address, "body" to body, "subject" to subject, "type" to type)

private val Barcode.GeoPoint.data: Map<String, Any?>
    get() = mapOf("latitude" to lat, "longitude" to lng)

private val Barcode.Phone.data: Map<String, Any?>
    get() = mapOf("number" to number, "type" to type)

private val Barcode.Sms.data: Map<String, Any?>
    get() = mapOf("message" to message, "phoneNumber" to phoneNumber)

private val Barcode.UrlBookmark.data: Map<String, Any?>
    get() = mapOf("title" to title, "url" to url)

private val Barcode.WiFi.data: Map<String, Any?>
    get() = mapOf("encryptionType" to encryptionType, "password" to password, "ssid" to ssid)

private val Rect.size: Map<String, Any?>
    get() {
        // Rect.isValid can't be accessed for some reason, so just do the check manually.
        if (left <= right && top <= bottom) {
            return mapOf("width" to width().toDouble(), "height" to height().toDouble())
        }

        return emptyMap()
    }