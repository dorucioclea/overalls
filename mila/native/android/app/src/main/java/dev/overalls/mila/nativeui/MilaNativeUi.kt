package dev.overalls.mila.nativeui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.OutlinedTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.State
import androidx.compose.runtime.remember
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.Locale
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

internal data class MachineCommandChoice(val label: String, val command: String)

/**
 * @cc [owner:ghuntley,label:architecture] android-machine-command-catalog
 * Every machine command presented by the Android shell MUST be classified through the closed
 * Rust command catalog before it is shown as selected; the UI must not invent operation tags.
 */
internal val machineCommandChoices = listOf(
    MachineCommandChoice("List", "ls"),
    MachineCommandChoice("Show", "show"),
    MachineCommandChoice("New", "new"),
    MachineCommandChoice("Resize", "resize"),
    MachineCommandChoice("Start", "start"),
    MachineCommandChoice("Stop", "stop"),
    MachineCommandChoice("Pause", "pause"),
    MachineCommandChoice("Resume", "resume"),
    MachineCommandChoice("Delete", "rm"),
    MachineCommandChoice("Share add", "share add"),
    MachineCommandChoice("Share remove", "share remove"),
    MachineCommandChoice("Web show", "web show"),
    MachineCommandChoice("Web set", "web set"),
)

/** Commands exposed by the Rust thread catalog; arguments are intentionally not accepted here. */
internal val threadCommandChoices = listOf(
    "List" to "thread ls",
    "Show" to "thread show",
    "Turns" to "thread turns",
    "Prompt" to "thread prompt",
    "Answer" to "thread answer",
    "Plan approve" to "thread plan approve",
    "Plan revise" to "thread plan revise",
    "Mode" to "thread mode",
    "Read" to "thread read",
)

/**
 * @cc [owner:ghuntley,label:security] android-native-deployment-selection
 * The Android shell MUST offer only persisted or user-validated deployments. It MUST NOT invent a
 * host, call the session-material provider without a selected deployment, or pass a different host
 * to that provider than the one selected by the user.
 */
