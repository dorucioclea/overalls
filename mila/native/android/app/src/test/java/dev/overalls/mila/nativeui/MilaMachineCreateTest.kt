package dev.overalls.mila.nativeui

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

private class CreateAdapter : MilaFfiAdapter {
    var request: MilaFfiRequest? = null
    override suspend fun call(request: MilaFfiRequest): MilaFfiResult {
        this.request = request
        return MilaFfiResult.Success(MilaFfiResponse(MilaFfiPayload(byteArrayOf())))
    }
}

class MilaMachineCreateTest {
    @Test fun validatesAndEncodesTypedRequest() = runBlocking {
        val adapter = CreateAdapter()
        assertTrue(adapter.createMachine(MilaMachineCreateRequest("dev\"box", 2, 1024, 20)).isSuccess)
        val payload = adapter.request!!.payload.copyBytes().toString(Charsets.UTF_8)
        assertTrue(payload.contains("dev\\\"box"))
        assertTrue(payload.contains("\"memory_mib\":1024"))
    }

    @Test fun rejectsInvalidResources() {
        assertThrows(IllegalArgumentException::class.java) { MilaMachineCreateRequest("", 1, 256, 1) }
        assertThrows(IllegalArgumentException::class.java) { MilaMachineCreateRequest("x", 0, 256, 1) }
    }
}
