package top.onemorejack.phototend

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaProjectionPolicyTest {
    @Test
    fun mixedMediaProjectionNeverIncludesImageOnlyXmpColumn() {
        val projection = buildMediaProjection(
            baseColumns = listOf("_id", "media_type"),
            xmpColumn = "xmp",
            imageOnly = false,
        )

        assertFalse(projection.contains("xmp"))
    }

    @Test
    fun imageProjectionCanIncludeXmpColumn() {
        val projection = buildMediaProjection(
            baseColumns = listOf("_id"),
            xmpColumn = "xmp",
            imageOnly = true,
        )

        assertTrue(projection.contains("xmp"))
    }
}
