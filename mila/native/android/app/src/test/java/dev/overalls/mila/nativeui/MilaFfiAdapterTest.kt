package dev.overalls.mila.nativeui

import kotlinx.coroutines.runBlocking
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class MilaFfiAdapterTest {
    @Test
    fun payloadCopiesInputAndOutput() {
        val input = byteArrayOf(1, 2, 3)
        val payload = MilaFfiPayload(input)
        input[0] = 9

        val output = payload.copyBytes()
        output[1] = 8

        assertArrayEquals(byteArrayOf(1, 2, 3), payload.copyBytes())
    }

    @Test
    fun unavailableAdapterFailsWithoutLeakingPayload() = runBlocking {
        val request = MilaFfiRequest(
            operation = MilaFfiOperation.Bootstrap,
            payload = MilaFfiPayload(byteArrayOf(4, 5)),
        )

        val result = UnavailableMilaFfiAdapter.call(request)

        assertEquals(MilaFfiResult.Failure(MilaFfiError.Unavailable), result)
    }

    @Test
    fun linkedAdapterReportsUnavailableWhenNativeLibraryIsAbsent() = runBlocking {
        val result = LinkedMilaFfiAdapter().call(MilaFfiRequest(MilaFfiOperation.Refresh))

        assertTrue(result is MilaFfiResult.Failure)
        assertEquals(MilaFfiError.Unavailable, (result as MilaFfiResult.Failure).error)
    }
}

class MilaSessionRefresherTest {
    @Test
    fun refreshPublishesTypedListing() = runBlocking {
        val listing = "{\"machines\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"demo\",\"status\":\"running\"}],\"has_more\":false}"
        val adapter = object : MilaFfiAdapter {
            override suspend fun call(request: MilaFfiRequest): MilaFfiResult = MilaFfiResult.Success(
                MilaFfiResponse(MilaFfiPayload(listing.toByteArray()))
            )
        }
        val state = MilaSessionRefresher.refresh(adapter)
        assertEquals("demo", (state as MilaSessionConnection.Connected).listing.machines.single().name)
    }

    @Test
    fun malformedListingFailsClosed() = runBlocking {
        val adapter = object : MilaFfiAdapter {
            override suspend fun call(request: MilaFfiRequest): MilaFfiResult = MilaFfiResult.Success(
                MilaFfiResponse(MilaFfiPayload("not-json".toByteArray()))
            )
        }
        assertTrue(MilaSessionRefresher.refresh(adapter) is MilaSessionConnection.Failed)
    }
}

private open class FakeRustBindings(
    private val version: Int = 1,
    private val route: String? = "overalls://machines",
    private val actions: Int? = 5,
) : MilaRustBindings {
    override fun abiVersion(): Int = version
    override fun canonicalRoute(value: String): String? = route
    override fun machineActions(snapshot: ByteArray, host: String, port: Int?, index: Int): Int? = actions
    override fun sessionConnect(trust: ByteArray, host: String, publicKey: String, port: Int, timeoutMs: Int, signer: MilaDeviceKey): MilaSessionHandle? = null
    override fun threadCommandKind(value: String): Int = 1
    override fun machineCommandKind(value: String): Int = 10
    override fun terminalAttach(from: Long, columns: Int, rows: Int, readWrite: Boolean): Int = 0
    override fun terminalInput(length: Int, readWrite: Boolean): Int = 0
    override fun terminalResize(columns: Int, rows: Int, readWrite: Boolean): Int = 0
}

private class SessionReadBindings : FakeRustBindings() {
    val pages = mutableListOf<Boolean>()
    var closeCalls = 0

    override fun sessionRead(handle: Long, more: Boolean): Int {
        pages += more
        return 0
    }

    override fun sessionListing(handle: Long): ByteArray =
        "{\"machines\":[],\"has_more\":false}".toByteArray()

    override fun sessionSnapshot(handle: Long): ByteArray =
        "{\"machines\":[],\"has_more\":false}".toByteArray()

    override fun sessionClose(handle: Long): Int {
        closeCalls++
        return 0
    }
}