@Composable
fun MilaNativeRoot(
    adapter: MilaFfiAdapter? = null,
    materialProvider: MilaSessionMaterialProvider? = null,
    initialRoute: MilaRoute? = null,
    routeState: State<MilaRoute>? = null,
    appLockController: MilaAppLockController? = null,
    onAuthenticatedRoute: (() -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    // Keep the default native adapter across recompositions. A live Rust session is
    // owned by this adapter and must not be replaced by a recomposition.
    val sessionAdapter = remember(adapter) { adapter ?: LinkedMilaFfiAdapter() }
    val sessionMaterialProvider = remember(materialProvider, context) {
        materialProvider ?: AndroidMilaSessionMaterialProvider(context)
    }
    val approvalBrowser = remember(context) { AndroidMilaApprovalBrowser(context) }
    var route by remember { mutableStateOf(initialRoute ?: MilaRoute.Machines) }
    LaunchedEffect(routeState?.value) { routeState?.value?.let { route = it } }
    LaunchedEffect(initialRoute) { initialRoute?.let { route = it } }
    var connection by remember { mutableStateOf<MilaSessionConnection>(MilaSessionConnection.Idle) }
    val localContext = LocalContext.current
    val deploymentStore = remember(localContext) { MilaSharedPreferencesDeploymentStore(localContext.getSharedPreferences("mila.deployment", 0)) }
    val savedDeployments = remember { deploymentStore.readAll() }
    val deployment = remember { MilaDeploymentSelection(savedDeployments) }
    var selectedDeployment by remember { mutableStateOf(deployment.selected) }
    var deploymentEntries by remember { mutableStateOf(deployment.deployments) }
    var hostInput by remember { mutableStateOf(selectedDeployment?.host.orEmpty()) }
    var hostInvalid by remember { mutableStateOf(false) }
    val signIn = remember(sessionAdapter) { MilaSignInController(sessionAdapter, deploymentStore) }
    val machineDetail = remember(sessionAdapter) { MilaMachineDetailController(sessionAdapter) }
    val threadDetail = remember(sessionAdapter) { MilaThreadDetailController(sessionAdapter) }
    var signInState by remember { mutableStateOf<MilaSignInState>(MilaSignInState.SignedOut) }
    LaunchedEffect(signInState) {
        if (signInState is MilaSignInState.SignedIn) onAuthenticatedRoute?.invoke()
    }
    var threadListing by remember { mutableStateOf<MilaThreadListing?>(null) }
    // Changing the selected deployment fences the authenticated session immediately. This keeps
    // machine/thread data from the previous host from remaining actionable while the user edits
    // or switches deployments.
    fun resetSessionForDeploymentChange() {
        signIn.close()
        signInState = MilaSignInState.SignedOut
        threadListing = null
    }
    DisposableEffect(signIn) {
        onDispose { signIn.close() }
    }
    fun refresh() { scope.launch {
        connection = MilaSessionConnection.Refreshing
        connection = MilaSessionRefresher.refresh(sessionAdapter)
    } }
    fun reconnect(selected: MilaDeployment) { scope.launch {
        signInState = MilaSignInState.Connecting(selected)
        sessionMaterialProvider.resolve(selected).fold(
            onSuccess = { material ->
                signIn.reconnect(material.config, material.signer)
                signInState = signIn.state
            },
            onFailure = { signInState = MilaSignInState.Failed(selected, MilaFfiError.Unavailable) },
        )
    } }
    val status = when (connection) {
        MilaSessionConnection.Idle -> MilaStrings.text(MilaMessage.Ready)
        MilaSessionConnection.Refreshing -> MilaStrings.text(MilaMessage.Connecting)
        is MilaSessionConnection.Connected -> MilaStrings.text(MilaMessage.Connected)
        is MilaSessionConnection.Failed -> MilaStrings.text(MilaMessage.RuntimeUnavailable)
    }
    val listing = (signInState as? MilaSignInState.SignedIn)?.listing ?: (connection as? MilaSessionConnection.Connected)?.listing
    machineDetail.setSession(signInState is MilaSignInState.SignedIn, listing)
    threadDetail.setSession(signInState is MilaSignInState.SignedIn, threadListing)
    Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(MilaStrings.text(MilaMessage.AppName), style = MaterialTheme.typography.headlineSmall)
        MilaDeploymentPicker(
            deployments = deploymentEntries,
            selected = selectedDeployment,
            host = hostInput,
            invalidHost = hostInvalid,
            onHostChanged = {
                hostInput = it
                hostInvalid = false
            },
            onSelect = { selected ->
                if (selectedDeployment != selected) resetSessionForDeploymentChange()
                deployment.select(selected.host, selected.port)
                deploymentStore.write(selected)
                selectedDeployment = selected
                hostInput = selected.label
                hostInvalid = false
            },
            onAdd = {
                parseMilaDeploymentHost(hostInput).fold(
                    onSuccess = { added ->
                        if (selectedDeployment != added) resetSessionForDeploymentChange()
                        deployment.add(added)
                        deployment.select(added.host, added.port)
                        deploymentStore.write(added)
                        deploymentEntries = deployment.deployments
                        selectedDeployment = added
                        hostInput = added.label
                        hostInvalid = false
                    },
                    onFailure = { hostInvalid = true },
                )
            },
            onForget = { forgotten ->
                if (deployment.remove(forgotten.host, forgotten.port)) {
                    deploymentStore.remove(forgotten)
                    deploymentEntries = deployment.deployments
                    selectedDeployment = deployment.selected
                    hostInput = selectedDeployment?.label.orEmpty()
                    hostInvalid = false
                    resetSessionForDeploymentChange()
                }
            },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button({
                selectedDeployment?.let { selected ->
                    scope.launch {
                        signInState = MilaSignInState.Connecting(selected)
                        sessionMaterialProvider.resolve(selected).fold(
                            onSuccess = { material ->
                                signIn.signIn(selected, material.config, material.signer)
                                signInState = signIn.state
                            },
                            onFailure = {
                                signInState = MilaSignInState.Failed(selected, MilaFfiError.Unavailable)
                            },
                        )
                    }
                }
            }, enabled = selectedDeployment != null) { Text(MilaStrings.text(MilaMessage.SignIn)) }
            Button({ route = MilaRoute.Machines }) { Text(MilaStrings.text(MilaMessage.Machines)) }
            Button({ route = MilaRoute.Threads }) { Text(MilaStrings.text(MilaMessage.Threads)) }
            Button({ route = MilaRoute.Settings }) { Text(MilaStrings.text(MilaMessage.Settings)) }
            Button(enabled = signInState is MilaSignInState.SignedIn, onClick = { context.startActivity(MilaShareIntentFactory.authenticatedChooser(route, signInState is MilaSignInState.SignedIn)!!) }) { Text("Share") }
            Button(::refresh) { Text(MilaStrings.text(MilaMessage.Refresh)) }
        }
        Text(status, style = MaterialTheme.typography.labelSmall)
        if (signInState is MilaSignInState.AwaitingApproval) {
            val awaiting = signInState as MilaSignInState.AwaitingApproval
            LaunchedEffect(awaiting.approval.url) { approvalBrowser.open(awaiting.approval) }
            Text(MilaStrings.text(MilaMessage.ApprovalPending), style = MaterialTheme.typography.bodyMedium)
            Text("${MilaStrings.text(MilaMessage.ApprovalFingerprint)}: ${awaiting.approval.fingerprint}", style = MaterialTheme.typography.labelSmall)
            Button({ approvalBrowser.open(awaiting.approval) }) {
                Text(MilaStrings.text(MilaMessage.OpenApproval))
            }
        }
        if (signInState is MilaSignInState.Expired) {
            Text(MilaStrings.text(MilaMessage.ApprovalExpired), style = MaterialTheme.typography.bodyMedium)
            selectedDeployment?.let { selected ->
                Button({ reconnect(selected) }) { Text(MilaStrings.text(MilaMessage.Reconnect)) }
            }
        }
        if (signInState is MilaSignInState.SignedIn) Text(MilaStrings.text(MilaMessage.Connected), style = MaterialTheme.typography.labelSmall)
        when (val selected = route) {
            MilaRoute.Machines -> MachineList(sessionAdapter, status, listing, signInState is MilaSignInState.SignedIn, ::refresh) { route = MilaRoute.Machine(it.id); machineDetail.select(it.id) }
            is MilaRoute.Machine -> MachineDetail(machineDetail, selected.id, sessionAdapter, signInState is MilaSignInState.SignedIn, listing)
            MilaRoute.Threads -> ThreadList(sessionAdapter, signInState is MilaSignInState.SignedIn, threadListing, onRefresh = {
                scope.launch { threadListing = sessionAdapter.threadListing().getOrNull() }
            }) { route = MilaRoute.Thread(it); threadDetail.select(it) }
            is MilaRoute.Thread -> ThreadDetail(threadDetail, selected.id) {
                scope.launch { threadListing = sessionAdapter.threadListing().getOrNull() }
            }
            MilaRoute.Settings -> MilaSettingsScreen(sessionAdapter, signInState is MilaSignInState.SignedIn, appLockController)
        }
        if (route == MilaRoute.Machines && signInState is MilaSignInState.SignedIn) TerminalControls(sessionAdapter)
    }
    LaunchedEffect(signIn) {
        val saved = selectedDeployment
        if (saved != null) {
            sessionMaterialProvider.resolve(saved).onSuccess { material ->
                signIn.signIn(saved, material.config, material.signer)
                signInState = signIn.state
            }
        }
    }
    LaunchedEffect(signInState) {
        while (signInState is MilaSignInState.AwaitingApproval) {
            delay(2_000)
            signIn.pollApproval()
            signInState = signIn.state
        }
    }
    LaunchedEffect(signInState) {
        if (signInState is MilaSignInState.SignedIn) {
            threadListing = sessionAdapter.threadListing().getOrNull()
        } else {
            threadListing = null
        }
    }
}

