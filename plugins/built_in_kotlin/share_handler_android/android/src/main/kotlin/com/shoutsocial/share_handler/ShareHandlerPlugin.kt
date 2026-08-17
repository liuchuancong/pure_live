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

private const val kEventsChannel = "com.shoutsocial.share_handler/sharedMediaStream"

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
    val contentResolver = applicationContext.contentResolver

    // Obtain the MIME type of the URI
    val mimeType = contentResolver.getType(uri)

    // Get the absolute path from the URI
    val path = FileDirectory.getAbsolutePath(applicationContext, uri) ?: return null

    val file = File(path)

    // Check if the file name has an extension
    if (file.extension.isNotEmpty()) {
      // File has an extension; use it directly
      val type = getAttachmentType(mimeType)
      return Messages.SharedAttachment.Builder()
        .setPath(file.absolutePath)
        .setType(type)
        .build()
    } else {
      // File does not have an extension; copy it to cache with the correct extension

      // Obtain the file name from the URI, including extension
      val fileName = getFileNameFromUri(contentResolver, uri, mimeType) ?: return null

      // Create a new file in the cache directory with the correct file name
      val newFile = File(applicationContext.cacheDir, fileName)

      // Copy the contents from the URI to the new file
      val success = copyFile(contentResolver, uri, newFile)
      if (!success) {
        return null
      }

      // Determine the attachment type using the MIME type
      val type = getAttachmentType(mimeType)

      // Return the attachment with the path to the copied file
      return Messages.SharedAttachment.Builder()
        .setPath(newFile.absolutePath)
        .setType(type)
        .build()
    }
  }

  // Function to get the file name from the URI
  private fun getFileNameFromUri(contentResolver: ContentResolver, uri: Uri, mimeType: String?): String? {
    var fileName: String? = null
    val cursor = contentResolver.query(uri, null, null, null, null)
    cursor?.use { c ->
      if (c.moveToFirst()) {
        val nameIndex = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        if (nameIndex != -1) {
          fileName = c.getString(nameIndex)
        }
      }
    }

    // If the file name couldn't be obtained, generate one
    if (fileName == null) {
      fileName = "file_${System.currentTimeMillis()}"
      // Add extension if possible
      mimeType?.let {
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(it)
        if (extension != null) {
          fileName += ".$extension"
        }
      }
    }

    return fileName
  }

  // Function to copy the file content from the URI to the destination file
  private fun copyFile(contentResolver: ContentResolver, uri: Uri, destinationFile: File): Boolean {
    return try {
      contentResolver.openInputStream(uri)?.use { inputStream ->
        FileOutputStream(destinationFile).use { outputStream ->
          val buffer = ByteArray(8 * 1024) // 8KB buffer
          var bytesRead: Int
          while (inputStream.read(buffer).also { bytesRead = it } != -1) {
            outputStream.write(buffer, 0, bytesRead)
          }
        }
      }
      true
    } catch (e: Exception) {
      e.printStackTrace()
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
