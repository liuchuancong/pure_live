package com.mystyle.purelive

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URI
import java.net.URL
import java.util.concurrent.Executors

internal class NativeHttpChannel(binaryMessenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "pure_live/native_http"
        private const val MAX_RESPONSE_BYTES = 8 * 1024 * 1024
        private val DISALLOWED_HEADERS = setOf(
            "accept-encoding",
            "connection",
            "content-length",
            "host",
            "proxy-authorization",
            "proxy-connection",
        )
    }

    private val channel = MethodChannel(binaryMessenger, CHANNEL)
    private val executor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val handler: (MethodCall) -> Map<String, Any> = when (call.method) {
            "postTwitchJson" -> ::executeTwitchPost
            // Cloudflare rejects dart:io's TLS fingerprint on every kick.com API
            // endpoint (403); Android's platform TLS stack is accepted.
            "getKickJson" -> ::executeKickGet
            else -> {
                result.notImplemented()
                return
            }
        }
        executor.execute {
            try {
                val response = handler(call)
                mainHandler.post { result.success(response) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "native_http_failed",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    private fun executeKickGet(call: MethodCall): Map<String, Any> {
        val urlValue = call.argument<String>("url") ?: error("Missing URL")
        val uri = URI(urlValue)
        require(uri.scheme.equals("https", ignoreCase = true) && uri.host.equals("kick.com", ignoreCase = true)) {
            "Native HTTP host is not allowed"
        }
        val connection = openConnection(call, urlValue).apply {
            requestMethod = "GET"
            doOutput = false
        }
        try {
            applyHeaders(connection, call.argument<Map<*, *>>("headers").orEmpty())
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            val responseBody = stream?.use { readBoundedUtf8(it) }.orEmpty()
            return mapOf("statusCode" to statusCode, "body" to responseBody)
        } finally {
            connection.disconnect()
        }
    }

    private fun openConnection(call: MethodCall, urlValue: String): HttpURLConnection {
        val timeoutMillis = (call.argument<Number>("timeoutMillis")?.toInt() ?: 20_000).coerceIn(1_000, 60_000)
        val proxyHost = call.argument<String>("proxyHost")?.trim().orEmpty()
        val proxyPort = call.argument<Number>("proxyPort")?.toInt() ?: 0
        val proxy = if (proxyHost.isNotEmpty() && proxyPort in 1..65_535) {
            Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved(proxyHost, proxyPort))
        } else {
            Proxy.NO_PROXY
        }
        return (URL(urlValue).openConnection(proxy) as HttpURLConnection).apply {
            connectTimeout = timeoutMillis
            readTimeout = timeoutMillis
            instanceFollowRedirects = false
            useCaches = false
            doInput = true
        }
    }

    private fun applyHeaders(connection: HttpURLConnection, headers: Map<*, *>) {
        for ((rawName, rawValue) in headers) {
            val name = rawName?.toString()?.trim().orEmpty()
            val value = rawValue?.toString().orEmpty()
            if (name.isEmpty() || name.lowercase() in DISALLOWED_HEADERS || value.contains('\r') || value.contains('\n')) {
                continue
            }
            connection.setRequestProperty(name, value)
        }
    }

    private fun executeTwitchPost(call: MethodCall): Map<String, Any> {
        val urlValue = call.argument<String>("url") ?: error("Missing URL")
        val uri = URI(urlValue)
        require(uri.scheme.equals("https", ignoreCase = true) && uri.host.equals("gql.twitch.tv", ignoreCase = true)) {
            "Native HTTP host is not allowed"
        }
        val timeoutMillis = (call.argument<Number>("timeoutMillis")?.toInt() ?: 20_000).coerceIn(1_000, 60_000)
        val proxyHost = call.argument<String>("proxyHost")?.trim().orEmpty()
        val proxyPort = call.argument<Number>("proxyPort")?.toInt() ?: 0
        val proxy = if (proxyHost.isNotEmpty() && proxyPort in 1..65_535) {
            Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved(proxyHost, proxyPort))
        } else {
            Proxy.NO_PROXY
        }
        val connection = (URL(urlValue).openConnection(proxy) as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = timeoutMillis
            readTimeout = timeoutMillis
            instanceFollowRedirects = false
            useCaches = false
            doInput = true
            doOutput = true
        }
        try {
            val headers = call.argument<Map<*, *>>("headers").orEmpty()
            for ((rawName, rawValue) in headers) {
                val name = rawName?.toString()?.trim().orEmpty()
                val value = rawValue?.toString().orEmpty()
                if (name.isEmpty() || name.lowercase() in DISALLOWED_HEADERS || value.contains('\r') || value.contains('\n')) {
                    continue
                }
                connection.setRequestProperty(name, value)
            }
            if (connection.getRequestProperty("Content-Type").isNullOrEmpty()) {
                connection.setRequestProperty("Content-Type", "application/json")
            }
            val body = call.argument<String>("body").orEmpty().toByteArray(Charsets.UTF_8)
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }

            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            val responseBody = stream?.use { readBoundedUtf8(it) }.orEmpty()
            return mapOf("statusCode" to statusCode, "body" to responseBody)
        } finally {
            connection.disconnect()
        }
    }

    private fun readBoundedUtf8(input: java.io.InputStream): String {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            require(total <= MAX_RESPONSE_BYTES) { "Native HTTP response exceeded 8 MiB" }
            output.write(buffer, 0, read)
        }
        return output.toString(Charsets.UTF_8.name())
    }
}
