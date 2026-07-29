package com.example.rephoto

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ExternalImportPagingTest {
    @Test
    fun refreshedSnapshotReturnsNewItemFirst() {
        val oldSnapshot = listOf(
            ImportPageEntry(id = "old", createdAtMillis = 100),
        )
        val refreshedSnapshot = oldSnapshot + ImportPageEntry(
            id = "new",
            createdAtMillis = 200,
        )

        val page = buildExternalImportPage(refreshedSnapshot, offset = 0, limit = 1)

        assertEquals(listOf("new"), page.items.map { it.id })
        assertTrue(page.hasMore)
    }

    @Test
    fun adjacentPagesAreSortedAndDoNotOverlap() {
        val snapshot = listOf(
            ImportPageEntry(id = "oldest", createdAtMillis = 100),
            ImportPageEntry(id = "newest", createdAtMillis = 300),
            ImportPageEntry(id = "middle", createdAtMillis = 200),
        )

        val first = buildExternalImportPage(snapshot, offset = 0, limit = 2)
        val second = buildExternalImportPage(snapshot, offset = 2, limit = 2)

        assertEquals(listOf("newest", "middle"), first.items.map { it.id })
        assertEquals(listOf("oldest"), second.items.map { it.id })
        assertTrue(first.hasMore)
        assertFalse(second.hasMore)
        assertTrue(first.items.map { it.id }.toSet().intersect(second.items.map { it.id }.toSet()).isEmpty())
    }
}
