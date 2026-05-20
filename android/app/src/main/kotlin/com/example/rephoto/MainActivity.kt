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
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val logTag = "RePhotoMedia"
    private val permissionsChannelName = "rephoto/mobile_permissions"
    private val mediaChannelName = "rephoto/mobile_media"
    private val externalImportChannelName = "rephoto/external_import"
    private val requestCodeMediaRead = 9201
    private val requestCodeDeleteMedia = 9202
    private val requestCodeImportRoot = 9203
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingImportRootResult: MethodChannel.Result? = null
    private var pendingDeleteIds: Set<String>? = null
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
    private val importRootUriKey = "import_root_uri"
    private val importFingerprintPrefix = "imported_v1_"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, externalImportChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSavedImportRoot" -> result.success(readSavedImportRoot())
                    "listImportRoots" -> result.success(listImportRoots())
                    "requestImportRoot" -> {
                        val rootId = call.argument<String>("rootId")
                        requestImportRoot(result, rootId)
                    }
                    "scanImportRoot" -> runAsync(result) { scanImportRoot().map { it.toMap() } }
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
                        val albumName = call.argument<String>("albumName") ?: "RePhoto"
                        if (sourceUri.isNullOrBlank() || displayName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "sourceUri/displayName is empty", null)
                        } else {
                            runAsync(result) {
                                importExternalMedia(sourceUri, displayName, type, albumName)
                            }
                        }
                    }
                    "deleteExternalMedia" -> {
                        val sourceUri = call.argument<String>("sourceUri")
                        if (sourceUri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "sourceUri is empty", null)
                        } else {
                            runAsync(result) {
                                deleteExternalMedia(sourceUri)
                                null
                            }
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
                pendingDeleteResult?.success(null)
            } else {
                Log.w(logTag, "User denied deletion")
                pendingDeleteResult?.error("DENIED", "User denied deletion request", null)
            }
            pendingDeleteResult = null
            pendingDeleteIds = null
        } else if (requestCode == requestCodeImportRoot) {
            val result = pendingImportRootResult
            pendingImportRootResult = null
            if (resultCode == android.app.Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val flags = data.flags and (
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                try {
                    contentResolver.takePersistableUriPermission(uri, flags)
                } catch (error: Exception) {
                    Log.w(logTag, "Persist import root permission failed", error)
                }
                val value = uri.toString()
                externalImportPrefs.edit().putString(importRootUriKey, value).apply()
                result?.success(value)
            } else {
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
        val projection = arrayOf(
            MediaStore.MediaColumns.BUCKET_ID,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
        )
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val id = cursor.getString(idIndex) ?: continue
                val name = cursor.getString(nameIndex) ?: continue
                val existing = albums.getOrPut(id) {
                    mutableMapOf<String, Any>(
                        "id" to id,
                        "name" to name,
                        "count" to 0,
                    )
                }
                existing["count"] = ((existing["count"] as? Int) ?: 0) + 1
            }
        }
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
        if (value.isNullOrBlank()) return null
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
                    mapOf(
                        "id" to (uuid ?: description),
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
        val intent = buildImportRootPickerIntent(rootId).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            putExtra("android.provider.extra.SHOW_ADVANCED", true)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, requestCodeImportRoot)
    }

    private fun buildImportRootPickerIntent(rootId: String? = null): Intent {
        if (!rootId.isNullOrBlank() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val storageManager = getSystemService(StorageManager::class.java)
                val selected = storageManager.storageVolumes
                    .filter { volume ->
                        volume.isRemovable && volume.state == Environment.MEDIA_MOUNTED
                    }
                    .firstOrNull { volume ->
                        volume.uuid == rootId || volume.getDescription(this) == rootId
                    }
                @Suppress("DEPRECATION")
                val directAccessIntent = selected?.createAccessIntent(null)
                if (directAccessIntent != null) {
                    return directAccessIntent
                }
            } catch (error: Exception) {
                Log.w(logTag, "Unable to build direct storage access intent", error)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val storageManager = getSystemService(StorageManager::class.java)
                val removable = storageManager.storageVolumes
                    .filter { volume ->
                        volume.isRemovable && volume.state == Environment.MEDIA_MOUNTED
                    }
                    .firstOrNull { volume ->
                        rootId.isNullOrBlank() ||
                            volume.uuid == rootId ||
                            volume.getDescription(this) == rootId
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

    private fun scanImportRoot(): List<NativeExternalImportItem> {
        val root = readSavedImportRoot() ?: return emptyList()
        val treeUri = Uri.parse(root)
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val items = mutableListOf<NativeExternalImportItem>()
        scanDocumentTree(treeUri, rootDocumentId, items)
        return items.sortedByDescending { it.createdAtMillis }
    }

    private fun scanDocumentTree(
        treeUri: Uri,
        documentId: String,
        items: MutableList<NativeExternalImportItem>,
    ) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
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
                    scanDocumentTree(treeUri, childId, items)
                    continue
                }
                val name = readString(cursor, nameColumn) ?: childId.substringAfterLast('/')
                val mediaType = externalMediaType(name, mimeType) ?: continue
                val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
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

    private fun externalMediaType(displayName: String, mimeType: String): String? {
        if (mimeType.startsWith("image/")) return "photo"
        if (mimeType.startsWith("video/")) return "video"
        val lower = displayName.lowercase(Locale.US)
        return when {
            lower.endsWith(".jpg") ||
                lower.endsWith(".jpeg") ||
                lower.endsWith(".png") ||
                lower.endsWith(".heic") ||
                lower.endsWith(".heif") ||
                lower.endsWith(".webp") -> "photo"
            lower.endsWith(".mp4") ||
                lower.endsWith(".mov") ||
                lower.endsWith(".m4v") ||
                lower.endsWith(".avi") ||
                lower.endsWith(".mkv") -> "video"
            else -> null
        }
    }

    private fun fetchExternalPreviewImageData(pathOrUri: String): ByteArray? {
        val uri = Uri.parse(pathOrUri)
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
            contentResolver.openInputStream(uri)?.use { input ->
                input.readBytes()
            }
        } catch (error: Exception) {
            Log.d(logTag, "fetchExternalFullImageData failed: ${error.message}")
            null
        }
    }

    private fun deleteExternalMedia(sourceUriValue: String) {
        val sourceUri = Uri.parse(sourceUriValue)
        val deleted = try {
            DocumentsContract.deleteDocument(contentResolver, sourceUri)
        } catch (error: Exception) {
            Log.w(logTag, "deleteExternalMedia failed", error)
            false
        }
        if (!deleted) {
            throw IllegalStateException("Unable to delete external media")
        }
    }

    private fun importExternalMedia(
        sourceUriValue: String,
        displayName: String,
        requestedType: String?,
        albumName: String,
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
                val baseDir = if (mediaType == "video") {
                    Environment.DIRECTORY_MOVIES
                } else {
                    Environment.DIRECTORY_PICTURES
                }
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$baseDir/$albumName")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val destinationUri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create MediaStore item")
        try {
            contentResolver.openInputStream(sourceUri).use { input ->
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

    private fun mimeTypeFromName(displayName: String): String? {
        val extension = MimeTypeMap.getFileExtensionFromUrl(displayName)
            .takeUnless { it.isNullOrBlank() }
            ?: displayName.substringAfterLast('.', missingDelimiterValue = "")
        if (extension.isBlank()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase(Locale.US))
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
}
