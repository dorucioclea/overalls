package dev.overalls.mila.nativeui
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
private class SignInAdapter(private val result: MilaFfiResult): MilaFfiAdapter { override suspend fun call(request: MilaFfiRequest)=result }

private class LifecycleAdapter(private val result: MilaFfiResult): MilaFfiAdapter, MilaSessionConnector {
 var clearedSessions = 0
 override suspend fun call(request: MilaFfiRequest) = result
 override fun connect(deployment: MilaDeployment, config: MilaSessionConnectConfig, signer: MilaDeviceKey): MilaSessionHandle? = null
 override fun bindSession(session: MilaSessionHandle?) { if (session == null) clearedSessions++ }
}

private class LifecycleStore : MilaDeploymentStore {
 var deployment: MilaDeployment? = null
 var approval = MilaApprovalState.Approved
 override fun read() = deployment
 override fun write(value: MilaDeployment) { deployment = value }
 override fun clear() { deployment = null }
 override fun readApproval() = approval
 override fun writeApproval(value: MilaApprovalState) { approval = value }
}

class MilaSignInStateTest {
 @Test fun sessionConnectConfigRejectsMissingTrustAndKey() {
  assertThrows(IllegalArgumentException::class.java) { MilaSessionConnectConfig(byteArrayOf(), "ssh-key") }
  assertThrows(IllegalArgumentException::class.java) { MilaSessionConnectConfig(byteArrayOf(1), "") }
 }

 @Test fun successfulBootstrapProducesSignedInListing() = runBlocking {
  val payload = MilaFfiPayload("{\"machines\":[],\"has_more\":false}".toByteArray())
  val d=MilaDeployment("mila.example"); val c=MilaSignInController(SignInAdapter(MilaFfiResult.Success(MilaFfiResponse(payload))))
  c.signIn(d); assertEquals(MilaSignInState.SignedIn(d, MilaSessionListing(emptyList(),false)), c.state)
 }
 @Test fun failedBootstrapRetainsDeploymentAndError() = runBlocking {
  val d=MilaDeployment("mila.example"); val c=MilaSignInController(SignInAdapter(MilaFfiResult.Failure(MilaFfiError.Unavailable)))
  c.signIn(d); assertEquals(MilaSignInState.Failed(d,MilaFfiError.Unavailable), c.state)
 }

 @Test fun reconnectClearsStaleApprovalBeforeFailedAttempt() = runBlocking {
  val d = MilaDeployment("mila.example")
  val store = LifecycleStore()
  val controller = MilaSignInController(
   SignInAdapter(MilaFfiResult.Failure(MilaFfiError.Unavailable)), store
  )
  store.write(d)
  assertFalse(controller.reconnect())
  assertEquals(MilaApprovalState.NotRequired, store.readApproval())
 }

 @Test fun closingControllerReleasesSessionAndKeepsReconnectSelection() = runBlocking {
  val d = MilaDeployment("mila.example")
  val store = LifecycleStore()
  val adapter = LifecycleAdapter(
   MilaFfiResult.Success(MilaFfiResponse(MilaFfiPayload("{\"machines\":[],\"has_more\":false}".toByteArray())))
  )
  val controller = MilaSignInController(adapter, store)

  controller.signIn(d)
  assertEquals(1, adapter.clearedSessions)
  controller.close()
  assertEquals(MilaSignInState.SignedOut, controller.state)
  assertEquals(2, adapter.clearedSessions)
  assertEquals(d, store.read())

  assertTrue(controller.reconnect())
  assertEquals(3, adapter.clearedSessions)
  assertEquals(MilaSignInState.SignedIn(d, MilaSessionListing(emptyList(), false)), controller.state)
 }
}
