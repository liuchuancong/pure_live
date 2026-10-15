package com.purelive.pure_live

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val pool = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pure_live/secret_cipher")
            .setMethodCallHandler { call, result ->
                pool.execute {
                    try {
                        val value = SecretCipherChannel.handle(call)
                        main.post { result.success(value) }
                    } catch (error: Exception) {
                        main.post { result.error("secret_cipher", error.message, null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        pool.shutdown()
        super.onDestroy()
    }
}

/** AES-256-GCM under a non-exportable Android Keystore key; the secret's
 * name is the associated data. */
private object SecretCipherChannel {
    private const val KEY_ALIAS = "pure_live.secrets.v1"
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128

    fun handle(call: MethodCall): Any? = when (call.method) {
        "seal" -> seal(call.argument<String>("ref")!!, call.argument<String>("plain")!!)
        "open" -> open(call.argument<String>("ref")!!, call.argument<ByteArray>("sealed")!!)
        else -> null
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun seal(ref: String, plain: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(ref.toByteArray(Charsets.UTF_8))
        val body = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        return cipher.iv + body
    }

    private fun open(ref: String, sealed: ByteArray): String {
        require(sealed.size > IV_BYTES) { "Sealed value too short" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, sealed, 0, IV_BYTES))
        cipher.updateAAD(ref.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(sealed, IV_BYTES, sealed.size - IV_BYTES), Charsets.UTF_8)
    }
}