class MilaSessionHandleTest {
    @Test
    fun machineReadsUseTheInjectedAuthenticatedBinding() {
        val bindings = SessionReadBindings()
        val session = MilaSessionHandle(42L, bindings)

        assertEquals(0, session.readMachines())
        assertEquals(0, session.readMachines(more = true))
        assertEquals("{\"machines\":[],\"has_more\":false}", session.listing().toString(Charsets.UTF_8))
        assertEquals("{\"machines\":[],\"has_more\":false}", session.snapshot().toString(Charsets.UTF_8))
        session.close()

        assertEquals(listOf(false, true), bindings.pages)
        assertEquals(1, bindings.closeCalls)
        assertThrows(IllegalStateException::class.java) { session.listing() }
    }
}

private class TrustBindings : FakeRustBindings() {
    var seenPinned: ByteArray? = null
    var seenFetched: ByteArray? = null
    override fun reconcileTrust(pinned: ByteArray?, fetched: ByteArray?, host: String, now: Long): ByteArray? {
        seenPinned = pinned?.copyOf()
        seenFetched = fetched?.copyOf()
        return when {
            fetched?.contentEquals(byteArrayOf(9)) == true -> null
            fetched != null -> byteArrayOf(7, 7)
            pinned != null -> pinned.copyOf()
            else -> null
        }
    }
}

private class MemoryTrustStore(var value: ByteArray? = null) : MilaTrustStore {
    var writes = 0
    override fun read(host: String): ByteArray? = value?.copyOf()
    override fun write(host: String, document: ByteArray) { value = document.copyOf(); writes++ }
}

class MilaLinkedFfiAdapterTest {
    @Test
    fun pushRegistrationUsesRustValidatorWithoutRetainingToken() {
        val bindings = object : FakeRustBindings() {
            var seen: String? = null
            override fun pushRegistrationValidate(provider: Int, environment: Int, token: String, appId: String, deployment: String, endpoint: String?): Int {
                seen = token
                return if (provider == 1 && environment == 1 && endpoint == null) 0 else -4
            }
        }
        val adapter = LinkedMilaFfiAdapter(bindings)
        assertTrue(adapter.validatePushRegistration("provider-token", "com.example.mila", "mila.example", null).isSuccess)
        assertEquals("provider-token", bindings.seen)
        assertTrue(adapter.validatePushRegistration("", "com.example.mila", "mila.example", null).isFailure)
    }

    @Test
    fun linkedAdapterUsesTypedRustBindings() = runBlocking {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings())
        val payload = MilaFfiPayload(byteArrayOf(7, 8))
        val result = adapter.call(MilaFfiRequest(MilaFfiOperation.Bootstrap, payload))
        assertEquals(MilaFfiResult.Success(MilaFfiResponse(payload)), result)
    }

    @Test
    fun linkedAdapterRejectsIncompatibleAbi() = runBlocking {
        val result = LinkedMilaFfiAdapter(FakeRustBindings(version = 2))
            .call(MilaFfiRequest(MilaFfiOperation.Refresh))
        assertEquals(MilaFfiResult.Failure(MilaFfiError.IncompatibleAbi), result)
    }

    @Test
    fun canonicalRouteReturnsNativeResult() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings(route = "overalls://threads"))
        assertEquals(Result.success("overalls://threads"), adapter.canonicalizeRoute("overalls://threads"))
    }

    @Test
    fun canonicalRouteRejectsNativeNull() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings(route = null))
        assertTrue(adapter.canonicalizeRoute("bad").isFailure)
    }

    @Test
    fun machineActionsExposeOnlyRustPolicyBits() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings(actions = 9))
        assertEquals(Result.success(9), adapter.machineActions(byteArrayOf(1), "mgmt.example.test", 443, 0))
    }

    @Test
    fun machineActionsRejectInvalidSnapshot() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings(actions = null))
        assertTrue(adapter.machineActions(byteArrayOf(1), "mgmt.example.test", null, 0).isFailure)
    }

    @Test
    fun threadCommandKindUsesClosedRustTags() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings())
        assertEquals(Result.success(MilaThreadCommand.List), adapter.threadCommandKind("thread ls"))
    }

    @Test
    fun machineCommandKindUsesClosedRustTags() {
        val adapter = LinkedMilaFfiAdapter(FakeRustBindings())
        assertEquals(Result.success(MilaMachineCommand.ShareAdd), adapter.machineCommandKind("machine share add"))
    }

    @Test
    fun machineCommandPaletteCoversClosedRustCatalog() {
        assertEquals(
            listOf(
                "ls", "show", "new", "resize", "start", "stop", "pause", "resume", "rm",
                "share add", "share remove", "web show", "web set",
            ),
            machineCommandChoices.map { it.command },
        )
        assertEquals(MilaMachineCommand.entries.size, machineCommandChoices.size)
    }

    @Test
    fun threadCommandPaletteCoversClosedRustCatalog() {
        assertEquals(
            listOf(
                "thread ls", "thread show", "thread turns", "thread prompt", "thread answer",
                "thread plan approve", "thread plan revise", "thread mode", "thread read",
            ),
            threadCommandChoices.map { it.second },
        )
        assertEquals(MilaThreadCommand.entries.size, threadCommandChoices.size)
    }
}

