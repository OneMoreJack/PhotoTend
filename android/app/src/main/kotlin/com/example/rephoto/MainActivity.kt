package com.example.rephoto

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.Uri
import android.location.Geocoder
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val logTag = "RePhotoMedia"
    private val permissionsChannelName = "rephoto/mobile_permissions"
    private val mediaChannelName = "rephoto/mobile_media"
    private val requestCodeMediaRead = 9201
    private val requestCodeDeleteMedia = 9202
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteIds: Set<String>? = null
    private var useLegacyPaging = false
    private var legacyMediaSnapshot: List<NativeMediaItem>? = null
    private val locationCachePrefs by lazy {
        getSharedPreferences("rephoto_location_cache", MODE_PRIVATE)
    }
    private val locationCachePrefix = "location_v1_"
    private val aliasCachePrefix = "alias_v1_"

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
}
