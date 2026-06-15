package com.example.rephoto

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import java.io.File
import java.util.Locale

class ExternalImportService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val itemsJson = intent?.getStringExtra(extraItems) ?: return START_NOT_STICKY
        val albumName = intent.getStringExtra(extraAlbumName)
        val albumRelativePath = intent.getStringExtra(extraAlbumRelativePath)
        val useSystemLibrary = intent.getBooleanExtra(extraUseSystemLibrary, false)
        val items = JSONArray(itemsJson)
        startForegroundNotification(0, items.length())
        Thread {
            val importedIds = mutableListOf<String>()
            val failedIds = mutableListOf<String>()
            for (index in 0 until items.length()) {
                val item = items.getJSONObject(index)
                val id = item.optString("id")
                try {
                    ExternalImportCopier.importMedia(
                        this,
                        item.getString("sourceUri"),
                        item.getString("displayName"),
                        item.optString("type"),
                        albumName,
                        albumRelativePath,
                        useSystemLibrary,
                    )
                    importedIds.add(id)
                } catch (_: Exception) {
                    failedIds.add(id)
                }
                val completed = index + 1
                writeStatus(this, true, items.length(), completed, importedIds, failedIds)
                updateNotification(completed, items.length())
            }
            writeStatus(this, false, items.length(), items.length(), importedIds, failedIds)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf(startId)
        }.start()
        return START_NOT_STICKY
    }

    private fun startForegroundNotification(completed: Int, total: Int) {
        ServiceCompat.startForeground(
            this,
            notificationId,
            buildNotification(completed, total),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            } else {
                0
            },
        )
    }

    private fun updateNotification(completed: Int, total: Int) {
        getSystemService(NotificationManager::class.java)
            .notify(notificationId, buildNotification(completed, total))
    }

    private fun buildNotification(completed: Int, total: Int) =
        NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("正在导入照片")
            .setContentText("$completed/$total")
            .setProgress(total, completed, false)
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            notificationChannelId,
            "照片导入",
            NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val prefsName = "rephoto_external_import"
        private const val statusRunning = "background_import_running"
        private const val statusTotal = "background_import_total"
        private const val statusCompleted = "background_import_completed"
        private const val statusImportedIds = "background_import_imported_ids"
        private const val statusFailedIds = "background_import_failed_ids"
        private const val notificationChannelId = "rephoto_import"
        private const val notificationId = 4301
        private const val extraItems = "items"
        private const val extraAlbumName = "albumName"
        private const val extraAlbumRelativePath = "albumRelativePath"
        private const val extraUseSystemLibrary = "useSystemLibrary"

        fun start(
            context: Context,
            items: List<Map<String, Any?>>,
            albumName: String?,
            albumRelativePath: String?,
            useSystemLibrary: Boolean,
        ): Boolean {
            if (items.isEmpty()) return false
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            if (prefs.getBoolean(statusRunning, false)) return true
            writeStatus(context, true, items.size, 0, emptyList(), emptyList())
            val json = JSONArray()
            for (item in items) {
                json.put(org.json.JSONObject(item))
            }
            val intent = Intent(context, ExternalImportService::class.java).apply {
                putExtra(extraItems, json.toString())
                putExtra(extraAlbumName, albumName)
                putExtra(extraAlbumRelativePath, albumRelativePath)
                putExtra(extraUseSystemLibrary, useSystemLibrary)
            }
            ContextCompat.startForegroundService(context, intent)
            return true
        }

        fun readStatus(context: Context): Map<String, Any> {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            return mapOf(
                "running" to prefs.getBoolean(statusRunning, false),
                "totalCount" to prefs.getInt(statusTotal, 0),
                "completedCount" to prefs.getInt(statusCompleted, 0),
                "importedIds" to prefs.getStringSet(statusImportedIds, emptySet()).orEmpty().toList(),
                "failedIds" to prefs.getStringSet(statusFailedIds, emptySet()).orEmpty().toList(),
            )
        }

        private fun writeStatus(
            context: Context,
            running: Boolean,
            total: Int,
            completed: Int,
            importedIds: Collection<String>,
            failedIds: Collection<String>,
        ) {
            context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(statusRunning, running)
                .putInt(statusTotal, total)
                .putInt(statusCompleted, completed)
                .putStringSet(statusImportedIds, importedIds.toSet())
                .putStringSet(statusFailedIds, failedIds.toSet())
                .apply()
        }
    }
}