@Composable
private fun MilaDeploymentPicker(
    deployments: List<MilaDeployment>,
    selected: MilaDeployment?,
    host: String,
    invalidHost: Boolean,
    onHostChanged: (String) -> Unit,
    onSelect: (MilaDeployment) -> Unit,
    onAdd: () -> Unit,
    onForget: (MilaDeployment) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(MilaStrings.text(MilaMessage.Deployments), style = MaterialTheme.typography.titleMedium)
        deployments.forEach { deployment ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button({ onSelect(deployment) }, enabled = deployment != selected) {
                    Text(deployment.label, style = MaterialTheme.typography.bodyMedium)
                }
                Button({ onForget(deployment) }) {
                    Text(MilaStrings.text(MilaMessage.ForgetDeployment))
                }
            }
        }
        OutlinedTextField(
            value = host,
            onValueChange = onHostChanged,
            label = { Text(MilaStrings.text(MilaMessage.DeploymentHost)) },
            placeholder = { Text(MilaStrings.text(MilaMessage.DeploymentHostHint)) },
            isError = invalidHost,
            singleLine = true,
        )
        if (invalidHost) {
            Text(MilaStrings.text(MilaMessage.InvalidHost), style = MaterialTheme.typography.labelSmall)
        }
        Button({ onAdd() }, enabled = host.isNotBlank()) {
            Text(MilaStrings.text(MilaMessage.AddDeployment))
        }
    }
}

