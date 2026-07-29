package com.example.rephoto

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExternalImportRootTest {
    @Test
    fun mountedDetectedVolumeResolvesWithoutDirectoryPicker() {
        val root = resolveDetectedImportVolumeRoot(
            requestedRootId = "1234-ABCD",
            mountedVolumeIds = setOf("1234-ABCD"),
        )

        assertEquals("volume://1234-ABCD", root)
    }

    @Test
    fun missingDetectedVolumeDoesNotResolve() {
        val root = resolveDetectedImportVolumeRoot(
            requestedRootId = "1234-ABCD",
            mountedVolumeIds = emptySet(),
        )

        assertNull(root)
    }
}
