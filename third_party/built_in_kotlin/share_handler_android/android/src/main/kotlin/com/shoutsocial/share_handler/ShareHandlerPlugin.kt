package com.shoutsocial.share_handler

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap

import androidx.annotation.NonNull
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.URLConnection
import java.util.UUID

private const val kEventsChannel = "com.shoutsocial.share_handler/sharedMediaStream"
private const val MAX_ATTACHMENT_NAME_BYTES = 180
private const val MAX_ATTACHMENT_EXTENSION_BYTES = 24

/** ShareHandlerPlugin */
class ShareHandlerPlugin : FlutterPlugin, Messages.ShareHandlerApi, EventChannel.StreamHandler, ActivityAware,
  PluginRegistry.NewIntentListener {
  private var initialMedia: Messages.SharedMedia? = null
  private var eventChannel: EventChannel? = null
  private var eventSink: EventChannel.EventSink? = null

  private var binding: ActivityPluginBinding? = null
  private lateinit var applicationContext: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext

    val messenger = flutterPluginBinding.binaryMessenger
    Messages.ShareHandlerApi.setup(messenger, this)

    eventChannel = EventChannel(messenger, kEventsChannel)
    eventChannel?.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    Messages.ShareHandlerApi.setup(binding.binaryMessenger, null)
  }

//  override fun getInitialSharedMedia(result: Result<SharedMedia>?) {
//    result?.let { _result -> {
//      initialMedia?.let { _media -> _result.success(_media) }
//    } }
//  }