@Composable
private fun MilaSettingsScreen(adapter: MilaFfiAdapter, signedIn: Boolean, appLockController: MilaAppLockController? = null) {
    val context = LocalContext.current
    val controller = remember { MilaSettingsController(MilaSharedPreferencesStore(context.getSharedPreferences("mila.settings", 0))) }
    var settings by remember { mutableStateOf(controller.load()) }
    // Keep locale choices finite and sourced from the shared catalog bundles. A user supplied
    // locale is still validated by MilaSettings before it reaches persistence.
    val localeChoices = MilaStrings.supportedLocales
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(MilaStrings.text(MilaMessage.Settings), style = MaterialTheme.typography.titleLarge)
        Text("${MilaStrings.text(MilaMessage.Appearance)}: ${settings.appearance}")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MilaAppearance.entries.forEach { appearance ->
                Button({ settings = settings.copy(appearance = appearance); controller.save(settings) }) { Text(appearance.name) }
            }
        }
        Text("${MilaStrings.text(MilaMessage.Locale)}: ${settings.locale}")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            localeChoices.forEach { localeTag ->
                Button(onClick = {
                    val canonical = canonicalMilaLocale(localeTag) ?: return@Button
                    settings = settings.copy(locale = canonical)
                    controller.save(settings)
                    MilaStrings.configure(context, Locale.forLanguageTag(canonical))
                }, enabled = settings.locale != localeTag) {
                    Text(localeTag)
                }
            }
        }
        appLockController?.let { lock ->
            Text(MilaStrings.text(MilaMessage.LockTitle), style = MaterialTheme.typography.titleMedium)
            Text(if (lock.state.availability == MilaLockAvailability.Unavailable) MilaStrings.text(MilaMessage.LockExplain) else "${lock.state.phase}: ${lock.state.delay}")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { lock.setEnabled(!lock.state.enabled) }, enabled = lock.state.availability == MilaLockAvailability.Available && lock.state.phase == MilaLockPhase.Unlocked) {
                    Text(if (lock.state.enabled) "Disable" else "Enable")
                }
                MilaLockDelay.entries.forEach { delay ->
                    Button(onClick = { lock.setDelay(delay) }, enabled = lock.state.phase == MilaLockPhase.Unlocked && lock.state.enabled) { Text(delay.name) }
                }
            }
        }
        MilaSshKeysPanel(adapter, signedIn)
    }
}

