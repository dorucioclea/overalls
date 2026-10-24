package dev.overalls.mila.nativeui

import org.junit.Assert.assertEquals
import org.junit.Test

class MilaSessionListingTest {
    @Test fun decodesBoundedValidatedRows() {
        val listing = MilaSessionListing.decode("{\"machines\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"build\",\"status\":\"running\"}],\"has_more\":true}".toByteArray())
        assertEquals("build", listing.machines.single().name)
        assertEquals(true, listing.hasMore)
    }
    @Test fun capsMachineProjectionAndMarksMore() {
        val rows = (1..257).joinToString(",") { i -> "{\"id\":\"00000000-0000-0000-0000-${i.toString().padStart(12, '0')}\",\"name\":\"m$i\",\"status\":\"running\"}" }
        val listing = MilaSessionListing.decode("{\"machines\":[$rows]}".toByteArray())
        assertEquals(256, listing.machines.size)
        assertEquals(true, listing.hasMore)
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsMalformedRows() {
        MilaSessionListing.decode("{\"machines\":[{\"id\":\"bad\"}]}".toByteArray())
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsUnsafeDisplayText() {
        MilaSessionListing.decode("{\"machines\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"bad\\nname\"}]}".toByteArray())
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsOversizedDisplayText() {
        val name = "x".repeat(129)
        MilaSessionListing.decode("{\"machines\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"$name\"}]}".toByteArray())
    }
}
