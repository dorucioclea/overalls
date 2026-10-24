package dev.overalls.mila.nativeui

import org.junit.Assert.*
import org.junit.Test

class MilaWebTest {
 @Test fun webViewStaysOnEndpointOrigin() {
  assertTrue(isAllowedMilaWebTarget("https://box.example.test/app", "https://box.example.test/next"))
  assertFalse(isAllowedMilaWebTarget("https://box.example.test/app", "https://other.example.test/next"))
  assertFalse(isAllowedMilaWebTarget("https://box.example.test/app", "http://box.example.test/next"))
  assertFalse(isAllowedMilaWebTarget("https://box.example.test/app", "https://box.example.test:444/next"))
 }

 @Test fun webViewRequiresExactNonDefaultPort() {
  assertTrue(isAllowedMilaWebTarget("https://box.example.test:8443/app", "https://box.example.test:8443/next"))
  assertFalse(isAllowedMilaWebTarget("https://box.example.test:8443/app", "https://box.example.test/next"))
  // An explicit default port is the same HTTPS origin as an omitted port.
  assertTrue(isAllowedMilaWebTarget("https://box.example.test/app", "https://box.example.test:443/next"))
 }

 @Test fun webViewRejectsCredentialAndFragmentTargets() {
  assertFalse(isAllowedMilaWebTarget("https://box.example.test/app", "https://user:pass@box.example.test/next"))
  assertFalse(isAllowedMilaWebTarget("https://box.example.test/app", "https://box.example.test/next#secret"))
 }

 @Test fun parsesSafeEndpoint() {
  val result = parseMilaWebEndpoint("{\"machine_id\":\"00000000-0000-0000-0000-000000000001\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2,\"url\":\"https://box.example.test\"}")
  assertTrue(result.isSuccess); assertEquals(8080, result.getOrThrow().port)
 }
 @Test fun rejectsUnsafeUrl() {
  val result = parseMilaWebEndpoint("{\"machine_id\":\"00000000-0000-0000-0000-000000000001\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2,\"url\":\"javascript:alert(1)\"}")
  assertTrue(result.isFailure)
 }
 @Test fun rejectsUrlWhosePortDoesNotMatchEndpoint() {
  val result = parseMilaWebEndpoint("{\"machine_id\":\"00000000-0000-0000-0000-000000000001\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2,\"url\":\"https://box.example.test:8443\"}")
  assertTrue(result.isFailure)
 }
 @Test fun rejectsInvalidPortAndVisibility() {
  val result = parseMilaWebEndpoint("{\"machine_id\":\"00000000-0000-0000-0000-000000000001\",\"port\":0,\"visibility\":\"public\",\"policy_revision\":2}")
  assertTrue(result.isFailure)
 }
 @Test fun controllerRejectsEndpointForAnotherMachine() = kotlinx.coroutines.runBlocking {
  val foreign = java.util.UUID.fromString("00000000-0000-0000-0000-000000000002")
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID) = Result.success("{\"machine_id\":\"$foreign\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2}")
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  assertFalse(controller.show(java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")))
  assertNull(controller.endpoint)
 }
 @Test fun controllerClearDropsPreviousAuthenticatedEndpoint() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID) = Result.success("{\"machine_id\":\"$id\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2}")
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  assertTrue(controller.show(id)); assertNotNull(controller.endpoint)
  controller.clear(); assertNull(controller.endpoint); assertNull(controller.error)
 }
 @Test fun setRequiresLoadedRevisionAndUsesIt() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  var seenRevision = -1L
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID) = Result.success("{\"machine_id\":\"$id\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":7}")
   override suspend fun webSet(machineId: java.util.UUID, port: Int, public: Boolean, revision: Long): Result<Unit> {
    seenRevision = revision
    return Result.success(Unit)
   }
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  assertFalse(controller.set(id, 8081, false))
  assertTrue(controller.show(id))
  assertTrue(controller.set(id, 8081, false))
  assertEquals(7L, seenRevision)
 }

 @Test fun setReportsRevisionConflictWithoutLosingLoadedEndpoint() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID) = Result.success("{\"machine_id\":\"$id\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":7}")
   override suspend fun webSet(machineId: java.util.UUID, port: Int, public: Boolean, revision: Long): Result<Unit> =
    Result.failure(IllegalStateException("policy revision mismatch"))
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  assertTrue(controller.show(id))
  assertFalse(controller.set(id, 8081, false))
  assertEquals("web policy revision conflict", controller.error)
  assertEquals(7L, controller.endpoint?.revision)
 }
 @Test fun staleShowAfterSignOutCannotRestoreEndpoint() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  val gate = kotlinx.coroutines.CompletableDeferred<String>()
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID): Result<String> = Result.success(gate.await())
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  val job = kotlinx.coroutines.launch { assertFalse(controller.show(id)) }
  kotlinx.coroutines.yield()
  controller.setSession(false)
  gate.complete("{\"machine_id\":\"$id\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2}")
  job.join()
  assertNull(controller.endpoint)
 }

 @Test fun changingSessionGenerationClearsLoadedEndpoint() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
   override suspend fun webShow(machineId: java.util.UUID) = Result.success("{\"machine_id\":\"$id\",\"port\":8080,\"visibility\":\"public\",\"policy_revision\":2}")
  }
  val controller = MilaWebController(adapter)
  controller.setSession(true)
  assertTrue(controller.show(id)); assertNotNull(controller.endpoint)
  controller.setSession(true)
  assertNull(controller.endpoint)
 }

 @Test fun signedOutControllerRefusesWebShow() = kotlinx.coroutines.runBlocking {
  val id = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001")
  val adapter = object : MilaFfiAdapter {
   override suspend fun call(request: MilaFfiRequest) = MilaFfiResult.Failure(MilaFfiError.Unavailable)
  }
  val controller = MilaWebController(adapter)
  assertFalse(controller.show(id)); assertNull(controller.endpoint)
 }
}