@Composable
private fun MilaSshKeysPanel(adapter: MilaFfiAdapter, signedIn: Boolean) {
    val store = adapter.sshKeyStore()
    val controller = remember(store) { MilaSshKeyController(store) }
    var keys by remember(controller) { mutableStateOf(controller.keys) }
    LaunchedEffect(store, signedIn) {
        controller.bindStore(if (signedIn) store else null)
        keys = controller.keys
    }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(MilaStrings.text(MilaMessage.SshKeysTitle), style = MaterialTheme.typography.titleMedium)
        Text(MilaStrings.text(MilaMessage.SshKeysExplain), style = MaterialTheme.typography.bodySmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { controller.refresh(); keys = controller.keys }, enabled = signedIn && store != null) {
                Text(MilaStrings.text(MilaMessage.Refresh))
            }
        }
        if (!signedIn || store == null) {
            Text(MilaStrings.text(MilaMessage.RuntimeUnavailable), style = MaterialTheme.typography.labelSmall)
        } else if (keys.isEmpty()) {
            Text(MilaStrings.text(MilaMessage.SshKeysEmpty), style = MaterialTheme.typography.labelSmall)
        } else {
            keys.forEach { key ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Column(modifier = Modifier.width(120.dp)) {
                        Text(key.label.ifBlank { key.fingerprint })
                        Text("${MilaStrings.text(MilaMessage.SshKeyAlgorithm)}: ${key.algorithm}", style = MaterialTheme.typography.labelSmall)
                        Text(key.fingerprint, style = MaterialTheme.typography.labelSmall)
                    }
                    if (key.isCurrentDevice) {
                        Text(MilaStrings.text(MilaMessage.SshKeyThisDevice), style = MaterialTheme.typography.labelSmall)
                    } else {
                        Button(onClick = { if (controller.revoke(key)) keys = controller.keys }, enabled = signedIn) {
                            Text(MilaStrings.text(MilaMessage.SshKeyRevoke))
                        }
                    }
                }
            }
        }
    }
}

@Composable private fun TerminalControls(adapter: MilaFfiAdapter) {
    var result by remember { mutableStateOf("Terminal idle") }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(MilaStrings.text(MilaMessage.Terminal), style = MaterialTheme.typography.titleMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button({ result = if (adapter.terminalAttach(0, 80, 24, true).isSuccess) "Attached" else "Attach rejected" }) { Text(MilaStrings.text(MilaMessage.Attach)) }
            Button({ result = if (adapter.terminalInput(0, true).isSuccess) "Input ready" else "Input rejected" }) { Text(MilaStrings.text(MilaMessage.Input)) }
            Button({ result = if (adapter.terminalResize(80, 24, true).isSuccess) "Resized" else "Resize rejected" }) { Text(MilaStrings.text(MilaMessage.Resize)) }
        }
        Text(result, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable private fun MachineList(adapter: MilaFfiAdapter, status: String, listing: MilaSessionListing?, signedIn: Boolean, onCreated: () -> Unit, onSelect: (MilaMachineRow) -> Unit) {
    var classified by remember { mutableStateOf<MilaMachineCommand?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(status, style = MaterialTheme.typography.bodyMedium)
        listing?.machines?.forEach { machine ->
            Button({ onSelect(machine) }) { Text("${machine.name} · ${machine.status}", style = MaterialTheme.typography.bodyMedium) }
        }
        if (signedIn) MachineCreateControls(adapter, onCreated)
        Text(MilaStrings.text(MilaMessage.MachineActions), style = MaterialTheme.typography.titleMedium)
        machineCommandChoices.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { choice ->
                    Button({ classified = adapter.machineCommandKind(choice.command).getOrNull() }) {
                        Text(choice.label)
                    }
                }
            }
        }
        Text(classified?.name ?: MilaStrings.text(MilaMessage.NoAction), style = MaterialTheme.typography.labelSmall)
    }
}

