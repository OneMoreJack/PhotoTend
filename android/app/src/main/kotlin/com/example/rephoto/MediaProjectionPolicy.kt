package com.example.rephoto

internal fun buildMediaProjection(
    baseColumns: List<String>,
    xmpColumn: String,
    imageOnly: Boolean,
): List<String> {
    return if (imageOnly) baseColumns + xmpColumn else baseColumns
}