//  override fun recordSentMessage(media: SharedMedia) {
//    val packageName = applicationContext.packageName
//    val shortcutTarget = "$packageName.dynamic_share_target"
//    val shortcutBuilder = ShortcutInfoCompat.Builder(applicationContext, media.conversationIdentifier ?: "").setShortLabel(media.speakableGroupName ?: "Unknown")
//      .setIsConversation()
//      .setCategories(setOf(shortcutTarget))
//      .setIntent(Intent(Intent.ACTION_DEFAULT))
//      .setLongLived(true)
//
//    val personBuilder = Person.Builder()
//      .setKey(media.conversationIdentifier)
//      .setName(media.speakableGroupName)
//
//    media.imageFilePath?.let {
//      val bitmap = BitmapFactory.decodeFile(it)
//      val icon = IconCompat.createWithAdaptiveBitmap(bitmap)
//      shortcutBuilder.setIcon(icon)
//      personBuilder.setIcon(icon)
//    }
//
//    val person = personBuilder.build()
//    shortcutBuilder.setPerson(person)
//
//    val shortcut = shortcutBuilder.build()
//
//    ShortcutManagerCompat.addDynamicShortcuts(applicationContext, listOf(shortcut))
//  }

  override fun getInitialSharedMedia(result: Messages.Result<Messages.SharedMedia>?) {
    result?.success(initialMedia)
  }

  override fun recordSentMessage(media: Messages.SharedMedia) {
    val packageName = applicationContext.packageName
    val intent = Intent(applicationContext, Class.forName("$packageName.MainActivity")).apply {
      action = Intent.ACTION_SEND
      putExtra("conversationIdentifier", media.conversationIdentifier)
    }
    val shortcutTarget = "$packageName.dynamic_share_target"
    val shortcutBuilder = ShortcutInfoCompat.Builder(applicationContext, media.conversationIdentifier ?: "")
      .setShortLabel(media.speakableGroupName ?: "Unknown")
      .setIsConversation()
      .setCategories(setOf(shortcutTarget))
      .setIntent(intent)
      .setLongLived(true)

    val personBuilder = Person.Builder()
      .setKey(media.conversationIdentifier)
      .setName(media.speakableGroupName)

    media.imageFilePath?.let {
      val bitmap = BitmapFactory.decodeFile(it)
      val icon = IconCompat.createWithAdaptiveBitmap(bitmap)
      shortcutBuilder.setIcon(icon)
      personBuilder.setIcon(icon)
    }

    val person = personBuilder.build()
    shortcutBuilder.setPerson(person)

    val shortcut = shortcutBuilder.build()

    ShortcutManagerCompat.addDynamicShortcuts(applicationContext, listOf(shortcut))
  }

  override fun resetInitialSharedMedia() {
    initialMedia = null
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addOnNewIntentListener(this)
    val flags: Int = binding.activity.intent.flags
    if ((flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) {
      // The activity was launched from history
      Log.w("TAG", "Handle skip: The activity was launched from history")
    } else {
      handleIntent(binding.activity.intent, true)
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    binding?.removeOnNewIntentListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addOnNewIntentListener(this)
  }

  override fun onDetachedFromActivity() {
    binding?.removeOnNewIntentListener(this)
  }

  override fun onNewIntent(intent: Intent): Boolean {
    handleIntent(intent, false)
    return false
  }

  private fun handleIntent(intent: Intent, initial: Boolean) {
    val attachments: List<Messages.SharedAttachment>? = try {
      attachmentsFromIntent(intent)
    } catch (e: Exception) {
      Log.e("TAG", "Error parsing attachments", e)
      null
    }

    val text: String? = when (intent.action) {
      Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> intent.getStringExtra(Intent.EXTRA_TEXT)
      else -> null
    }

    val conversationIdentifier = intent.getStringExtra("android.intent.extra.shortcut.ID")
      ?: intent.getStringExtra("conversationIdentifier")

    if (attachments != null || text != null || conversationIdentifier != null) {
      val mediaBuilder = Messages.SharedMedia.Builder()
      attachments?.let { mediaBuilder.setAttachments(it) }
      text?.let { mediaBuilder.setContent(it) }
      conversationIdentifier?.let { mediaBuilder.setConversationIdentifier(it) }
      val media = mediaBuilder.build()

      if (initial) {
        synchronized(this) {
          initialMedia = media
        }
      }

      if (eventSink != null) {
        eventSink?.success(media.toMap())
      } else {
        Log.w("TAG", "EventSink is not available")
      }
    }
  }

  private fun attachmentsFromIntent(intent: Intent?): List<Messages.SharedAttachment>? {
    if (intent == null) return null
    return when (intent.action) {
      Intent.ACTION_SEND -> {
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
        return listOf(attachmentForUri(uri)).mapNotNull { it }
      }

      Intent.ACTION_SEND_MULTIPLE -> {
        val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        val value = uris?.mapNotNull { uri ->
          attachmentForUri(uri)
        }?.toList()
        return value
      }

      else -> null
    }
  }

  private fun attachmentForUri(uri: Uri): Messages.SharedAttachment? {
    var attachmentDirectory: File? = null
    return try {
      val contentResolver = applicationContext.contentResolver
      val mimeType = contentResolver.getType(uri)
      val type = getAttachmentType(mimeType)

      // A file URI may already point to app-owned storage. Content URIs must be
      // copied while their transient grant is active: resolving them to an
      // external-storage path breaks under scoped storage on current Android.
      if (uri.scheme.equals("file", ignoreCase = true)) {
        val directFile = uri.path?.let(::File)
        if (directFile?.isFile == true && directFile.canRead()) {
          return Messages.SharedAttachment.Builder()
            .setPath(directFile.absolutePath)
            .setType(type)
            .build()
        }
      }

      val displayName = getFileNameFromUri(contentResolver, uri, mimeType) ?: return null
      val safeName = safeAttachmentFileName(displayName, mimeType)
      val stagingRoot = File(applicationContext.cacheDir, "share_handler")
      val directory = File(stagingRoot, UUID.randomUUID().toString())
      attachmentDirectory = directory
      if (!directory.mkdirs()) return null
      val copiedFile = File(directory, safeName)
      if (!copyFile(contentResolver, uri, copiedFile)) {
        copiedFile.delete()
        directory.delete()
        return null
      }
      Messages.SharedAttachment.Builder()
        .setPath(copiedFile.absolutePath)
        .setType(type)
        .build()
    } catch (error: Exception) {
      attachmentDirectory?.let { directory -> runCatching { directory.deleteRecursively() } }
      Log.e("ShareHandler", "Shared URI attachment failed", error)
      null
    }
  }

  private fun safeAttachmentFileName(displayName: String, mimeType: String?): String {
    val leaf = displayName.substringAfterLast('/').substringAfterLast('\\').trim()
    val fallbackExtension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "bin"
    val sanitizedLeaf = buildString(leaf.length) {
      leaf.forEach { character ->
        append(if (character.code < 0x20 || character.code == 0x7f) '_' else character)
      }
    }
    val candidate = sanitizedLeaf.takeIf { it.isNotEmpty() && it != "." && it != ".." }
      ?: "file_${System.currentTimeMillis()}.$fallbackExtension"
    if (candidate.toByteArray(Charsets.UTF_8).size <= MAX_ATTACHMENT_NAME_BYTES) return candidate

    val originalExtension = candidate.substringAfterLast('.', "")
    val extension = truncateUtf8(originalExtension, MAX_ATTACHMENT_EXTENSION_BYTES)
    val suffix = if (extension.isEmpty()) "" else ".$extension"
    val rawBase = if (originalExtension.isEmpty()) candidate else candidate.dropLast(originalExtension.length + 1)
    val baseBudget = MAX_ATTACHMENT_NAME_BYTES - suffix.toByteArray(Charsets.UTF_8).size
    val base = truncateUtf8(rawBase, baseBudget).ifEmpty { "file" }
    return base + suffix
  }

  private fun truncateUtf8(value: String, maxBytes: Int): String {
    if (maxBytes <= 0) return ""
    val result = StringBuilder()
    var usedBytes = 0
    var offset = 0
    while (offset < value.length) {
      val codePoint = Character.codePointAt(value, offset)
      val segment = String(Character.toChars(codePoint))
      val segmentBytes = segment.toByteArray(Charsets.UTF_8).size
      if (usedBytes + segmentBytes > maxBytes) break
      result.append(segment)
      usedBytes += segmentBytes
      offset += Character.charCount(codePoint)
    }
    return result.toString()
  }

  // Function to get the file name from the URI
  private fun getFileNameFromUri(contentResolver: ContentResolver, uri: Uri, mimeType: String?): String? {
    var fileName: String? = null
    try {
      val cursor = contentResolver.query(uri, null, null, null, null)
      cursor?.use { c ->
        if (c.moveToFirst()) {
          val nameIndex = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
          if (nameIndex != -1) {
            fileName = c.getString(nameIndex)
          }
        }
      }
    } catch (e: Exception) {
      Log.w("ShareHandler", "Shared URI display name query failed", e)
    }

    if (fileName.isNullOrBlank()) {
      fileName = uri.lastPathSegment?.substringAfterLast('/')
    }
    if (fileName.isNullOrBlank()) {
      var fallbackName = "file_${System.currentTimeMillis()}"
      mimeType?.let {
        val fallbackExtension = MimeTypeMap.getSingleton().getExtensionFromMimeType(it)
        if (fallbackExtension != null) {
          fallbackName += ".$fallbackExtension"
        }
      }
      fileName = fallbackName
    }
    return fileName
  }

  // Function to copy the file content from the URI to the destination file
  private fun copyFile(contentResolver: ContentResolver, uri: Uri, destinationFile: File): Boolean {
    return try {
      val inputStream = contentResolver.openInputStream(uri) ?: return false
      inputStream.use { input ->
        FileOutputStream(destinationFile).use { outputStream ->
          val buffer = ByteArray(8 * 1024) // 8KB buffer
          var bytesRead: Int
          while (input.read(buffer).also { bytesRead = it } != -1) {
            outputStream.write(buffer, 0, bytesRead)
          }
        }
      }
      true
    } catch (e: Exception) {
      Log.e("ShareHandler", "Shared URI copy failed", e)
      false
    }
  }

  // Function to determine the attachment type using the MIME type
  private fun getAttachmentType(mimeType: String?): Messages.SharedAttachmentType {
    return when {
      mimeType?.startsWith("image") == true -> Messages.SharedAttachmentType.image
      mimeType?.startsWith("video") == true -> Messages.SharedAttachmentType.video
      mimeType?.startsWith("audio") == true -> Messages.SharedAttachmentType.audio
      else -> Messages.SharedAttachmentType.file
    }
  }
}