@Composable private fun MachineCreateControls(adapter: MilaFfiAdapter, onCreated: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var cpu by remember { mutableStateOf("2") }
    var memory by remember { mutableStateOf("1024") }
    var disk by remember { mutableStateOf("20") }
    var result by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(MilaStrings.text(MilaMessage.MachineCreate), style = MaterialTheme.typography.titleMedium)
        OutlinedTextField(name, { name = it }, label = { Text(MilaStrings.text(MilaMessage.MachineName)) }, singleLine = true)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(cpu, { cpu = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineCpu)) }, singleLine = true, modifier = Modifier.width(120.dp))
            OutlinedTextField(memory, { memory = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineMemory)) }, singleLine = true, modifier = Modifier.width(120.dp))
            OutlinedTextField(disk, { disk = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineDisk)) }, singleLine = true, modifier = Modifier.width(120.dp))
        }
        Button(enabled = !submitting, onClick = {
            val request = runCatching { MilaMachineCreateRequest(name, cpu.toInt(), memory.toInt(), disk.toInt()) }
            scope.launch {
                submitting = true
                result = request.fold(
                    onSuccess = { value -> adapter.createMachine(value).fold({ onCreated(); MilaStrings.text(MilaMessage.MachineCreated) }, { MilaStrings.text(MilaMessage.MachineCreateFailed) }) },
                    onFailure = { MilaStrings.text(MilaMessage.MachineCreateFailed) },
                )
                submitting = false
            }
        }) { Text(MilaStrings.text(MilaMessage.MachineCreate)) }
        if (result.isNotEmpty()) Text(result, style = MaterialTheme.typography.labelSmall)
    }
}

private fun validResize(cpu: String, memory: String, disk: String): Boolean = listOf(cpu, memory, disk).all { it.toIntOrNull() in 1..1_000_000 }