private object ExternalImportCopier {
    private const val prefsName = "rephoto_external_import"
    private const val importFingerprintPrefix = "imported_v1_"

    fun importMedia(
        context: Context,
        sourceUriValue: String,
        displayName: String,
        requestedType: String?,
        albumName: String?,
        albumRelativePath: String?,
        useSystemLibrary: Boolean,
    ): String {
        val sourceUri = Uri.parse(sourceUriValue)
        val sourceMime = context.contentResolver.getType(sourceUri)
            ?: mimeTypeFromName(displayName)
            ?: if (requestedType == "video") "video/mp4" else "image/jpeg"
        val mediaType = if (requestedType == "video" || sourceMime.startsWith("video/")) "video" else "photo"
        val safeName = sanitizeDisplayName(displayName, mediaType)
        val collection = if (mediaType == "video") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
            put(MediaStore.MediaColumns.MIME_TYPE, sourceMime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath(mediaType, albumName, albumRelativePath, useSystemLibrary))
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val destinationUri = context.contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create MediaStore item")
        try {
            val input = if (sourceUri.scheme == "file") {
                File(sourceUri.path ?: "").inputStream()
            } else {
                context.contentResolver.openInputStream(sourceUri)
            }
            input.use {
                context.contentResolver.openOutputStream(destinationUri).use { output ->
                    if (it == null || output == null) throw IllegalStateException("Unable to open import streams")
                    it.copyTo(output)
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                context.contentResolver.update(
                    destinationUri,
                    ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                    null,
                    null,
                )
            }
            rememberImported(context, sourceUri, displayName)
            return destinationUri.toString()
        } catch (error: Exception) {
            context.contentResolver.delete(destinationUri, null, null)
            throw error
        }
    }

    private fun relativePath(
        mediaType: String,
        albumName: String?,
        albumRelativePath: String?,
        useSystemLibrary: Boolean,
    ): String {
        val baseDir = if (mediaType == "video") Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
        if (useSystemLibrary) return baseDir
        albumRelativePath?.trim()?.trim('/')?.takeIf { it.isNotBlank() }?.let { return it }
        return "$baseDir/${albumName?.trim()?.trim('/')?.takeIf { it.isNotBlank() } ?: "RePhoto"}"
    }

    private fun mimeTypeFromName(displayName: String): String? {
        val extension = displayName.substringAfterLast('.', "").lowercase(Locale.US)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: when (extension) {
                "dng" -> "image/x-adobe-dng"
                "nef" -> "image/x-nikon-nef"
                "nrw" -> "image/x-nikon-nrw"
                "cr2" -> "image/x-canon-cr2"
                "cr3" -> "image/x-canon-cr3"
                "arw" -> "image/x-sony-arw"
                "rw2" -> "image/x-panasonic-rw2"
                "orf" -> "image/x-olympus-orf"
                "raf" -> "image/x-fuji-raf"
                "pef" -> "image/x-pentax-pef"
                "srw" -> "image/x-samsung-srw"
                else -> null
            }
    }

    private fun sanitizeDisplayName(displayName: String, mediaType: String): String {
        val fallback = if (mediaType == "video") "RePhoto-import.mp4" else "RePhoto-import.jpg"
        return File(displayName).name.trim().takeIf { it.isNotEmpty() }?.replace(Regex("[\\\\/:*?\"<>|]"), "_") ?: fallback
    }

    private fun rememberImported(context: Context, sourceUri: Uri, displayName: String) {
        val size = queryDocumentLong(context, sourceUri, DocumentsContract.Document.COLUMN_SIZE)
        val modified = queryDocumentLong(context, sourceUri, DocumentsContract.Document.COLUMN_LAST_MODIFIED) ?: 0L
        val fingerprint = listOf(displayName.trim().lowercase(Locale.US), size?.toString() ?: "", modified.toString())
            .joinToString("|")
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("$importFingerprintPrefix$fingerprint", true)
            .apply()
    }

    private fun queryDocumentLong(context: Context, uri: Uri, columnName: String): Long? {
        if (uri.scheme == "file") {
            val file = File(uri.path ?: return null)
            return if (columnName == DocumentsContract.Document.COLUMN_SIZE) file.length() else file.lastModified()
        }
        return try {
            context.contentResolver.query(uri, arrayOf(columnName), null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(columnName)
                if (index < 0 || cursor.isNull(index)) null else cursor.getLong(index)
            }
        } catch (_: Exception) {
            null
        }
    }
}
