package com.example.rephoto

internal const val importVolumeRootPrefix = "volume://"

internal fun resolveDetectedImportVolumeRoot(
    requestedRootId: String?,
    mountedVolumeIds: Set<String>,
): String? {
    val rootId = requestedRootId?.takeIf { it.isNotBlank() } ?: return null
    return if (mountedVolumeIds.contains(rootId)) {
        "$importVolumeRootPrefix$rootId"
    } else {
        null
    }
}

internal interface ExternalImportPageItem {
    val id: String
    val createdAtMillis: Long
}

internal data class ImportPageEntry(
    override val id: String,
    override val createdAtMillis: Long,
) : ExternalImportPageItem

internal data class ExternalImportPage<T : ExternalImportPageItem>(
    val items: List<T>,
    val hasMore: Boolean,
)

internal fun <T : ExternalImportPageItem> buildExternalImportPage(
    snapshot: List<T>,
    offset: Int,
    limit: Int,
): ExternalImportPage<T> {
    val safeOffset = offset.coerceAtLeast(0)
    val safeLimit = limit.coerceIn(1, 200)
    val sorted = snapshot.sortedWith(
        compareByDescending<T> { it.createdAtMillis }.thenBy { it.id }
    )
    val end = (safeOffset + safeLimit).coerceAtMost(sorted.size)
    val pageItems = if (safeOffset >= sorted.size) {
        emptyList()
    } else {
        sorted.subList(safeOffset, end)
    }
    return ExternalImportPage(
        items = pageItems,
        hasMore = sorted.size > end,
    )
}