@Composable private fun MachineDetail(controller: MilaMachineDetailController, id: java.util.UUID, adapter: MilaFfiAdapter, signedIn: Boolean, listing: MilaSessionListing?) {
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf(controller.state) }
    var resizeCpu by remember { mutableStateOf("2") }
    var resizeMemory by remember { mutableStateOf("1024") }
    var resizeDisk by remember { mutableStateOf("20") }
    var resizeResult by remember { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(MilaStrings.text(MilaMessage.MachineActions), style = MaterialTheme.typography.titleLarge)
        Text(id.toString(), style = MaterialTheme.typography.labelSmall)
        val currentState = state
        val machine = when (currentState) {
            is MilaMachineMutationState.Ready -> (currentState as MilaMachineMutationState.Ready).machine
            is MilaMachineMutationState.Submitting -> (currentState as MilaMachineMutationState.Submitting).machine
            is MilaMachineMutationState.Applied -> (currentState as MilaMachineMutationState.Applied).machine
            is MilaMachineMutationState.Failed -> (currentState as MilaMachineMutationState.Failed).machine
            else -> null
        }
        if (machine != null) Text("${machine.name} · ${machine.status}")
        machineCommandChoices.filter { it.command in setOf("start", "stop", "pause", "resume", "rm", "resize") }.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { choice ->
                    Button(
                        enabled = signedIn,
                        onClick = {
                            controller.select(id)
                            controllerSelect(controller, choice.command, scope) { state = controller.state }
                        },
                    ) { Text(choice.label) }
                }
            }
        }
        if (machine != null) {
            Text(MilaStrings.text(MilaMessage.Resize), style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedTextField(resizeCpu, { resizeCpu = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineCpu)) }, singleLine = true, modifier = Modifier.width(120.dp))
                OutlinedTextField(resizeMemory, { resizeMemory = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineMemory)) }, singleLine = true, modifier = Modifier.width(120.dp))
                OutlinedTextField(resizeDisk, { resizeDisk = it.filter(Char::isDigit) }, label = { Text(MilaStrings.text(MilaMessage.MachineDisk)) }, singleLine = true, modifier = Modifier.width(120.dp))
                Button(enabled = signedIn && validResize(resizeCpu, resizeMemory, resizeDisk), onClick = { scope.launch {
                    val cpu = resizeCpu.toIntOrNull()!!
                    val memory = resizeMemory.toIntOrNull()!!
                    val disk = resizeDisk.toIntOrNull()!!
                    resizeResult = adapter.machineResize(id, cpu, memory, disk).fold({ "Resize submitted" }, { "Resize rejected" })
                } }) { Text(MilaStrings.text(MilaMessage.Resize)) }
            }
            if (resizeResult.isNotEmpty()) Text(resizeResult, style = MaterialTheme.typography.labelSmall)
        }
        MachineSharingControls(adapter, machine, signedIn, listing)
        if (machine != null) MilaWebControls(adapter, machine, signedIn)
        Text(
            when (val current = controller.state) {
                MilaMachineMutationState.SignedOut -> MilaStrings.text(MilaMessage.RuntimeUnavailable)
                MilaMachineMutationState.Idle -> MilaStrings.text(MilaMessage.NoAction)
                is MilaMachineMutationState.Ready -> "Ready"
                is MilaMachineMutationState.Submitting -> "Submitting ${current.command.name}"
                is MilaMachineMutationState.Applied -> "Applied ${current.command.name}"
                is MilaMachineMutationState.Failed -> current.reason
            },
            style = MaterialTheme.typography.labelSmall,
        )
    }
}

@Composable
private fun MachineSharingControls(adapter: MilaFfiAdapter, machine: MilaMachineRow?, signedIn: Boolean, listing: MilaSessionListing?) {
    var principal by remember { mutableStateOf("") }
    var result by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    // Sharing commands are classified and submitted by the typed controller.
    val controller = remember { MilaMachineSharingController(adapter) }
    LaunchedEffect(controller, signedIn, listing, machine?.id) {
        controller.setSession(signedIn, listing)
        if (machine != null) controller.setMachine(machine)
    }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        OutlinedTextField(value = principal, onValueChange = { principal = it }, label = { Text(MilaStrings.text(MilaMessage.SharePrincipal)) })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(enabled = signedIn && machine != null, onClick = { scope.launch { result = if (controller.submit(principal)) MilaStrings.text(MilaMessage.ShareAdded) else MilaStrings.text(MilaMessage.ShareRejected) } }) { Text(MilaStrings.text(MilaMessage.ShareAdd)) }
            Button(enabled = signedIn && machine != null, onClick = { scope.launch { result = if (controller.submit(principal, remove = true)) MilaStrings.text(MilaMessage.ShareRemoved) else MilaStrings.text(MilaMessage.ShareRejected) } }) { Text(MilaStrings.text(MilaMessage.ShareRemove)) }
        }
        if (result.isNotEmpty()) Text(result, style = MaterialTheme.typography.labelSmall)
    }
}

private fun controllerSelect(controller: MilaMachineDetailController, command: String, scope: kotlinx.coroutines.CoroutineScope, onComplete: () -> Unit) {
    val value = MilaMachineCommand.entries.firstOrNull { it.name.equals(command, ignoreCase = true) }
        ?: when (command) { "rm" -> MilaMachineCommand.Delete; else -> null }
        ?: return
    scope.launch { controller.submit(value); onComplete() }
}