class MilaTrustEnrollmentTest {
    @Test
    fun fetchedTrustIsRustSelectedAndPersisted() = runBlocking {
        val bindings = TrustBindings()
        val store = MemoryTrustStore()
        val result = MilaTrustEnrollment(bindings, store, MilaTrustFetcher { byteArrayOf(1) })
            .resolve("mila.example")
        assertArrayEquals(byteArrayOf(7, 7), result.getOrThrow())
        assertEquals(1, store.writes)
        assertArrayEquals(byteArrayOf(1), bindings.seenFetched)
    }

    @Test
    fun transportFailureUsesPinnedTrustWithoutReplacingIt() = runBlocking {
        val bindings = TrustBindings()
        val store = MemoryTrustStore(byteArrayOf(4))
        val result = MilaTrustEnrollment(bindings, store, MilaTrustFetcher { throw IOException("offline") })
            .resolve("mila.example")
        assertArrayEquals(byteArrayOf(4), result.getOrThrow())
        assertEquals(0, store.writes)
        assertEquals(null, bindings.seenFetched)
    }

    @Test
    fun conflictingFetchedTrustFailsClosedAndDoesNotPersist() = runBlocking {
        val bindings = TrustBindings()
        val store = MemoryTrustStore(byteArrayOf(4))
        val result = MilaTrustEnrollment(bindings, store, MilaTrustFetcher { byteArrayOf(9) })
            .resolve("mila.example")
        assertTrue(result.isFailure)
        assertEquals(0, store.writes)
    }

    @Test
    fun malformedFetchedTrustDoesNotFallBackToPinnedTrust() = runBlocking {
        val bindings = TrustBindings()
        val store = MemoryTrustStore(byteArrayOf(4))
        val result = MilaTrustEnrollment(bindings, store, MilaTrustFetcher {
            throw IllegalArgumentException("malformed trust response")
        }).resolve("mila.example")
        assertTrue(result.isFailure)
        assertEquals(0, store.writes)
        assertEquals(null, bindings.seenFetched)
    }
}

private class TerminalSessionBindings : FakeRustBindings() {
    val calls = mutableListOf<String>()
    override fun sessionTerminalAttach(handle: Long, from: Long, columns: Int, rows: Int, readWrite: Boolean): Int {
        calls += "attach:$handle:$from:$columns:$rows:$readWrite"; return 0
    }
    override fun sessionTerminalInput(handle: Long, length: Int, readWrite: Boolean): Int {
        calls += "input:$handle:$length:$readWrite"; return 0
    }
    override fun sessionTerminalResize(handle: Long, columns: Int, rows: Int, readWrite: Boolean): Int {
        calls += "resize:$handle:$columns:$rows:$readWrite"; return 0
    }
    override fun sessionClose(handle: Long): Int = 0
}

class MilaAuthenticatedTerminalTest {
    @Test
    fun terminalOperationsUseTheBoundAuthenticatedSession() {
        val bindings = TerminalSessionBindings()
        val adapter = LinkedMilaFfiAdapter(bindings)
        val session = MilaSessionHandle(91L, bindings)
        adapter.bindSession(session)

        assertTrue(adapter.terminalAttach(7L, 120, 40, true).isSuccess)
        assertTrue(adapter.terminalInput(4, true).isSuccess)
        assertTrue(adapter.terminalResize(100, 30, true).isSuccess)
        assertEquals(
            listOf("attach:91:7:120:40:true", "input:91:4:true", "resize:91:100:30:true"),
            bindings.calls,
        )
        adapter.bindSession(null)
        assertTrue(adapter.terminalAttach(0, 80, 24, false).isFailure)
    }
}
