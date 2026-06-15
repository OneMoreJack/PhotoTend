package com.example.rephoto

import android.Manifest
import android.content.ContentValues
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.Uri
import android.location.Geocoder
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Size
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val logTag = "RePhotoMedia"
    private val permissionsChannelName = "rephoto/mobile_permissions"
    private val mediaChannelName = "rephoto/mobile_media"
    private val localStateChannelName = "rephoto/local_state"
    private val externalImportChannelName = "rephoto/external_import"
    private val requestCodeMediaRead = 9201
    private val requestCodeDeleteMedia = 9202
    private val requestCodeImportRoot = 9203
    private val requestCodeImportNotifications = 9204
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingImportRootResult: MethodChannel.Result? = null
    private var pendingImportRootId: String? = null
    private var pendingDeleteIds: Set<String>? = null
    private var pendingExternalDeleteUri: Uri? = null
    private var pendingExternalDeleteUris: List<Uri>? = null
    private var pendingExternalDeletedUris: List<String> = emptyList()
    private var useLegacyPaging = false
    private var legacyMediaSnapshot: List<NativeMediaItem>? = null
    private val locationCachePrefs by lazy {
        getSharedPreferences("rephoto_location_cache", MODE_PRIVATE)
    }
    private val locationCachePrefix = "location_v1_"
    private val aliasCachePrefix = "alias_v1_"
    private val externalImportPrefs by lazy {
        getSharedPreferences("rephoto_external_import", MODE_PRIVATE)
    }
    private val localStatePrefs by lazy {
        getSharedPreferences("rephoto_local_state", MODE_PRIVATE)
    }
    private val deletionPhotoCountKey = "deletion_stats_photo_count"
    private val deletionVideoCountKey = "deletion_stats_video_count"
    private val deletionKnownSizeBytesKey = "deletion_stats_known_size_bytes"
    private val deletionHasUnknownSizeKey = "deletion_stats_has_unknown_size"
    private val browseProgressPrefix = "browse_progress_v1_"
    private val importRootUriKey = "import_root_uri"
    private val importFingerprintPrefix = "imported_v1_"
    private var lastImportDebugInfo: String = "导入诊断：尚未开始扫描。"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestMediaReadPermission" -> requestMediaReadPermission(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "fetchAllMediaItems" -> runAsync(result) { fetchAllMediaItems() }
                    "fetchUserAlbums" -> runAsync(result) { fetchUserAlbums() }
                    "fetchMediaPage" -> {
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 100
                        runAsync(result) { fetchMediaPage(offset, limit).map { it.toMap() } }
                    }
                    "fetchAllIds" -> runAsync(result) { fetchAllMediaIds() }
                    "batchGetLocationKeys" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any?>>>("items")
                        if (items == null || items.isEmpty()) {
                            result.success(emptyMap<String, String>())
                            return@setMethodCallHandler
                        }
                        runAsync(result) {
                            val keys = mutableMapOf<String, String>()
                            for (item in items) {
                                val id = item["id"]?.toString() ?: continue
                                val cached = readCachedLocationKey(id)
                                if (!cached.isNullOrBlank() && hasPreciseCoordinate(cached)) {
                                    keys[id] = cached
                                    continue
                                }
                                val path = item["pathOrUri"]?.toString()
                                val location = resolveReadableLocationKey(path)
                                if (!location.isNullOrBlank()) {
                                    keys[id] = location
                                    writeCachedLocationKey(id, location)
                                }
                            }
                            keys
                        }
                    }
                    "getLocationAliases" -> runAsync(result) { readAllLocationAliases() }
                    "setLocationAlias" -> {
                        val locationKey = call.argument<String>("locationKey")
                        val alias = call.argument<String>("alias")
                        if (locationKey.isNullOrBlank() || alias.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "locationKey/alias is empty", null)
                        } else {
                            locationCachePrefs.edit()
                                .putString("$aliasCachePrefix$locationKey", alias.trim())
                                .apply()
                            result.success(null)
                        }
                    }
                    "removeLocationAlias" -> {
                        val locationKey = call.argument<String>("locationKey")
                        if (locationKey.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            locationCachePrefs.edit()
                                .remove("$aliasCachePrefix$locationKey")
                                .apply()
                            result.success(null)
                        }
                    }
                    "permanentDelete" -> permanentDelete(call, result)
                    "getDeviceModel" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        result.success(readDeviceModelFromExif(pathOrUri))
                    }
                    "batchGetDeviceModels" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any?>>>("items")
                        if (items == null || items.isEmpty()) {
                            result.success(emptyMap<String, String?>())
                            return@setMethodCallHandler
                        }
                        Thread {
                            val models = mutableMapOf<String, Any?>()
                            for (item in items) {
                                val id = item["id"]?.toString() ?: continue
                                val path = item["pathOrUri"]?.toString()
                                models[id] = readDeviceModelFromExif(path)
                            }
                            runOnUiThread { result.success(models) }
                        }.start()
                    }
                    "fetchPreviewImageData" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        if (pathOrUri.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            runAsync(result) { fetchPreviewImageData(pathOrUri) }
                        }
                    }
                    "openInGallery" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        if (pathOrUri != null) {
                            openInGallery(pathOrUri)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "pathOrUri is null", null)
                        }
                    }
                    "shareToTarget" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        val pkg = call.argument<String>("package")
                        val activity = call.argument<String>("activity")
                        if (pathOrUri != null && pkg != null) {
                            shareToTarget(pathOrUri, pkg, activity)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "pathOrUri or package is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localStateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveDeletionStats" -> {
                        val args = call.arguments as? Map<*, *>
                        saveDeletionStats(args)
                        result.success(null)
                    }
                    "loadDeletionStats" -> result.success(loadDeletionStats())
                    "saveBrowseProgress" -> {
                        val args = call.arguments as? Map<*, *>
                        saveBrowseProgress(args)
                        result.success(null)
                    }
                    "loadBrowseProgress" -> {
                        val args = call.arguments as? Map<*, *>
                        result.success(loadBrowseProgress(args))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, externalImportChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSavedImportRoot" -> result.success(readSavedImportRoot())
                    "listImportRoots" -> result.success(listImportRoots())
                    "getImportDebugInfo" -> result.success(lastImportDebugInfo)
                    "requestImportRoot" -> {
                        val rootId = call.argument<String>("rootId")
                        requestImportRoot(result, rootId)
                    }
                    "scanImportRoot" -> {
                        val includeRaw = call.argument<Boolean>("includeRaw") == true
                        runAsync(result) { scanImportRoot(includeRaw).map { it.toMap() } }
                    }
                    "scanImportRootPage" -> {
                        val includeRaw = call.argument<Boolean>("includeRaw") == true
                        val offset = call.argument<Int>("offset") ?: 0
                        val limit = call.argument<Int>("limit") ?: 60
                        runAsync(result) { scanImportRootPage(includeRaw, offset, limit) }
                    }
                    "fetchImportPreviewImageData" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        if (pathOrUri.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            runAsync(result) { fetchExternalPreviewImageData(pathOrUri) }
                        }
                    }
                    "fetchImportFullImageData" -> {
                        val pathOrUri = call.argument<String>("pathOrUri")
                        if (pathOrUri.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            runAsync(result) { fetchExternalFullImageData(pathOrUri) }
                        }
                    }
                    "importExternalMedia" -> {
                        val sourceUri = call.argument<String>("sourceUri")
                        val displayName = call.argument<String>("displayName")
                        val type = call.argument<String>("type")
                        val albumName = call.argument<String>("albumName")
                        val albumRelativePath = call.argument<String>("albumRelativePath")
                        val useSystemLibrary = call.argument<Boolean>("useSystemLibrary") == true
                        if (sourceUri.isNullOrBlank() || displayName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "sourceUri/displayName is empty", null)
                        } else {
                            runAsync(result) {
                                importExternalMedia(
                                    sourceUri,
                                    displayName,
                                    type,
                                    albumName,
                                    albumRelativePath,
                                    useSystemLibrary
                                )
                            }
                        }
                    }
                    "startBackgroundImport" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any?>>>("items")
                        if (items.isNullOrEmpty()) {
                            result.success(false)
                        } else {
                            requestImportNotificationPermissionIfNeeded()
                            result.success(
                                ExternalImportService.start(
                                    this,
                                    items,
                                    call.argument<String>("albumName"),
                                    call.argument<String>("albumRelativePath"),
                                    call.argument<Boolean>("useSystemLibrary") == true,
                                )
                            )
                        }
                    }
                    "getBackgroundImportStatus" -> {
                        result.success(ExternalImportService.readStatus(this))
                    }
                    "deleteExternalMedia" -> {
                        val sourceUri = call.argument<String>("sourceUri")
                        if (sourceUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "sourceUri is empty", null)
                        } else {
                            deleteExternalMedia(sourceUri, result)
                        }
                    }
                    "deleteExternalMediaItems" -> {
                        val sourceUris = call.argument<List<String>>("sourceUris")
                        if (sourceUris.isNullOrEmpty()) {
                            result.success(emptyList<String>())
                        } else {
                            deleteExternalMediaItems(sourceUris, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCodeDeleteMedia) {
            if (resultCode == android.app.Activity.RESULT_OK) {
                Log.i(logTag, "User approved deletion")
                val externalDeleteUris = pendingExternalDeleteUris
                    ?: pendingExternalDeleteUri?.let { listOf(it) }
                    ?: emptyList()
                val deletedUris = externalDeleteUris
                    .filterNot { mediaUriStillExists(it) }
                    .map { it.toString() }
                val allDeletedUris = pendingExternalDeletedUris + deletedUris
                if (deletedUris.size != externalDeleteUris.size) {
                    lastImportDebugInfo =
                        "导入诊断：系统确认删除后，仍有媒体存在\n" +
                            "requested=${externalDeleteUris.size} deleted=${deletedUris.size}"
                    pendingDeleteResult?.error("DELETE_FAILED", "Media still exists after delete request", null)
                } else {
                    if (externalDeleteUris.isNotEmpty()) {
                        lastImportDebugInfo = "导入诊断：已从储存卡删除 ${externalDeleteUris.size} 个媒体项目"
                    }
                    pendingDeleteResult?.success(allDeletedUris)
                }
            } else {
                Log.w(logTag, "User denied deletion")
                pendingDeleteResult?.error("DENIED", "User denied deletion request", null)
            }
            pendingDeleteResult = null
            pendingDeleteIds = null
            pendingExternalDeleteUri = null
            pendingExternalDeleteUris = null
            pendingExternalDeletedUris = emptyList()
        } else if (requestCode == requestCodeImportRoot) {
            val result = pendingImportRootResult
            val requestedRootId = pendingImportRootId
            pendingImportRootResult = null
            pendingImportRootId = null
            if (resultCode == android.app.Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val flags = data.flags and (
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                val grantInfo =
                    "uri=$uri\nflags=$flags\n" +
                        "tree=${DocumentsContract.isTreeUri(uri)} " +
                        "document=${DocumentsContract.isDocumentUri(this, uri)} " +
                        "root=${DocumentsContract.isRootUri(this, uri)}"
                Log.i(
                    logTag,
                    "Import root granted $grantInfo"
                )
                lastImportDebugInfo = "导入诊断：已授权\n$grantInfo"
                try {
                    contentResolver.takePersistableUriPermission(uri, flags)
                } catch (error: Exception) {
                    Log.w(logTag, "Persist import root permission failed", error)
                    lastImportDebugInfo += "\npersist failed=${error.javaClass.simpleName}: ${error.message}"
                }
                val value = uri.toString()
                externalImportPrefs.edit().putString(importRootUriKey, value).apply()
                result?.success(value)
            } else if (resultCode == android.app.Activity.RESULT_OK && !requestedRootId.isNullOrBlank()) {
                lastImportDebugInfo =
                    "导入诊断：系统没有返回可读取的储存卡目录，请改用手动授权位置选择储存卡根目录。\nvolume=$requestedRootId"
                result?.success(null)
            } else {
                lastImportDebugInfo = "导入诊断：用户取消或系统未返回授权位置。"
                result?.success(null)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != requestCodeMediaRead) {
            return
        }

        val status = when {
            hasFullMediaReadPermission() -> "granted"
            hasLimitedMediaReadPermission() -> "limited"
            else -> "denied"
        }
        pendingPermissionResult?.success(status)
        pendingPermissionResult = null
    }

    private fun requestMediaReadPermission(result: MethodChannel.Result) {
        if (hasFullMediaReadPermission()) {
            result.success("granted")
            return
        }
        if (hasLimitedMediaReadPermission()) {
            result.success("limited")
            return
        }

        val permissions = mediaReadPermissions()
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, permissions, requestCodeMediaRead)
    }

    private fun requestImportNotificationPermissionIfNeeded() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                requestCodeImportNotifications,
            )
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        Thread {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (error: SecurityException) {
                runOnUiThread {
                    result.error("SECURITY_ERROR", error.message ?: "Security exception", null)
                }
            } catch (error: Exception) {
                Log.e(logTag, "runAsync failed", error)
                runOnUiThread {
                    result.error("UNEXPECTED_ERROR", error.message ?: "Unexpected error", null)
                }
            }
        }.start()
    }

    private fun fetchAllMediaIds(): List<String> {
        return fetchAllMediaItems().mapNotNull { item -> item["id"]?.toString() }
    }

    private fun fetchAllMediaItems(): List<Map<String, Any?>> {
        val all = mutableListOf<Map<String, Any?>>()
        var offset = 0
        val pageSize = 500
        while (true) {
            val page = fetchMediaPage(offset, pageSize)
            if (page.isEmpty()) break
            all.addAll(page.map { it.toMap() })
            if (page.size < pageSize) break
            offset += page.size
        }
        Log.i(logTag, "fetchAllMediaItems merged=${all.size}")
        return all
    }

    private fun fetchUserAlbums(): List<Map<String, Any>> {
        val albums = linkedMapOf<String, MutableMap<String, Any>>()
        collectAlbums(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, albums)
        collectAlbums(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, albums)
        return albums.values
            .sortedBy { (it["name"] as? String)?.lowercase(Locale.getDefault()) ?: "" }
    }

    private fun collectAlbums(
        uri: Uri,
        albums: LinkedHashMap<String, MutableMap<String, Any>>,
    ) {
        val projection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                MediaStore.MediaColumns.BUCKET_ID,
                MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
                MediaStore.MediaColumns.RELATIVE_PATH,
            )
        } else {
            arrayOf(
                MediaStore.MediaColumns.BUCKET_ID,
                MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
                MediaStore.MediaColumns.DATA,
            )
        }
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            val pathIndex = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
            } else {
                cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            }
            while (cursor.moveToNext()) {
                val id = cursor.getString(idIndex) ?: continue
                val name = cursor.getString(nameIndex) ?: continue
                val relativePath = albumRelativePathFromCursor(cursor, pathIndex)
                val existing = albums.getOrPut(id) {
                    mutableMapOf<String, Any>(
                        "id" to id,
                        "name" to name,
                        "count" to 0,
                    )
                }
                existing["count"] = ((existing["count"] as? Int) ?: 0) + 1
                if (relativePath != null && existing["relativePath"] == null) {
                    existing["relativePath"] = relativePath
                }
            }
        }
    }

    private fun albumRelativePathFromCursor(cursor: android.database.Cursor, pathIndex: Int): String? {
        if (pathIndex < 0) return null
        val raw = cursor.getString(pathIndex) ?: return null
        val value = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            raw
        } else {
            val parent = File(raw).parent ?: return null
            val root = Environment.getExternalStorageDirectory().absolutePath
            if (parent.startsWith(root)) parent.removePrefix(root) else parent
        }
        return value.trim().trim('/').takeIf { it.isNotBlank() }
    }

    private fun fetchMediaPage(offset: Int, limit: Int): List<NativeMediaItem> {
        if (limit <= 0) return emptyList()
        val safeOffset = offset.coerceAtLeast(0)
        val safeLimit = limit.coerceIn(1, 1000)
        if (useLegacyPaging) {
            return fetchMediaPageLegacy(safeOffset, safeLimit)
        }
        val primary = fetchMediaPagePrimary(safeOffset, safeLimit)
        if (primary.isNotEmpty() || safeOffset > 0) {
            return primary
        }
        val legacy = fetchMediaPageLegacy(safeOffset, safeLimit)
        if (legacy.isNotEmpty()) {
            useLegacyPaging = true
            Log.w(logTag, "Switching to legacy media paging strategy")
        }
        return legacy
    }

    private fun fetchMediaPagePrimary(
        safeOffset: Int,
        safeLimit: Int,
    ): List<NativeMediaItem> {
        val baseUri = MediaStore.Files.getContentUri("external")
        val mediaTypeColumnName = MediaStore.Files.FileColumns.MEDIA_TYPE
        val dateTakenColumnName = "datetaken"
        val dateAddedColumnName = "date_added"
        val dataColumnName = "_data"
        val sizeColumnName = MediaStore.MediaColumns.SIZE
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            mediaTypeColumnName,
            dateTakenColumnName,
            dateAddedColumnName,
            dataColumnName,
            sizeColumnName,
        )
        val selection = "$mediaTypeColumnName = ? OR $mediaTypeColumnName = ?"
        val selectionArgs = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )
        val sortOrder =
            "$dateTakenColumnName DESC, $dateAddedColumnName DESC LIMIT $safeLimit OFFSET $safeOffset"

        val items = mutableListOf<NativeMediaItem>()
        try {
            contentResolver.query(
                baseUri,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val mediaTypeColumn = cursor.getColumnIndex(mediaTypeColumnName)
                val dateTakenColumn = cursor.getColumnIndex(dateTakenColumnName)
                val dateAddedColumn = cursor.getColumnIndex(dateAddedColumnName)
                val dataColumn = cursor.getColumnIndex(dataColumnName)
                val sizeColumn = cursor.getColumnIndex(sizeColumnName)

                while (cursor.moveToNext()) {
                    val rowId = cursor.getLong(idColumn)
                    val mediaType = readInt(cursor, mediaTypeColumn)
                    val type = when (mediaType) {
                        MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> "photo"
                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> "video"
                        else -> continue
                    }
                    val contentBaseUri = when (type) {
                        "photo" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                        "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                        else -> continue
                    }
                    val contentUri = ContentUris.withAppendedId(contentBaseUri, rowId)
                    val dateTakenMillis = readLong(cursor, dateTakenColumn)
                    val dateAddedSeconds = readLong(cursor, dateAddedColumn)
                    val createdAtMillis = when {
                        dateTakenMillis != null && dateTakenMillis > 0L -> dateTakenMillis
                        dateAddedSeconds != null && dateAddedSeconds > 0L -> dateAddedSeconds * 1000
                        else -> 0L
                    }
                    val filePath = readString(cursor, dataColumn)
                    val sizeBytes = readLong(cursor, sizeColumn)
                    val uri = contentUri.toString()
                    val pathOrUri = if (filePath.isNullOrBlank()) uri else filePath

                    items.add(
                        NativeMediaItem(
                            id = "$type:$rowId",
                            type = type,
                            createdAtMillis = createdAtMillis,
                            locationKey = readCachedLocationKey("$type:$rowId"),
                            pathOrUri = pathOrUri,
                            sizeBytes = sizeBytes,
                        )
                    )
                }
            }
        } catch (error: SecurityException) {
            Log.e(logTag, "fetchMediaPagePrimary denied offset=$safeOffset limit=$safeLimit", error)
            return emptyList()
        } catch (error: Exception) {
            Log.e(logTag, "fetchMediaPagePrimary failed offset=$safeOffset limit=$safeLimit", error)
            return emptyList()
        }
        return items
    }

    private fun fetchMediaPageLegacy(offset: Int, limit: Int): List<NativeMediaItem> {
        if (offset == 0) {
            legacyMediaSnapshot = null
        }
        val snapshot = legacyMediaSnapshot ?: run {
            val loaded = loadLegacyMediaSnapshot()
            legacyMediaSnapshot = loaded
            loaded
        }
        if (offset >= snapshot.size) {
            return emptyList()
        }
        val end = (offset + limit).coerceAtMost(snapshot.size)
        return snapshot.subList(offset, end)
    }

    private fun loadLegacyMediaSnapshot(): List<NativeMediaItem> {
        val photos = queryMediaStoreByType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "photo")
        val videos = queryMediaStoreByType(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video")
        val merged = (photos + videos).sortedByDescending { it.createdAtMillis }
        Log.i(logTag, "loadLegacyMediaSnapshot photos=${photos.size}, videos=${videos.size}, merged=${merged.size}")
        return merged
    }

    private fun queryMediaStoreByType(baseUri: Uri, type: String): List<NativeMediaItem> {
        val dateTakenColumnName = "datetaken"
        val dateAddedColumnName = "date_added"
        val dataColumnName = "_data"
        val sizeColumnName = MediaStore.MediaColumns.SIZE
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            dateTakenColumnName,
            dateAddedColumnName,
            dataColumnName,
            sizeColumnName,
        )
        val items = mutableListOf<NativeMediaItem>()
        try {
            contentResolver.query(
                baseUri,
                projection,
                null,
                null,
                "$dateTakenColumnName DESC, $dateAddedColumnName DESC",
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val dateTakenColumn = cursor.getColumnIndex(dateTakenColumnName)
                val dateAddedColumn = cursor.getColumnIndex(dateAddedColumnName)
                val dataColumn = cursor.getColumnIndex(dataColumnName)
                val sizeColumn = cursor.getColumnIndex(sizeColumnName)

                while (cursor.moveToNext()) {
                    val rowId = cursor.getLong(idColumn)
                    val contentUri = ContentUris.withAppendedId(baseUri, rowId)
                    val dateTakenMillis = readLong(cursor, dateTakenColumn)
                    val dateAddedSeconds = readLong(cursor, dateAddedColumn)
                    val createdAtMillis = when {
                        dateTakenMillis != null && dateTakenMillis > 0L -> dateTakenMillis
                        dateAddedSeconds != null && dateAddedSeconds > 0L -> dateAddedSeconds * 1000
                        else -> 0L
                    }
                    val filePath = readString(cursor, dataColumn)
                    val sizeBytes = readLong(cursor, sizeColumn)
                    val uri = contentUri.toString()
                    val pathOrUri = if (filePath.isNullOrBlank()) uri else filePath
                    items.add(
                        NativeMediaItem(
                            id = "$type:$rowId",
                            type = type,
                            createdAtMillis = createdAtMillis,
                            locationKey = readCachedLocationKey("$type:$rowId"),
                            pathOrUri = pathOrUri,
                            sizeBytes = sizeBytes,
                        )
                    )
                }
            }
        } catch (error: Exception) {
            Log.e(logTag, "queryMediaStoreByType failed type=$type", error)
            return emptyList()
        }
        return items
    }

    private fun readGeoLocationFromExif(filePath: String?, contentUri: Uri): Pair<Double, Double>? {
        val exif = try {
            when {
                !filePath.isNullOrBlank() -> ExifInterface(filePath)
                else -> {
                    val stream = contentResolver.openInputStream(contentUri) ?: return null
                    stream.use { ExifInterface(it) }
                }
            }
        } catch (e: Exception) {
            Log.d(logTag, "readGeoLocationFromExif failed: ${e.message}")
            return null
        }

        val latLong = FloatArray(2)
        if (!exif.getLatLong(latLong)) {
            return null
        }
        val latitude = latLong[0].toDouble()
        val longitude = latLong[1].toDouble()
        if (latitude == 0.0 && longitude == 0.0) {
            return null
        }
        return latitude to longitude
    }

    private fun resolveReadableLocationKey(pathOrUri: String?): String? {
        val geo = readGeoLocationFromPath(pathOrUri) ?: return null
        val (latitude, longitude) = geo
        val geocoded = reverseGeocodeKey(latitude, longitude)
        return geocoded ?: buildLocationKey(latitude, longitude)
    }

    private fun readGeoLocationFromPath(pathOrUri: String?): Pair<Double, Double>? {
        if (pathOrUri.isNullOrBlank()) return null
        return try {
            when {
                pathOrUri.startsWith("content://") -> {
                    val uri = Uri.parse(pathOrUri)
                    readGeoLocationFromExif(null, uri)
                }
                pathOrUri.startsWith("file://") -> {
                    val filePath = Uri.parse(pathOrUri).path ?: return null
                    readGeoLocationFromExif(filePath, Uri.parse(pathOrUri))
                }
                else -> {
                    readGeoLocationFromExif(pathOrUri, Uri.fromFile(java.io.File(pathOrUri)))
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun reverseGeocodeKey(latitude: Double, longitude: Double): String? {
        if (!Geocoder.isPresent()) return null
        return try {
            val geocoder = Geocoder(this, Locale.SIMPLIFIED_CHINESE)
            val results = geocoder.getFromLocation(latitude, longitude, 1)
            val addr = results?.firstOrNull() ?: return null
            val country = addr.countryCode?.trim().takeUnless { it.isNullOrEmpty() } ?: "ZZ"
            val province = addr.adminArea?.trim().takeUnless { it.isNullOrEmpty() }
            val city = addr.locality?.trim().takeUnless { it.isNullOrEmpty() }
                ?: addr.subAdminArea?.trim().takeUnless { it.isNullOrEmpty() }
            val district = addr.subLocality?.trim().takeUnless { it.isNullOrEmpty() }
                ?: addr.featureName?.trim().takeUnless { it.isNullOrEmpty() }
            val segments = mutableListOf<String>()
            segments.add(country)
            if (!province.isNullOrEmpty()) segments.add(province)
            if (!city.isNullOrEmpty()) segments.add(city)
            if (!district.isNullOrEmpty()) segments.add(district)
            val preciseLat = String.format(Locale.US, "%.5f", latitude)
            val preciseLon = String.format(Locale.US, "%.5f", longitude)
            segments.add("@$preciseLat,$preciseLon")
            if (segments.size < 2) null else segments.joinToString("/")
        } catch (_: Exception) {
            null
        }
    }

    private fun readDeviceModelFromExif(pathOrUri: String?): String? {
        if (pathOrUri == null || pathOrUri.isEmpty()) return null
        // Detect screenshots from path
        if (pathOrUri.contains("Screenshot", ignoreCase = true)) {
            return "Screenshot"
        }
        try {
            val exif = when {
                !pathOrUri.contains("://") -> ExifInterface(pathOrUri)
                pathOrUri.startsWith("file://") -> {
                    val path = Uri.parse(pathOrUri).path ?: return null
                    ExifInterface(path)
                }
                pathOrUri.startsWith("content://") -> {
                    val uri = Uri.parse(pathOrUri)
                    val stream = contentResolver.openInputStream(uri) ?: return null
                    stream.use { ExifInterface(it) }
                }
                else -> return null
            }
            return buildDeviceLabel(
                exif.getAttribute(ExifInterface.TAG_MAKE),
                exif.getAttribute(ExifInterface.TAG_MODEL)
            )
        } catch (e: Exception) {
            Log.d(logTag, "readDeviceModelFromExif: ${e.message}")
        }
        return null
    }

    private fun fetchPreviewImageData(pathOrUri: String): ByteArray? {
        val bitmap = try {
            val uri = resolveContentUri(pathOrUri)
            if (uri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentResolver.loadThumbnail(uri, Size(768, 768), null)
            } else {
                val path = when {
                    pathOrUri.startsWith("file://") -> Uri.parse(pathOrUri).path
                    pathOrUri.startsWith("content://") -> null
                    else -> pathOrUri
                }
                if (!path.isNullOrBlank()) {
                    BitmapFactory.decodeFile(path)
                } else if (uri != null) {
                    contentResolver.openInputStream(uri)?.use {
                        BitmapFactory.decodeStream(it)
                    }
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.d(logTag, "fetchPreviewImageData failed: ${e.message}")
            null
        } ?: return null

        return ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
            output.toByteArray()
        }
    }

    private fun buildDeviceLabel(make: String?, model: String?): String? {
        val m = model?.trim()
        if (m.isNullOrEmpty()) return null
        val mk = make?.trim()
        if (mk.isNullOrEmpty()) return m
        // Use only the first word of make (e.g. "NIKON" from "NIKON CORPORATION")
        val mkBrand = mk.split(" ").first()
        // If model already starts with the brand (e.g. "NIKON D5600"), return model as-is
        if (m.startsWith(mkBrand, ignoreCase = true)) return m
        // Otherwise prefix with full make
        return "$mk $m"
    }

    private fun openInGallery(pathOrUri: String) {
        try {
            val contentUri = resolveContentUri(pathOrUri) ?: return
            val mimeType = contentResolver.getType(contentUri) ?: guessMimeType(pathOrUri)
            val intent = Intent(Intent.ACTION_SEND)
            intent.type = mimeType
            intent.putExtra(Intent.EXTRA_STREAM, contentUri)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(intent, null))
        } catch (e: Exception) {
            Log.e(logTag, "Failed to open in gallery", e)
        }
    }

    private fun shareToTarget(pathOrUri: String, pkg: String, activity: String?) {
        try {
            val contentUri = resolveContentUri(pathOrUri) ?: return
            val mimeType = contentResolver.getType(contentUri) ?: guessMimeType(pathOrUri)
            val intent = Intent(Intent.ACTION_SEND)
            intent.type = mimeType
            intent.putExtra(Intent.EXTRA_STREAM, contentUri)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.setPackage(pkg)
            if (activity != null && activity.isNotEmpty()) {
                intent.setClassName(pkg, activity)
            }
            try {
                startActivity(intent)
            } catch (e: android.content.ActivityNotFoundException) {
                // Target not installed, fall back to system chooser
                Log.w(logTag, "Target $pkg not found, falling back to chooser")
                intent.setPackage(null)
                intent.component = null
                startActivity(Intent.createChooser(intent, null))
            }
        } catch (e: Exception) {
            Log.e(logTag, "shareToTarget failed", e)
        }
    }

    private fun resolveContentUri(pathOrUri: String): Uri? {
        // Already a content URI — use directly
        if (pathOrUri.startsWith("content://")) {
            return Uri.parse(pathOrUri)
        }
        // File path — look up in MediaStore to get a content URI
        val filePath = if (pathOrUri.startsWith("file://")) {
            Uri.parse(pathOrUri).path ?: return null
        } else {
            pathOrUri
        }
        // Try images first, then videos
        val imageUri = queryContentUri(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, filePath)
        if (imageUri != null) return imageUri
        return queryContentUri(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, filePath)
    }

    private fun queryContentUri(baseUri: Uri, filePath: String): Uri? {
        val cursor = contentResolver.query(
            baseUri,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.DATA} = ?",
            arrayOf(filePath),
            null
        ) ?: return null
        return cursor.use {
            if (it.moveToFirst()) {
                val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                ContentUris.withAppendedId(baseUri, id)
            } else null
        }
    }

    private fun guessMimeType(path: String): String {
        val lower = path.lowercase()
        return when {
            lower.endsWith(".mp4") || lower.endsWith(".mov") || lower.endsWith(".avi") || lower.endsWith(".mkv") -> "video/*"
            else -> "image/*"
        }
    }

    private fun permanentDelete(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        if (arguments == null) {
            result.success(null)
            return
        }
        val ids = arguments["ids"] as? List<*>
        if (ids == null || ids.isEmpty()) {
            result.success(null)
            return
        }

        // Collect content URIs for all media items to delete
        val contentUris = mutableListOf<Uri>()
        for (id in ids) {
            val idString = id?.toString() ?: continue
            val typedId = parseTypedMediaId(idString)
            if (typedId == null) {
                // Try both photo and video URIs
                resolveContentUri(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, idString)?.let { contentUris.add(it) }
                resolveContentUri(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idString)?.let { contentUris.add(it) }
                continue
            }
            val baseUri = when (typedId.first) {
                "photo" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                else -> null
            }
            if (baseUri != null) {
                val contentUri = ContentUris.withAppendedId(baseUri, typedId.second.toLongOrNull() ?: continue)
                contentUris.add(contentUri)
            }
        }

        if (contentUris.isEmpty()) {
            result.success(null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ : use createDeleteRequest for user consent
            try {
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, contentUris)
                pendingDeleteResult = result
                pendingDeleteIds = ids.mapNotNull { it?.toString() }.toSet()
                @Suppress("DEPRECATION")
                startIntentSenderForResult(pendingIntent.intentSender, requestCodeDeleteMedia, null, 0, 0, 0)
            } catch (e: Exception) {
                Log.e(logTag, "createDeleteRequest failed", e)
                // Fallback: try direct delete
                for (uri in contentUris) {
                    try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
                }
                result.success(null)
            }
        } else {
            // Android 10 and below: direct delete
            for (uri in contentUris) {
                try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            }
            result.success(null)
        }
    }

    private fun readSavedImportRoot(): String? {
        val value = externalImportPrefs.getString(importRootUriKey, null)
        if (value.isNullOrBlank()) {
            lastImportDebugInfo = "导入诊断：没有已保存的授权位置。"
            return null
        }
        if (value.startsWith("volume://")) {
            val volumeName = value.removePrefix("volume://")
            externalImportPrefs.edit().remove(importRootUriKey).apply()
            lastImportDebugInfo =
                "导入诊断：需要重新授权储存卡根目录\nvolume=$volumeName"
            return null
        }
        val uri = Uri.parse(value)
        val hasPersistedPermission = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
        val hasActivePermission = checkUriPermission(
            uri,
            android.os.Process.myPid(),
            android.os.Process.myUid(),
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        ) == PackageManager.PERMISSION_GRANTED
        val hasPermission = hasPersistedPermission || hasActivePermission
        if (!hasPermission) {
            lastImportDebugInfo =
                "导入诊断：授权位置不可读\nuri=$uri\n" +
                    "persisted=$hasPersistedPermission active=$hasActivePermission"
        }
        return if (hasPermission) value else null
    }

    private fun listImportRoots(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return emptyList()
        return try {
            val storageManager = getSystemService(StorageManager::class.java)
            storageManager.storageVolumes
                .filter { volume ->
                    volume.isRemovable && volume.state == Environment.MEDIA_MOUNTED
                }
                .map { volume ->
                    val description = volume.getDescription(this)
                    val uuid = volume.uuid
                    val mediaStoreVolumeName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        volume.mediaStoreVolumeName
                    } else {
                        uuid ?: description
                    }
                    mapOf(
                        "id" to mediaStoreVolumeName,
                        "label" to (description.takeUnless { it.isNullOrBlank() } ?: "储存卡"),
                        "description" to if (uuid.isNullOrBlank()) {
                            "已挂载的外接储存卡"
                        } else {
                            "储存卡 $uuid"
                        },
                        "removable" to true,
                    )
                }
        } catch (error: Exception) {
            Log.w(logTag, "Unable to list removable storage roots", error)
            emptyList()
        }
    }

    private fun requestImportRoot(result: MethodChannel.Result, rootId: String? = null) {
        if (pendingImportRootResult != null) {
            result.error("BUSY", "Import root picker is already open", null)
            return
        }
        pendingImportRootResult = result
        pendingImportRootId = rootId
        val intent = buildImportRootPickerIntent(rootId).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            putExtra("android.provider.extra.SHOW_ADVANCED", true)
        }
        lastImportDebugInfo = if (rootId.isNullOrBlank()) {
            "导入诊断：正在请求手动授权储存位置。"
        } else {
            "导入诊断：正在请求储存卡目录授权\nvolume=$rootId"
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, requestCodeImportRoot)
    }

    private fun buildImportRootPickerIntent(rootId: String? = null): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val storageManager = getSystemService(StorageManager::class.java)
                val removable = storageManager.storageVolumes
                    .filter { volume ->
                        volume.isRemovable && volume.state == Environment.MEDIA_MOUNTED
                    }
                    .firstOrNull { volume ->
                        rootId.isNullOrBlank() ||
                            volumeMatchesImportRoot(volume, rootId)
                    }
                val intent = removable?.createOpenDocumentTreeIntent()
                if (intent != null) {
                    return intent
                }
            } catch (error: Exception) {
                Log.w(logTag, "Unable to open picker at removable storage root", error)
            }
        }
        return Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
    }

    private fun volumeMatchesImportRoot(
        volume: android.os.storage.StorageVolume,
        rootId: String?,
    ): Boolean {
        if (rootId.isNullOrBlank()) return false
        val mediaStoreVolumeName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            volume.mediaStoreVolumeName
        } else {
            null
        }
        return volume.uuid == rootId ||
            volume.getDescription(this) == rootId ||
            mediaStoreVolumeName == rootId
    }

    private fun isImportVolumeMounted(volumeName: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        return try {
            val storageManager = getSystemService(StorageManager::class.java)
            storageManager.storageVolumes.any { volume ->
                volume.isRemovable &&
                    volume.state == Environment.MEDIA_MOUNTED &&
                    volumeMatchesImportRoot(volume, volumeName)
            }
        } catch (error: Exception) {
            Log.w(logTag, "Unable to verify import volume mount state", error)
            false
        }
    }

    private fun scanImportRoot(includeRaw: Boolean = false): List<NativeExternalImportItem> {
        val root = readSavedImportRoot() ?: return emptyList()
        if (root.startsWith("volume://")) {
            val volumeName = root.removePrefix("volume://")
            val items = scanMediaStoreImportVolume(volumeName, includeRaw)
            return items
        }
        val items = mutableListOf<NativeExternalImportItem>()
        val rootUri = Uri.parse(root)
        val uriInfo =
            "uri=$rootUri\n" +
                "tree=${DocumentsContract.isTreeUri(rootUri)} " +
                "document=${DocumentsContract.isDocumentUri(this, rootUri)} " +
                "root=${DocumentsContract.isRootUri(this, rootUri)}"
        try {
            when {
                DocumentsContract.isTreeUri(rootUri) -> {
                    val rootDocumentId = DocumentsContract.getTreeDocumentId(rootUri)
                    scanDocumentTree(rootUri, rootDocumentId, items, includeRaw)
                }
                DocumentsContract.isDocumentUri(this, rootUri) -> {
                    val rootDocumentId = DocumentsContract.getDocumentId(rootUri)
                    scanDocumentSubtree(rootUri.authority ?: return emptyList(), rootDocumentId, items, includeRaw)
                }
                DocumentsContract.isRootUri(this, rootUri) -> {
                    val rootDocumentId = "${DocumentsContract.getRootId(rootUri)}:"
                    scanDocumentSubtree(rootUri.authority ?: return emptyList(), rootDocumentId, items, includeRaw)
                }
                else -> {
                    Log.w(logTag, "Unsupported import root uri: $rootUri")
                    lastImportDebugInfo = "导入诊断：不支持的授权 URI\n$uriInfo"
                    return emptyList()
                }
            }
        } catch (error: Exception) {
            Log.w(logTag, "scanImportRoot failed for uri=$rootUri", error)
            lastImportDebugInfo =
                "导入诊断：扫描失败\n$uriInfo\n" +
                    "${error.javaClass.simpleName}: ${error.message}"
            return emptyList()
        }
        val volumeName = importVolumeNameFromDocumentUri(rootUri)
        if (!volumeName.isNullOrBlank()) {
            val volumeItems = scanMediaStoreImportVolume(volumeName, includeRaw)
            val mergedItems = mergeImportItems(items, volumeItems)
                .sortedByDescending { it.createdAtMillis }
            lastImportDebugInfo =
                "导入诊断：授权目录与储存卡索引合并完成，找到 ${mergedItems.size} 个可导入项目\n" +
                    "$uriInfo\nvolume=$volumeName dir=${items.size} volumeItems=${volumeItems.size}"
            return mergedItems
        }
        Log.i(logTag, "scanImportRoot found ${items.size} importable items")
        lastImportDebugInfo = "导入诊断：扫描完成，找到 ${items.size} 个可导入项目\n$uriInfo"
        return items.sortedByDescending { it.createdAtMillis }
    }

    private fun scanImportRootPage(
        includeRaw: Boolean = false,
        offset: Int,
        limit: Int,
    ): Map<String, Any?> {
        val safeOffset = offset.coerceAtLeast(0)
        val safeLimit = limit.coerceIn(1, 200)
        val maxItems = safeOffset + safeLimit + 1
        val root = readSavedImportRoot() ?: return mapOf(
            "items" to emptyList<Map<String, Any?>>(),
            "hasMore" to false,
        )
        val items = mutableListOf<NativeExternalImportItem>()
        if (root.startsWith("volume://")) {
            val volumeName = root.removePrefix("volume://")
            items.addAll(scanMediaStoreImportVolume(volumeName, includeRaw))
        } else {
            val rootUri = Uri.parse(root)
            try {
                when {
                    DocumentsContract.isTreeUri(rootUri) -> {
                        val rootDocumentId = DocumentsContract.getTreeDocumentId(rootUri)
                        scanDocumentTreeLimited(rootUri, rootDocumentId, items, includeRaw, maxItems)
                    }
                    DocumentsContract.isDocumentUri(this, rootUri) -> {
                        val rootDocumentId = DocumentsContract.getDocumentId(rootUri)
                        scanDocumentSubtreeLimited(
                            rootUri.authority ?: return mapOf("items" to emptyList<Map<String, Any?>>(), "hasMore" to false),
                            rootDocumentId,
                            items,
                            includeRaw,
                            maxItems,
                        )
                    }
                    DocumentsContract.isRootUri(this, rootUri) -> {
                        val rootDocumentId = "${DocumentsContract.getRootId(rootUri)}:"
                        scanDocumentSubtreeLimited(
                            rootUri.authority ?: return mapOf("items" to emptyList<Map<String, Any?>>(), "hasMore" to false),
                            rootDocumentId,
                            items,
                            includeRaw,
                            maxItems,
                        )
                    }
                    else -> {
                        lastImportDebugInfo = "导入诊断：不支持的授权 URI\nuri=$rootUri"
                    }
                }
            } catch (error: Exception) {
                Log.w(logTag, "scanImportRootPage failed for uri=$rootUri", error)
                lastImportDebugInfo =
                    "导入诊断：分页扫描失败\nuri=$rootUri\n" +
                        "${error.javaClass.simpleName}: ${error.message}"
            }
        }
        val merged = mergeImportItems(items, emptyList())
            .sortedByDescending { it.createdAtMillis }
        val end = (safeOffset + safeLimit).coerceAtMost(merged.size)
        val pageItems = if (safeOffset >= merged.size) {
            emptyList()
        } else {
            merged.subList(safeOffset, end)
        }
        return mapOf(
            "items" to pageItems.map { it.toMap() },
            "hasMore" to (merged.size > end),
        )
    }

    private fun importVolumeNameFromDocumentUri(uri: Uri): String? {
        val documentId = try {
            when {
                DocumentsContract.isTreeUri(uri) -> DocumentsContract.getTreeDocumentId(uri)
                DocumentsContract.isDocumentUri(this, uri) -> DocumentsContract.getDocumentId(uri)
                DocumentsContract.isRootUri(this, uri) -> "${DocumentsContract.getRootId(uri)}:"
                else -> null
            }
        } catch (_: Exception) {
            null
        } ?: return null
        val rootId = documentId.substringBefore(':').takeUnless { it.isBlank() } ?: return null
        if (rootId.equals("primary", ignoreCase = true)) return null
        return importMediaStoreVolumeNameForRoot(rootId)
    }

    private fun importMediaStoreVolumeNameForRoot(rootId: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return rootId
        return try {
            val storageManager = getSystemService(StorageManager::class.java)
            storageManager.storageVolumes
                .firstOrNull { volume ->
                    volume.isRemovable &&
                        volume.state == Environment.MEDIA_MOUNTED &&
                        volumeMatchesImportRoot(volume, rootId)
                }
                ?.let { volume ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        volume.mediaStoreVolumeName
                    } else {
                        volume.uuid ?: rootId
                    }
                }
        } catch (error: Exception) {
            Log.w(logTag, "Unable to resolve MediaStore volume for document uri", error)
            null
        }
    }

    private fun scanMediaStoreImportVolume(
        volumeName: String,
        includeRaw: Boolean = false,
    ): List<NativeExternalImportItem> {
        if (!isImportVolumeMounted(volumeName)) {
            externalImportPrefs.edit().remove(importRootUriKey).apply()
            lastImportDebugInfo =
                "导入诊断：储存卡未连接或未挂载\nvolume=$volumeName"
            return emptyList()
        }
        val photoItems = scanMediaStoreImportCollection(
            volumeName = volumeName,
            baseUri = importMediaCollectionUri(volumeName, "photo"),
            type = "photo",
            includeDateTaken = true,
            includeRaw = includeRaw,
        )
        val videoItems = scanMediaStoreImportCollection(
            volumeName = volumeName,
            baseUri = importMediaCollectionUri(volumeName, "video"),
            type = "video",
            includeDateTaken = false,
            includeRaw = includeRaw,
        )
        val filesItems = scanMediaStoreFilesImportVolume(volumeName, includeRaw)
        val fileSystemItems = scanFileSystemImportVolume(volumeName, includeRaw)
        val items = mergeImportItems(photoItems + videoItems, filesItems + fileSystemItems)
            .sortedByDescending { it.createdAtMillis }
        lastImportDebugInfo =
            "导入诊断：储存卡扫描完成，找到 ${items.size} 个可导入项目\n" +
                "volume=$volumeName images=${photoItems.size} videos=${videoItems.size} " +
                "files=${filesItems.size} direct=${fileSystemItems.size}"
        return items
    }

    private fun scanMediaStoreFilesImportVolume(
        volumeName: String,
        includeRaw: Boolean = false,
    ): List<NativeExternalImportItem> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        val baseUri = MediaStore.Files.getContentUri(volumeName)
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.Files.FileColumns.DATE_ADDED,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.SIZE,
        )
        val selection =
            "${MediaStore.Files.FileColumns.MEDIA_TYPE}=? OR " +
                "${MediaStore.Files.FileColumns.MEDIA_TYPE}=?"
        val selectionArgs = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )
        val sortOrder =
            "${MediaStore.Files.FileColumns.DATE_ADDED} DESC, " +
                "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
        val items = mutableListOf<NativeExternalImportItem>()
        try {
            contentResolver.query(
                baseUri,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                val nameColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val mimeColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.MIME_TYPE)
                val mediaTypeColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.MEDIA_TYPE)
                val dateAddedColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_ADDED)
                val modifiedColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_MODIFIED)
                val sizeColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
                while (cursor.moveToNext()) {
                    val rowId = cursor.getLong(idColumn)
                    val displayName = readString(cursor, nameColumn) ?: "$rowId"
                    val mimeType = readString(cursor, mimeColumn) ?: mimeTypeFromName(displayName) ?: ""
                    val mediaType = when (readLong(cursor, mediaTypeColumn)?.toInt()) {
                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> "video"
                        MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> "photo"
                        else -> externalMediaType(displayName, mimeType, includeRaw)
                    } ?: continue
                    if (externalMediaType(displayName, mimeType, includeRaw) != mediaType) continue
                    val dateAddedSeconds = readLong(cursor, dateAddedColumn)
                    val modifiedSeconds = readLong(cursor, modifiedColumn)
                    val createdAtMillis = when {
                        dateAddedSeconds != null && dateAddedSeconds > 0L -> dateAddedSeconds * 1000
                        modifiedSeconds != null && modifiedSeconds > 0L -> modifiedSeconds * 1000
                        else -> 0L
                    }
                    val sizeBytes = readLong(cursor, sizeColumn)
                    val documentUri = ContentUris.withAppendedId(baseUri, rowId)
                    items.add(
                        NativeExternalImportItem(
                            id = documentUri.toString(),
                            type = mediaType,
                            displayName = displayName,
                            createdAtMillis = createdAtMillis,
                            sizeBytes = sizeBytes,
                            pathOrUri = documentUri.toString(),
                            imported = isPreviouslyImported(displayName, sizeBytes, modifiedSeconds ?: 0L),
                        )
                    )
                }
            }
        } catch (error: SecurityException) {
            Log.w(logTag, "MediaStore files permission denied for volume=$volumeName", error)
        } catch (error: Exception) {
            Log.w(logTag, "MediaStore files scan failed for volume=$volumeName", error)
        }
        return items
    }

    private fun scanFileSystemImportVolume(
        volumeName: String,
        includeRaw: Boolean = false,
    ): List<NativeExternalImportItem> {
        val volumeDirectory = importVolumeDirectory(volumeName) ?: return emptyList()
        if (!volumeDirectory.canRead()) return emptyList()
        val preferredRoots = listOf("DCIM", "Pictures", "Movies")
            .map { File(volumeDirectory, it) }
            .filter { it.exists() && it.canRead() }
            .takeUnless { it.isEmpty() }
            ?: listOf(volumeDirectory)
        val items = mutableListOf<NativeExternalImportItem>()
        for (root in preferredRoots) {
            root.walkTopDown()
                .onEnter { directory -> directory.canRead() }
                .filter { file -> file.isFile && file.canRead() }
                .forEach { file ->
                    val mimeType = mimeTypeFromName(file.name) ?: ""
                    val type = externalMediaType(file.name, mimeType, includeRaw) ?: return@forEach
                    val modifiedAtMillis = file.lastModified().takeIf { it > 0L } ?: 0L
                    val sizeBytes = file.length().takeIf { it >= 0L }
                    val uri = Uri.fromFile(file).toString()
                    items.add(
                        NativeExternalImportItem(
                            id = uri,
                            type = type,
                            displayName = file.name,
                            createdAtMillis = modifiedAtMillis,
                            sizeBytes = sizeBytes,
                            pathOrUri = uri,
                            imported = isPreviouslyImported(file.name, sizeBytes, modifiedAtMillis),
                        )
                    )
                }
        }
        return items
    }

    private fun importVolumeDirectory(volumeName: String): File? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            val storageManager = getSystemService(StorageManager::class.java)
            storageManager.storageVolumes
                .firstOrNull { volume ->
                    volume.isRemovable &&
                        volume.state == Environment.MEDIA_MOUNTED &&
                        volumeMatchesImportRoot(volume, volumeName)
                }
                ?.directory
        } catch (error: Exception) {
            Log.w(logTag, "Unable to resolve import volume directory", error)
            null
        }
    }

    private fun mergeImportItems(
        mediaStoreItems: List<NativeExternalImportItem>,
        fileSystemItems: List<NativeExternalImportItem>,
    ): List<NativeExternalImportItem> {
        val merged = mutableListOf<NativeExternalImportItem>()
        val seen = mutableSetOf<String>()
        for (item in mediaStoreItems + fileSystemItems) {
            val key = listOf(
                item.displayName.trim().lowercase(Locale.US),
                item.sizeBytes?.toString() ?: "",
            ).joinToString("|")
            if (seen.add(key)) {
                merged.add(item)
            }
        }
        return merged
    }

    private fun importMediaCollectionUri(volumeName: String, type: String): Uri {
        return if (type == "video") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(volumeName)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(volumeName)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        }
    }

    private fun scanMediaStoreImportCollection(
        volumeName: String,
        baseUri: Uri,
        type: String,
        includeDateTaken: Boolean,
        includeRaw: Boolean = false,
    ): List<NativeExternalImportItem> {
        val dateTakenColumnName = "datetaken"
        val dateAddedColumnName = "date_added"
        val modifiedColumnName = "date_modified"
        val projection = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            dateAddedColumnName,
            modifiedColumnName,
            MediaStore.MediaColumns.SIZE,
        )
        if (includeDateTaken) {
            projection.add(3, dateTakenColumnName)
        }
        val sortOrder = if (includeDateTaken) {
            "$dateTakenColumnName DESC, $dateAddedColumnName DESC"
        } else {
            "$dateAddedColumnName DESC, $modifiedColumnName DESC"
        }
        val items = mutableListOf<NativeExternalImportItem>()
        try {
            contentResolver.query(baseUri, projection.toTypedArray(), null, null, sortOrder)?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val nameColumn = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                val mimeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
                val dateTakenColumn = cursor.getColumnIndex(dateTakenColumnName)
                val dateAddedColumn = cursor.getColumnIndex(dateAddedColumnName)
                val modifiedColumn = cursor.getColumnIndex(modifiedColumnName)
                val sizeColumn = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
                while (cursor.moveToNext()) {
                    val rowId = cursor.getLong(idColumn)
                    val displayName = readString(cursor, nameColumn) ?: "$rowId"
                    val mimeType = readString(cursor, mimeColumn) ?: mimeTypeFromName(displayName) ?: ""
                    if (externalMediaType(displayName, mimeType, includeRaw) != type) continue
                    val dateTakenMillis = readLong(cursor, dateTakenColumn)
                    val dateAddedSeconds = readLong(cursor, dateAddedColumn)
                    val modifiedSeconds = readLong(cursor, modifiedColumn)
                    val createdAtMillis = when {
                        dateTakenMillis != null && dateTakenMillis > 0L -> dateTakenMillis
                        dateAddedSeconds != null && dateAddedSeconds > 0L -> dateAddedSeconds * 1000
                        modifiedSeconds != null && modifiedSeconds > 0L -> modifiedSeconds * 1000
                        else -> 0L
                    }
                    val sizeBytes = readLong(cursor, sizeColumn)
                    val documentUri = ContentUris.withAppendedId(baseUri, rowId)
                    items.add(
                        NativeExternalImportItem(
                            id = documentUri.toString(),
                            type = type,
                            displayName = displayName,
                            createdAtMillis = createdAtMillis,
                            sizeBytes = sizeBytes,
                            pathOrUri = documentUri.toString(),
                            imported = isPreviouslyImported(displayName, sizeBytes, modifiedSeconds ?: 0L),
                        )
                    )
                }
            }
        } catch (error: SecurityException) {
            lastImportDebugInfo =
                "导入诊断：MediaStore 读取权限不足\nvolume=$volumeName type=$type\n" +
                    "${error.javaClass.simpleName}: ${error.message}"
            return emptyList()
        } catch (error: Exception) {
            lastImportDebugInfo =
                "导入诊断：MediaStore 扫描失败\nvolume=$volumeName type=$type\n" +
                    "${error.javaClass.simpleName}: ${error.message}"
            return emptyList()
        }
        return items
    }

    private fun scanDocumentSubtree(
        authority: String,
        documentId: String,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
    ) {
        scanDocumentChildren(
            childrenUri = DocumentsContract.buildChildDocumentsUri(authority, documentId),
            documentUriFor = { childId -> DocumentsContract.buildDocumentUri(authority, childId) },
            recurseInto = { childId -> scanDocumentSubtree(authority, childId, items, includeRaw) },
            items = items,
            includeRaw = includeRaw,
        )
    }

    private fun scanDocumentTree(
        treeUri: Uri,
        documentId: String,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
    ) {
        scanDocumentChildren(
            childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId),
            documentUriFor = { childId -> DocumentsContract.buildDocumentUriUsingTree(treeUri, childId) },
            recurseInto = { childId -> scanDocumentTree(treeUri, childId, items, includeRaw) },
            items = items,
            includeRaw = includeRaw,
        )
    }

    private fun scanDocumentSubtreeLimited(
        authority: String,
        documentId: String,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
        maxItems: Int,
    ): Boolean {
        if (items.size >= maxItems) return true
        return scanDocumentChildrenLimited(
            childrenUri = DocumentsContract.buildChildDocumentsUri(authority, documentId),
            documentUriFor = { childId -> DocumentsContract.buildDocumentUri(authority, childId) },
            recurseInto = { childId ->
                scanDocumentSubtreeLimited(authority, childId, items, includeRaw, maxItems)
            },
            items = items,
            includeRaw = includeRaw,
            maxItems = maxItems,
        )
    }

    private fun scanDocumentTreeLimited(
        treeUri: Uri,
        documentId: String,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
        maxItems: Int,
    ): Boolean {
        if (items.size >= maxItems) return true
        return scanDocumentChildrenLimited(
            childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId),
            documentUriFor = { childId -> DocumentsContract.buildDocumentUriUsingTree(treeUri, childId) },
            recurseInto = { childId ->
                scanDocumentTreeLimited(treeUri, childId, items, includeRaw, maxItems)
            },
            items = items,
            includeRaw = includeRaw,
            maxItems = maxItems,
        )
    }

    private fun scanDocumentChildrenLimited(
        childrenUri: Uri,
        documentUriFor: (String) -> Uri,
        recurseInto: (String) -> Boolean,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
        maxItems: Int,
    ): Boolean {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val children = mutableListOf<NativeDocumentChild>()
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val modifiedColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val sizeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val childId = readString(cursor, idColumn) ?: continue
                val mimeType = readString(cursor, mimeColumn) ?: ""
                val name = readString(cursor, nameColumn) ?: childId.substringAfterLast('/')
                children.add(
                    NativeDocumentChild(
                        id = childId,
                        name = name,
                        mimeType = mimeType,
                        modifiedAtMillis = readLong(cursor, modifiedColumn) ?: 0L,
                        sizeBytes = readLong(cursor, sizeColumn),
                        isDirectory = mimeType == DocumentsContract.Document.MIME_TYPE_DIR,
                    )
                )
            }
        }

        val orderedChildren = children.sortedWith(
            compareBy<NativeDocumentChild> { if (it.isDirectory) 0 else 1 }
                .thenBy { if (it.isDirectory) importDirectoryPriority(it.name) else 0 }
                .thenByDescending { if (it.isDirectory) 0L else it.modifiedAtMillis }
                .thenBy { it.name.lowercase(Locale.US) }
        )
        for (child in orderedChildren) {
            if (items.size >= maxItems) return true
            if (child.isDirectory) {
                if (recurseInto(child.id)) return true
                continue
            }
            val mediaType = externalMediaType(child.name, child.mimeType, includeRaw) ?: continue
            val documentUri = documentUriFor(child.id)
            items.add(
                NativeExternalImportItem(
                    id = documentUri.toString(),
                    type = mediaType,
                    displayName = child.name,
                    createdAtMillis = child.modifiedAtMillis,
                    sizeBytes = child.sizeBytes,
                    pathOrUri = documentUri.toString(),
                    imported = isPreviouslyImported(child.name, child.sizeBytes, child.modifiedAtMillis),
                )
            )
        }
        return items.size >= maxItems
    }

    private fun importDirectoryPriority(name: String): Int {
        val lower = name.lowercase(Locale.US)
        return when {
            lower == "dcim" -> 0
            lower == "pictures" -> 2
            lower == "movies" -> 3
            lower == "android" -> 99
            else -> 10
        }
    }

    private fun scanDocumentChildren(
        childrenUri: Uri,
        documentUriFor: (String) -> Uri,
        recurseInto: (String) -> Unit,
        items: MutableList<NativeExternalImportItem>,
        includeRaw: Boolean = false,
    ) {
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val modifiedColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val sizeColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            while (cursor.moveToNext()) {
                val childId = readString(cursor, idColumn) ?: continue
                val mimeType = readString(cursor, mimeColumn) ?: ""
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    recurseInto(childId)
                    continue
                }
                val name = readString(cursor, nameColumn) ?: childId.substringAfterLast('/')
                val mediaType = externalMediaType(name, mimeType, includeRaw) ?: continue
                val documentUri = documentUriFor(childId)
                items.add(
                    NativeExternalImportItem(
                        id = documentUri.toString(),
                        type = mediaType,
                        displayName = name,
                        createdAtMillis = readLong(cursor, modifiedColumn) ?: 0L,
                        sizeBytes = readLong(cursor, sizeColumn),
                        pathOrUri = documentUri.toString(),
                        imported = isPreviouslyImported(name, readLong(cursor, sizeColumn), readLong(cursor, modifiedColumn) ?: 0L),
                    )
                )
            }
        }
    }

    private fun externalMediaType(
        displayName: String,
        mimeType: String,
        includeRaw: Boolean = false,
    ): String? {
        val rawImage = isRawImage(displayName, mimeType)
        if (rawImage && !includeRaw) return null
        if (rawImage) return "photo"
        if (mimeType.startsWith("image/")) return "photo"
        if (mimeType.startsWith("video/")) return "video"
        val lower = displayName.lowercase(Locale.US)
        return when {
            lower.endsWith(".jpg") ||
                lower.endsWith(".jpeg") ||
                lower.endsWith(".png") ||
                lower.endsWith(".heic") ||
                lower.endsWith(".heif") ||
                lower.endsWith(".webp") ||
                lower.endsWith(".dng") ||
                lower.endsWith(".nef") ||
                lower.endsWith(".nrw") ||
                lower.endsWith(".cr2") ||
                lower.endsWith(".cr3") ||
                lower.endsWith(".arw") ||
                lower.endsWith(".rw2") ||
                lower.endsWith(".orf") ||
                lower.endsWith(".raf") ||
                lower.endsWith(".pef") ||
                lower.endsWith(".srw") -> "photo"
            lower.endsWith(".mp4") ||
                lower.endsWith(".mov") ||
                lower.endsWith(".m4v") ||
                lower.endsWith(".avi") ||
                lower.endsWith(".mkv") -> "video"
            else -> null
        }
    }

    private fun isRawImage(displayName: String, mimeType: String): Boolean {
        if (mimeType.startsWith("image/x-") && rawImageMimeTypeFromName(displayName) != null) {
            return true
        }
        return rawImageMimeTypeFromName(displayName) != null
    }

    private fun fetchExternalPreviewImageData(pathOrUri: String): ByteArray? {
        val uri = Uri.parse(pathOrUri)
        val bitmap = try {
            if (uri.scheme == "file") {
                BitmapFactory.decodeFile(uri.path)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentResolver.loadThumbnail(uri, Size(768, 768), null)
            } else {
                contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it)
                }
            }
        } catch (error: Exception) {
            Log.d(logTag, "fetchExternalPreviewImageData failed: ${error.message}")
            null
        } ?: return null

        return ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)
            output.toByteArray()
        }
    }

    private fun fetchExternalFullImageData(pathOrUri: String): ByteArray? {
        val uri = Uri.parse(pathOrUri)
        return try {
            openSourceInputStream(uri)?.use { input ->
                input.readBytes()
            }
        } catch (error: Exception) {
            Log.d(logTag, "fetchExternalFullImageData failed: ${error.message}")
            null
        }
    }

    private fun deleteExternalMedia(sourceUriValue: String, result: MethodChannel.Result) {
        deleteExternalMediaItems(listOf(sourceUriValue), result)
    }

    private fun deleteExternalMediaItems(sourceUriValues: List<String>, result: MethodChannel.Result) {
        val sourceUris = sourceUriValues
            .mapNotNull { value -> value.takeUnless { it.isBlank() }?.let(Uri::parse) }
        if (sourceUris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }
        val mediaStoreUris = sourceUris.filter { uri ->
            uri.scheme == "content" &&
                uri.authority == MediaStore.AUTHORITY &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        }
        if (mediaStoreUris.isNotEmpty() && pendingDeleteResult != null) {
            result.error("BUSY", "A delete request is already pending", null)
            return
        }
        val directUris = sourceUris.filterNot { uri -> mediaStoreUris.contains(uri) }
        val deletedDirectUris = mutableListOf<String>()
        if (directUris.isNotEmpty()) {
            try {
                for (uri in directUris) {
                    deleteExternalMediaDirect(uri)
                    deletedDirectUris.add(uri.toString())
                }
            } catch (error: Exception) {
                lastImportDebugInfo =
                    "导入诊断：批量删除失败\n" +
                        "${error.javaClass.simpleName}: ${error.message}"
                result.error("DELETE_FAILED", error.message ?: "Unable to delete media", null)
                return
            }
        }
        if (mediaStoreUris.isNotEmpty()) {
            try {
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, mediaStoreUris)
                pendingDeleteResult = result
                pendingExternalDeleteUri = mediaStoreUris.singleOrNull()
                pendingExternalDeleteUris = mediaStoreUris
                pendingExternalDeletedUris = deletedDirectUris
                lastImportDebugInfo = "导入诊断：已发起系统批量删除授权\ncount=${mediaStoreUris.size}"
                @Suppress("DEPRECATION")
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    requestCodeDeleteMedia,
                    null,
                    0,
                    0,
                    0,
                )
            } catch (error: Exception) {
                Log.w(logTag, "MediaStore delete request failed", error)
                pendingDeleteResult = null
                pendingExternalDeleteUri = null
                pendingExternalDeleteUris = null
                pendingExternalDeletedUris = emptyList()
                lastImportDebugInfo =
                    "导入诊断：系统删除授权创建失败\ncount=${mediaStoreUris.size}\n" +
                        "${error.javaClass.simpleName}: ${error.message}"
                result.error("DELETE_FAILED", error.message ?: "Unable to delete media", null)
            }
            return
        }
        result.success(deletedDirectUris)
    }

    private fun deleteExternalMediaDirect(sourceUri: Uri) {
        val deleted = try {
            if (sourceUri.scheme == "file") {
                File(sourceUri.path ?: "").delete()
            } else if (DocumentsContract.isDocumentUri(this, sourceUri) || DocumentsContract.isTreeUri(sourceUri)) {
                DocumentsContract.deleteDocument(contentResolver, sourceUri)
            } else {
                contentResolver.delete(sourceUri, null, null) > 0
            }
        } catch (error: Exception) {
            Log.w(logTag, "deleteExternalMedia failed", error)
            false
        }
        if (!deleted) {
            throw IllegalStateException("Unable to delete external media")
        }
    }

    private fun mediaUriStillExists(uri: Uri): Boolean {
        return try {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns._ID),
                null,
                null,
                null,
            )?.use { cursor ->
                cursor.moveToFirst()
            } ?: false
        } catch (error: Exception) {
            false
        }
    }

    private fun importExternalMedia(
        sourceUriValue: String,
        displayName: String,
        requestedType: String?,
        albumName: String?,
        albumRelativePath: String?,
        useSystemLibrary: Boolean,
    ): String {
        val sourceUri = Uri.parse(sourceUriValue)
        val sourceMime = contentResolver.getType(sourceUri)
            ?: mimeTypeFromName(displayName)
            ?: if (requestedType == "video") "video/mp4" else "image/jpeg"
        val mediaType = if (requestedType == "video" || sourceMime.startsWith("video/")) {
            "video"
        } else {
            "photo"
        }
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
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    importRelativePath(mediaType, albumName, albumRelativePath, useSystemLibrary)
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val destinationUri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create MediaStore item")
        try {
            openSourceInputStream(sourceUri).use { input ->
                contentResolver.openOutputStream(destinationUri).use { output ->
                    if (input == null || output == null) {
                        throw IllegalStateException("Unable to open import streams")
                    }
                    input.copyTo(output)
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val completeValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                contentResolver.update(destinationUri, completeValues, null, null)
            }
            rememberImported(sourceUri, displayName)
            return destinationUri.toString()
        } catch (error: Exception) {
            try {
                contentResolver.delete(destinationUri, null, null)
            } catch (_: Exception) {}
            throw error
        }
    }

    private fun importRelativePath(
        mediaType: String,
        albumName: String?,
        albumRelativePath: String?,
        useSystemLibrary: Boolean,
    ): String {
        val baseDir = if (mediaType == "video") {
            Environment.DIRECTORY_MOVIES
        } else {
            Environment.DIRECTORY_PICTURES
        }
        if (useSystemLibrary) {
            return baseDir
        }
        val existingPath = albumRelativePath
            ?.trim()
            ?.trim('/')
            ?.takeIf { it.isNotBlank() }
        if (existingPath != null) {
            return existingPath
        }
        val safeAlbumName = albumName
            ?.trim()
            ?.trim('/')
            ?.takeIf { it.isNotBlank() }
            ?: "RePhoto"
        return "$baseDir/$safeAlbumName"
    }

    private fun mimeTypeFromName(displayName: String): String? {
        val extension = MimeTypeMap.getFileExtensionFromUrl(displayName)
            .takeUnless { it.isNullOrBlank() }
            ?: displayName.substringAfterLast('.', missingDelimiterValue = "")
        if (extension.isBlank()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase(Locale.US))
            ?: rawImageMimeTypeFromExtension(extension)
    }

    private fun rawImageMimeTypeFromName(displayName: String): String? {
        val extension = MimeTypeMap.getFileExtensionFromUrl(displayName)
            .takeUnless { it.isNullOrBlank() }
            ?: displayName.substringAfterLast('.', missingDelimiterValue = "")
        if (extension.isBlank()) return null
        return rawImageMimeTypeFromExtension(extension)
    }

    private fun rawImageMimeTypeFromExtension(extension: String): String? {
        return when (extension.lowercase(Locale.US)) {
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
        val name = File(displayName).name.trim().takeUnless { it.isEmpty() }
            ?: if (mediaType == "video") "RePhoto-import.mp4" else "RePhoto-import.jpg"
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
    }

    private fun rememberImported(sourceUri: Uri, displayName: String) {
        val fingerprint = buildImportFingerprint(
            displayName,
            queryDocumentLong(sourceUri, DocumentsContract.Document.COLUMN_SIZE),
            queryDocumentLong(sourceUri, DocumentsContract.Document.COLUMN_LAST_MODIFIED) ?: 0L,
        )
        externalImportPrefs.edit()
            .putBoolean("$importFingerprintPrefix$fingerprint", true)
            .apply()
    }

    private fun openSourceInputStream(uri: Uri): InputStream? {
        if (uri.scheme == "file") {
            val path = uri.path ?: return null
            return File(path).inputStream()
        }
        return contentResolver.openInputStream(uri)
    }

    private fun isPreviouslyImported(
        displayName: String,
        sizeBytes: Long?,
        modifiedAtMillis: Long,
    ): Boolean {
        val fingerprint = buildImportFingerprint(displayName, sizeBytes, modifiedAtMillis)
        return externalImportPrefs.getBoolean("$importFingerprintPrefix$fingerprint", false)
    }

    private fun buildImportFingerprint(
        displayName: String,
        sizeBytes: Long?,
        modifiedAtMillis: Long,
    ): String {
        return listOf(
            displayName.trim().lowercase(Locale.US),
            sizeBytes?.toString() ?: "",
            modifiedAtMillis.toString(),
        ).joinToString("|")
    }

    private fun queryDocumentLong(uri: Uri, columnName: String): Long? {
        if (uri.scheme == "file") {
            val file = File(uri.path ?: return null)
            return when (columnName) {
                DocumentsContract.Document.COLUMN_SIZE -> file.length()
                DocumentsContract.Document.COLUMN_LAST_MODIFIED -> file.lastModified()
                else -> null
            }
        }
        return try {
            contentResolver.query(uri, arrayOf(columnName), null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                readLong(cursor, cursor.getColumnIndex(columnName))
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveContentUri(baseUri: Uri, rawId: String): Uri? {
        val numericId = rawId.toLongOrNull() ?: return null
        return ContentUris.withAppendedId(baseUri, numericId)
    }

    private fun mediaReadPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                Manifest.permission.ACCESS_MEDIA_LOCATION,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.ACCESS_MEDIA_LOCATION,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.ACCESS_MEDIA_LOCATION,
            )
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun hasFullMediaReadPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) ==
                PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VIDEO) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasLimitedMediaReadPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return false
        }
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun buildLocationKey(latitude: Double?, longitude: Double?): String? {
        if (latitude == null || longitude == null) {
            return null
        }
        if (latitude == 0.0 && longitude == 0.0) {
            return null
        }
        val lat = String.format(Locale.US, "%.3f", latitude)
        val lon = String.format(Locale.US, "%.3f", longitude)
        return "geo/$lat/$lon"
    }

    private fun readCachedLocationKey(mediaId: String): String? {
        return locationCachePrefs.getString("$locationCachePrefix$mediaId", null)
    }

    private fun writeCachedLocationKey(mediaId: String, locationKey: String) {
        if (locationKey.isBlank()) return
        locationCachePrefs.edit()
            .putString("$locationCachePrefix$mediaId", locationKey)
            .apply()
    }

    private fun hasPreciseCoordinate(locationKey: String): Boolean {
        return locationKey.contains("/@")
    }

    private fun readAllLocationAliases(): Map<String, String> {
        val all = locationCachePrefs.all
        if (all.isEmpty()) return emptyMap()
        val result = mutableMapOf<String, String>()
        for ((key, value) in all) {
            if (!key.startsWith(aliasCachePrefix)) continue
            val locationKey = key.removePrefix(aliasCachePrefix)
            val alias = value?.toString()?.trim()
            if (locationKey.isNotBlank() && !alias.isNullOrBlank()) {
                result[locationKey] = alias
            }
        }
        return result
    }

    private fun parseTypedMediaId(value: String): Pair<String, String>? {
        val parts = value.split(':', limit = 2)
        if (parts.size != 2) {
            return null
        }
        val type = parts[0]
        val rawId = parts[1]
        if ((type != "photo" && type != "video") || rawId.isBlank()) {
            return null
        }
        return type to rawId
    }

    private fun readLong(cursor: android.database.Cursor, columnIndex: Int): Long? {
        if (columnIndex < 0 || cursor.isNull(columnIndex)) {
            return null
        }
        return cursor.getLong(columnIndex)
    }

    private fun readInt(cursor: android.database.Cursor, columnIndex: Int): Int? {
        if (columnIndex < 0 || cursor.isNull(columnIndex)) {
            return null
        }
        return cursor.getInt(columnIndex)
    }

    private fun readDouble(cursor: android.database.Cursor, columnIndex: Int): Double? {
        if (columnIndex < 0 || cursor.isNull(columnIndex)) {
            return null
        }
        return cursor.getDouble(columnIndex)
    }

    private fun readString(cursor: android.database.Cursor, columnIndex: Int): String? {
        if (columnIndex < 0 || cursor.isNull(columnIndex)) {
            return null
        }
        return cursor.getString(columnIndex)
    }

    private fun saveDeletionStats(args: Map<*, *>?) {
        localStatePrefs.edit()
            .putInt(deletionPhotoCountKey, intArg(args, "photoCount"))
            .putInt(deletionVideoCountKey, intArg(args, "videoCount"))
            .putLong(deletionKnownSizeBytesKey, longArg(args, "knownSizeBytes"))
            .putBoolean(deletionHasUnknownSizeKey, args?.get("hasUnknownSize") == true)
            .apply()
    }

    private fun loadDeletionStats(): Map<String, Any> {
        return mapOf(
            "photoCount" to localStatePrefs.getInt(deletionPhotoCountKey, 0),
            "videoCount" to localStatePrefs.getInt(deletionVideoCountKey, 0),
            "knownSizeBytes" to localStatePrefs.getLong(deletionKnownSizeBytesKey, 0L),
            "hasUnknownSize" to localStatePrefs.getBoolean(deletionHasUnknownSizeKey, false),
        )
    }

    private fun saveBrowseProgress(args: Map<*, *>?) {
        val collectionId = args?.get("collectionId") as? String
        val mediaId = args?.get("mediaId") as? String
        if (collectionId.isNullOrBlank() || mediaId.isNullOrBlank()) {
            return
        }
        localStatePrefs.edit()
            .putString("$browseProgressPrefix$collectionId", mediaId)
            .apply()
    }

    private fun loadBrowseProgress(args: Map<*, *>?): String? {
        val collectionId = args?.get("collectionId") as? String
        if (collectionId.isNullOrBlank()) {
            return null
        }
        return localStatePrefs.getString("$browseProgressPrefix$collectionId", null)
    }

    private fun intArg(args: Map<*, *>?, key: String): Int {
        val raw = args?.get(key)
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Number -> raw.toInt()
            is String -> raw.toIntOrNull() ?: 0
            else -> 0
        }
    }

    private fun longArg(args: Map<*, *>?, key: String): Long {
        val raw = args?.get(key)
        return when (raw) {
            is Long -> raw
            is Int -> raw.toLong()
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull() ?: 0L
            else -> 0L
        }
    }

    private data class NativeMediaItem(
        val id: String,
        val type: String,
        val createdAtMillis: Long,
        val locationKey: String?,
        val pathOrUri: String,
        val sizeBytes: Long?,
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "id" to id,
                "type" to type,
                "createdAtMillis" to createdAtMillis,
                "locationKey" to locationKey,
                "pathOrUri" to pathOrUri,
                "sizeBytes" to sizeBytes,
                "size" to sizeBytes,
            )
        }
    }

    private data class NativeExternalImportItem(
        val id: String,
        val type: String,
        val displayName: String,
        val createdAtMillis: Long,
        val sizeBytes: Long?,
        val pathOrUri: String,
        val imported: Boolean,
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "id" to id,
                "type" to type,
                "displayName" to displayName,
                "createdAtMillis" to createdAtMillis,
                "sizeBytes" to sizeBytes,
                "size" to sizeBytes,
                "pathOrUri" to pathOrUri,
                "imported" to imported,
            )
        }
    }

    private data class NativeDocumentChild(
        val id: String,
        val name: String,
        val mimeType: String,
        val modifiedAtMillis: Long,
        val sizeBytes: Long?,
        val isDirectory: Boolean,
    )
}