@Composable private fun ThreadDetail(
    controller: MilaThreadDetailController,
    id: java.util.UUID,
    onActionApplied: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var input by remember { mutableStateOf("") }
    var actionState by remember { mutableStateOf(controller.state) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(value = input, onValueChange = { if (boundedTerminalInput(it)) input = it }, label = { Text(MilaStrings.text(MilaMessage.Input)) })
        Text(MilaStrings.text(MilaMessage.ThreadCommands), style = MaterialTheme.typography.titleLarge)
        Text(id.toString(), style = MaterialTheme.typography.labelSmall)
        threadCommandChoices.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (label, raw) ->
                    Button(enabled = controller.canSubmit(), onClick = {
                        val command = when (raw) {
                            "thread ls" -> MilaThreadCommand.List
                            "thread show" -> MilaThreadCommand.Show
                            "thread turns" -> MilaThreadCommand.Turns
                            "thread prompt" -> MilaThreadCommand.Prompt
                            "thread answer" -> MilaThreadCommand.Answer
                            "thread plan approve" -> MilaThreadCommand.PlanApprove
                            "thread plan revise" -> MilaThreadCommand.PlanRevise
                            "thread mode" -> MilaThreadCommand.Mode
                            "thread read" -> MilaThreadCommand.Read
                            else -> null
                        } ?: return@Button
                        scope.launch {
                            val payload = input.takeIf { command == MilaThreadCommand.Prompt || command == MilaThreadCommand.Answer || command == MilaThreadCommand.PlanRevise }
                            controller.submit(command, payload)
                            actionState = controller.state
                            if (actionState is MilaThreadActionState.Applied) onActionApplied()
                        }
                    }) { Text(label) }
                }
            }
        }
        Text(
            when (val state = actionState) {
                MilaThreadActionState.SignedOut -> MilaStrings.text(MilaMessage.RuntimeUnavailable)
                MilaThreadActionState.Idle -> MilaStrings.text(MilaMessage.NoCommand)
                is MilaThreadActionState.Ready -> "${state.thread.title} · ${state.thread.status}"
                is MilaThreadActionState.Submitting -> "${MilaStrings.text(MilaMessage.Connecting)} ${state.command.name}"
                is MilaThreadActionState.Applied -> "${MilaStrings.text(MilaMessage.Connected)} ${state.command.name}"
                is MilaThreadActionState.Failed -> state.reason
            }, style = MaterialTheme.typography.labelSmall,
        )
    }
}

@Composable private fun ThreadList(
    adapter: MilaFfiAdapter,
    signedIn: Boolean,
    listing: MilaThreadListing?,
    onRefresh: () -> Unit,
    onSelect: (java.util.UUID) -> Unit,
) {
    var classified by remember { mutableStateOf<MilaThreadCommand?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(MilaStrings.text(MilaMessage.ThreadCommands), style = MaterialTheme.typography.titleLarge)
        Button(onClick = onRefresh, enabled = signedIn) { Text(MilaStrings.text(MilaMessage.Refresh)) }
        listing?.threads?.forEach { thread ->
            Button({ onSelect(thread.id) }) { Text("${thread.title} · ${thread.status}") }
        }
        if (!signedIn) Text(MilaStrings.text(MilaMessage.RuntimeUnavailable), style = MaterialTheme.typography.labelSmall)
        threadCommandChoices.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { (label, command) ->
                    Button({ classified = adapter.threadCommandKind(command).getOrNull() }, enabled = signedIn) { Text(label) }
                }
            }
        }
        Text(classified?.name ?: MilaStrings.text(MilaMessage.NoCommand), style = MaterialTheme.typography.bodyMedium)
    }
}
@Composable private fun Detail(title: String, value: String) { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Text(title, style = MaterialTheme.typography.titleLarge); Text(value, style = MaterialTheme.typography.bodyMedium) } }
