import SwiftUI

/// Native presentation shell. Machine records are supplied by the validated Rust snapshot boundary.
public struct MilaNativeRootView: View {
    private let adapter: any MilaFFIAdapter
    @StateObject private var session: MilaDeploymentSessionController
    @State private var selection: MilaRoute = .machines
    @State private var machines: [MilaMachinePresentation] = []
    @State private var status = MilaStrings.text(.ready)
    @State private var showCreate = false
    @StateObject private var appLock = MilaAppLockController()
    @Environment(\.scenePhase) private var scenePhase

    public init(adapter: any MilaFFIAdapter = LinkedMilaFFIAdapter(), snapshot: MilaValidatedSnapshot? = nil) {
        self.adapter = adapter
        _machines = State(initialValue: snapshot?.machines ?? [])
        _session = StateObject(wrappedValue: MilaDeploymentSessionController { deployment in
            let signer = try MilaDeviceSigner(deploymentHost: deployment.host)
            return try LinkedMilaFFIAdapter(trust: deployment.trust, host: deployment.host, port: deployment.port, signer: signer)
        })
    }

    public var body: some View {
        MilaAppLockView(controller: appLock) {
        NavigationSplitView {
            List(selection: $selection) {
                Label(MilaStrings.text(.machines), systemImage: "desktopcomputer").tag(MilaRoute.machines)
                Label(MilaStrings.text(.threads), systemImage: "bubble.left.and.bubble.right").tag(MilaRoute.threads)
                Label(MilaStrings.text(.settings), systemImage: "gearshape").tag(MilaRoute.settings)
            }.navigationTitle(MilaStrings.text(.appName))
        } detail: {
            Group {
                switch selection {
                case .machines: MachinesView(machines: machines, create: { showCreate = true }) { selection = .machine(id: $0) }
                case .machine(let id): MachineDetailView(machine: machines.first { $0.id == id }, adapter: session.adapter() ?? adapter, signedIn: session.adapter() != nil)
                case .threads: ThreadsView(adapter: session.adapter() ?? adapter, select: { selection = .thread(id: $0) })
                case .thread(let id): ThreadDetailView(id: id, adapter: session.adapter() ?? adapter)
                case .settings: SettingsView(adapter: session.adapter() ?? adapter, lockController: appLock, session: session)
                }
            }
            .toolbar { ToolbarItem { Button(MilaStrings.text(.refresh)) { Task { await refresh() } } } }
            .safeAreaInset(edge: .bottom) { Text(status).font(.caption).foregroundStyle(.secondary).padding(4) }
        }.sheet(isPresented: $showCreate) {
            MilaMachineCreateView(adapter: session.adapter() ?? adapter) { result in
                status = result ? MilaStrings.text(.actionSubmitted) : MilaStrings.text(.actionNotSubmitted)
                if result { Task { await refresh() } }
            }
        }.milaDesignSystem().onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appLock.sceneDidEnterBackground()
            case .active: Task { await appLock.sceneWillEnterForeground() }
            default: break
            }
        }.task {
            await refresh()
        }
        }
    }

    private func refresh() async {
        do { let active = session.adapter() ?? adapter; let snapshot = try await active.refreshSnapshot(); machines = snapshot.machines; status = MilaStrings.text(.snapshotLoaded) }
        catch { status = MilaStrings.text(.noSnapshotLoaded); machines = [] }
    }
}

private struct MachinesView: View {
    let machines: [MilaMachinePresentation]
    let create: () -> Void
    let select: (UUID) -> Void
    var body: some View {
        List {
            if machines.isEmpty { ContentUnavailableView(MilaStrings.text(.machinesEmpty), systemImage: "desktopcomputer", description: Text(MilaStrings.text(.machinesHint))) }
            ForEach(machines) { machine in
                Button { select(machine.id) } label: {
                    VStack(alignment: .leading) { Text(machine.machine.name); Text(machine.machine.observedState ?? "unknown").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle(MilaStrings.text(.machines)).toolbar { ToolbarItem(placement: .primaryAction) { Button("＋") { create() }.accessibilityLabel("Create machine") } }
    }
}

private struct MilaMachineCreateView: View {
    let adapter: any MilaFFIAdapter
    let completed: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cpu = "2"
    @State private var memory = "2048"
    @State private var disk = "20"
    @State private var busy = false
    @State private var error = false
    var body: some View {
        NavigationStack { Form {
            TextField("Name", text: $name).textContentType(.nickname)
            TextField("CPU", text: $cpu)
            TextField("Memory (MiB)", text: $memory)
            TextField("Disk (GiB)", text: $disk)
            if error { Text(MilaStrings.text(.actionNotSubmitted)).foregroundStyle(.secondary) }
        }.navigationTitle("Create machine").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Create") { submit() }.disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }}
    }
    private func submit() {
        guard let c = UInt32(cpu), let m = UInt64(memory), let d = UInt64(disk), c > 0, m > 0, d > 0 else { error = true; return }
        busy = true
        Task {
            do { try await adapter.createMachine(name: name.trimmingCharacters(in: .whitespacesAndNewlines), cpu: c, memory: m, disk: d, requestID: UUID()); completed(true); dismiss() }
            catch { busy = false; self.error = true; completed(false) }
        }
    }
}

private struct MachineDetailView: View {
    let machine: MilaMachinePresentation?
    let adapter: any MilaFFIAdapter
    let signedIn: Bool
    @StateObject private var workflow: MilaMachineWorkflow
    @State private var classified = ""
    @State private var showTerminal = false
    @State private var webURL = ""
    @StateObject private var webControls = MilaWebControlsController()
    @State private var showWeb = false
    @State private var webLoading = false
    @State private var sharePrincipal = ""
    @State private var shareRole: MilaShareRole = .viewer
    @State private var resizeCPU = "2"
    @State private var resizeMemory = "2048"
    @State private var resizeDisk = "20"
    @State private var resizeStatus = ""
    @StateObject private var sharing: MilaMachineSharingController
    init(machine: MilaMachinePresentation?, adapter: any MilaFFIAdapter, signedIn: Bool = false) {
        self.machine = machine
        self.adapter = adapter
        self.signedIn = signedIn
        _workflow = StateObject(wrappedValue: MilaMachineWorkflow(adapter: adapter))
        _sharing = StateObject(wrappedValue: MilaMachineSharingController(adapter: adapter))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let machine {
                Text(machine.machine.name).font(.title)
                Text(machine.id.uuidString).font(.caption)
                Text(machine.machine.observedState ?? "unknown").foregroundStyle(.secondary)
                HStack {
                    TextField("CPU", text: $resizeCPU).frame(width: 60)
                    TextField("Memory MiB", text: $resizeMemory).frame(width: 110)
                    TextField("Disk GiB", text: $resizeDisk).frame(width: 100)
                    Button("Resize") { resize(machine) }.disabled(!machine.machine.write)
                }
                Text(resizeStatus).font(.caption).foregroundStyle(.secondary)
                Button(MilaStrings.text(.openTerminal)) { showTerminal = true }.disabled(!machine.machine.write)
                HStack {
                    TextField(MilaStrings.text(.sharePrincipal), text: $sharePrincipal)
                        .autocorrectionDisabled()
                    Picker("Role", selection: $shareRole) {
                        ForEach(MilaShareRole.allCases) { role in Text(role.rawValue.capitalized).tag(role) }
                    }.frame(maxWidth: 130)
                    Button(MilaStrings.text(.shareAdd)) { sharing.submit(principal: sharePrincipal, role: shareRole) }
                        .disabled(!signedIn || !machine.machine.write || sharePrincipal.isEmpty)
                    Button(MilaStrings.text(.shareRemove)) { sharing.submit(principal: sharePrincipal, remove: true) }
                        .disabled(!signedIn || !machine.machine.write || sharePrincipal.isEmpty)
                }
                Text(shareStatus).font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField(MilaStrings.text(.webPlaceholder), text: $webURL).textContentType(.URL).autocorrectionDisabled()
                    Button(MilaStrings.text(.webOpen)) { openAuthenticatedWeb(machine.id) }
                        .disabled(webLoading || !machine.machine.read)
                }
                if webControls.error != nil { Text(MilaStrings.text(.webInvalid)).font(.caption).foregroundStyle(.secondary) }
                ForEach(machine.actions.values, id: \.self) { action in
                    Button(action.title) {
                        workflow.submit(action, machine: machine)
                    }
                    .disabled(!isIdle)
                }
                HStack {
                    ForEach(["show", "resize", "share show", "web show"], id: \.self) { command in
                        Button(command) {
                            do { classified = String(describing: try adapter.classifyMachineCommand(command)) }
                            catch { classified = MilaStrings.text(.rejectedByRust) }
                        }
                    }
                }
                Text(classified).font(.caption).foregroundStyle(.secondary)
                Text(mutationStatus).font(.caption).foregroundStyle(.secondary)
                .onAppear { sharing.setSession(signedIn: signedIn, machine: machine) }
            } else { ContentUnavailableView(MilaStrings.text(.machineUnavailable), systemImage: "questionmark") }
        }.padding().sheet(isPresented: $showTerminal) { MilaTerminalView() }
        #if canImport(WebKit)
        .sheet(isPresented: $showWeb) { if let endpoint = webControls.endpoint { MilaWebView(endpoint: endpoint) } }
        #endif
    }

    private func openAuthenticatedWeb(_ machineID: UUID) {
        webLoading = true
        Task {
            defer { webLoading = false }
            do {
                let endpoint = try await adapter.webEndpoint(machine: machineID)
                webControls.open(endpoint)
                showWeb = true
            } catch {
                webControls.clear()
                _ = webControls.set("invalid")
            }
        }
    }

    private var isIdle: Bool {
        if case .idle = workflow.state { return true }
        return false
    }

    private var shareStatus: String {
        switch sharing.state {
        case .signedOut: return MilaStrings.text(.runtimeUnavailable)
        case .idle: return MilaStrings.text(.ready)
        case .submitting: return MilaStrings.text(.connecting)
        case .applied(_, _, let remove): return remove ? MilaStrings.text(.shareRemoved) : MilaStrings.text(.shareAdded)
        case .failed: return MilaStrings.text(.actionNotSubmitted)
        }
    }

    private var mutationStatus: String {
        switch workflow.state {
        case .idle: return MilaStrings.text(.ready)
        case .submitting: return MilaStrings.text(.connecting)
        case .applied: return MilaStrings.text(.actionSubmitted)
        case .failed: return MilaStrings.text(.actionNotSubmitted)
        }
    }

    private func resize(_ machine: MilaMachinePresentation) {
        guard let cpu = UInt32(resizeCPU), let memory = UInt64(resizeMemory), let disk = UInt64(resizeDisk), cpu > 0, memory > 0, disk > 0 else { resizeStatus = MilaStrings.text(.actionNotSubmitted); return }
        resizeStatus = MilaStrings.text(.connecting)
        Task {
            do { try await adapter.resize(machine: machine, cpu: cpu, memory: memory, disk: disk, requestID: UUID()); resizeStatus = MilaStrings.text(.actionSubmitted) }
            catch { resizeStatus = MilaStrings.text(.actionNotSubmitted) }
        }
    }

}
private struct ThreadsView: View {
    let adapter: any MilaFFIAdapter
    let select: (UUID) -> Void
    @State private var status = ""
    @State private var input = ""
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(MilaStrings.text(.threads)).font(.title)
            Text(MilaStrings.text(.commandsRust)).font(.caption).foregroundStyle(.secondary)
            HStack {
                actionButton("List", action: .list)
                actionButton("Read", action: .read)
            }
            TextField(MilaStrings.text(.input), text: $input).textFieldStyle(.roundedBorder)
            Button(MilaStrings.text(.send)) { Task { await execute(.answer(input)) } }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            Text(status).font(.caption)
            ContentUnavailableView(MilaStrings.text(.noThreads), systemImage: "bubble.left", description: Text(MilaStrings.text(.threadsHint)))
        }.padding()
    }
    @ViewBuilder private func actionButton(_ title: String, action: MilaThreadAction) -> some View {
        Button(title) { Task { await execute(action) } }.disabled(busy)
    }
    private func execute(_ action: MilaThreadAction) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            _ = try adapter.classifyThreadCommand(action.command + (action.secondary.map { " " + $0 } ?? ""))
            let data = try await adapter.threadAction(thread: nil, command: action.command, secondary: action.secondary, input: action.input, requestID: UUID())
            status = String(decoding: data.prefix(4096), as: UTF8.self)
            if case .answer = action { input = "" }
        } catch { status = MilaStrings.text(.unavailable) }
    }
}
private struct ThreadDetailView: View {
    let id: UUID
    let adapter: any MilaFFIAdapter
    @State private var input = ""
    @State private var plan = ""
    @State private var status = ""
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(MilaStrings.text(.threads)) \(id.uuidString)")
            TextField(MilaStrings.text(.input), text: $input).textFieldStyle(.roundedBorder)
            HStack {
                Button(MilaStrings.text(.send)) { Task { await send(.answer(input)) } }.disabled(input.isEmpty || busy)
                Button("Approve plan") { Task { await send(.planApprove(plan)) } }.disabled(plan.isEmpty || busy)
                Button("Revise plan") { Task { await send(.planRevise(plan)) } }.disabled(plan.isEmpty || busy)
            }
            TextField("Plan identifier", text: $plan).textFieldStyle(.roundedBorder)
            Text(status).font(.caption).foregroundStyle(.secondary)
        }.padding()
    }
    private func send(_ action: MilaThreadAction) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { let data = try await adapter.threadAction(thread: id, command: action.command, secondary: action.secondary, input: action.input, requestID: UUID()); status = String(decoding: data.prefix(4096), as: UTF8.self); if case .answer = action { input = "" } }
        catch { status = MilaStrings.text(.unavailable) }
    }
}
private struct SettingsView: View {
    let adapter: any MilaFFIAdapter
    let lockController: MilaAppLockController
    @ObservedObject var session: MilaDeploymentSessionController
    @AppStorage("mila.appearance") private var appearance = "system"
    @AppStorage("mila.locale") private var locale = "en"
    @AppStorage("mila.appLockEnabled") private var appLockEnabled = false
    @State private var notificationToken = ""
    @State private var notificationEndpoint = ""
    @State private var notificationStatus = ""
    @State private var notificationsEnabled = false
    @State private var deploymentHost = ""
    @State private var deploymentPort = "22"
    @State private var deploymentTrust = ""
    @State private var deploymentStatus = ""
    var body: some View {
        Form {
            Section("Deployment sign-in") {
                Picker("Deployment", selection: Binding(get: { session.selectedDeployment?.id }, set: { id in if let id, let value = session.deployments.first(where: { $0.id == id }) { session.select(value) } })) {
                    Text("Select deployment").tag(Optional<UUID>.none)
                    ForEach(session.deployments) { deployment in Text("\(deployment.host):\(deployment.port)").tag(Optional(deployment.id)) }
                }
                HStack {
                    Button("Sign in") { if let value = session.selectedDeployment { _ = session.signIn(value) } }.disabled(session.selectedDeployment == nil)
                    Button("Reconnect") { _ = session.reconnect() }.disabled(session.selectedDeployment == nil)
                    Button("Sign out") { session.signOut() }.disabled(session.state == .signedOut)
                }
                Text(String(describing: session.state)).font(.caption).foregroundStyle(.secondary)
            }
            Section("Deployment") {
                TextField("Host", text: $deploymentHost)
                TextField("Port", text: $deploymentPort)
                TextField("Pinned trust", text: $deploymentTrust)
                Button("Save deployment") {
                    guard let port = UInt16(deploymentPort), let trust = Data(base64Encoded: deploymentTrust), session.upsert(MilaDeployment(host: deploymentHost, port: port, trust: trust)) else { deploymentStatus = "Invalid deployment"; return }
                    deploymentStatus = "Deployment saved"
                }
                ForEach(session.deployments) { deployment in
                    HStack {
                        Button { session.select(deployment) } label: {
                            VStack(alignment: .leading) { Text("\(deployment.host):\(deployment.port)"); Text(deployment.id == session.selectedDeployment?.id ? "Selected" : "") .font(.caption).foregroundStyle(.secondary) }
                        }.buttonStyle(.plain)
                        Spacer()
                        Button("Remove") { _ = session.remove(deployment.id) }
                    }
                }
                Text(deploymentStatus).font(.caption)
            }
            Section(MilaStrings.text(.appearance)) {
                Picker(MilaStrings.text(.appearance), selection: $appearance) {
                    Text(MilaStrings.text(.appearanceSystem)).tag("system")
                    Text(MilaStrings.text(.appearanceLight)).tag("light")
                    Text(MilaStrings.text(.appearanceDark)).tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section("Language") {
                Picker("Language", selection: $locale) {
                    Text("English").tag("en")
                    Text("Français").tag("fr-FR")
                    Text("Deutsch").tag("de")
                    Text("Español").tag("es")
                    Text("日本語").tag("ja")
                    Text("العربية").tag("ar")
                }
                .onChange(of: locale) { _, value in
                    if !["en", "fr-FR", "de", "es", "ja", "ar"].contains(value) { locale = "en" }
                }
            }
            Section(MilaStrings.text(.lockTitle)) {
                Toggle(MilaStrings.text(.lockTitle), isOn: Binding(get: { appLockEnabled }, set: { value in
                    appLockEnabled = value
                    Task { await lockController.setEnabled(value) }
                }))
                    .disabled(!lockController.canEnable)
                Text(lockController.canEnable ? MilaStrings.text(.lockExplain) : MilaStrings.text(.lockUnavailable)).font(.caption).foregroundStyle(.secondary)
            }
            Section(MilaStrings.text(.notificationsTitle)) {
                Text(MilaStrings.text(.notificationsExplain)).font(.caption)
                SecureField("Device token", text: $notificationToken)
                    .textContentType(.oneTimeCode)
                TextField("https://deployment.example/push", text: $notificationEndpoint)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                HStack {
                    Button(notificationsEnabled ? MilaStrings.text(.notificationsTurnOff) : MilaStrings.text(.notificationsTurnOn)) {
                        if notificationsEnabled {
                            notificationsEnabled = false
                            notificationStatus = MilaStrings.text(.notificationsTurnOff)
                        } else {
                            let controller = MilaNotificationController(adapter: adapter, appID: "com.overalls.mila", deployment: "current")
                            controller.register(token: notificationToken, endpoint: notificationEndpoint)
                            notificationsEnabled = controller.state == .on
                            notificationStatus = notificationsEnabled ? MilaStrings.text(.notificationsTurnOn) : MilaStrings.text(.runtimeUnavailable)
                            notificationToken = ""
                        }
                    }
                    Text(notificationsEnabled ? "[on]" : "[off]").font(.caption)
                }
                Text(notificationStatus).font(.caption).foregroundStyle(.secondary)
            }
            NavigationLink(MilaStrings.text(.sshKeysTitle)) {
                MilaSSHKeysView(
                    controller: MilaSSHKeysController(
                        loader: { try await adapter.listSSHKeys() },
                        revoker: { keyID in
                            let key = MilaSSHKey(id: keyID, fingerprint: "", algorithm: "")
                            try await adapter.revokeSSHKey(key, requestID: UUID())
                        }
                    ),
                    signedIn: session.state != .signedOut
                )
            }
            Text(MilaStrings.text(.runtimeUnavailable)).foregroundStyle(.secondary)
        }.navigationTitle(MilaStrings.text(.settings))
    }
}

public struct MilaSSHKeysView: View {
    @StateObject private var controller: MilaSSHKeysController
    private let signedIn: Bool
    public init(controller: MilaSSHKeysController, signedIn: Bool = false) {
        _controller = StateObject(wrappedValue: controller)
        self.signedIn = signedIn
    }
    public var body: some View {
        List {
            Text(MilaStrings.text(.sshKeysExplain)).font(.caption)
            switch controller.state {
            case .signedOut: Text(MilaStrings.text(.sshKeysEmpty))
            case .loading: ProgressView()
            case .failed: Text(MilaStrings.text(.runtimeUnavailable))
            case .loaded(let keys):
                if keys.isEmpty { Text(MilaStrings.text(.sshKeysEmpty)) }
                ForEach(keys) { key in
                    HStack {
                        VStack(alignment: .leading) { Text(key.label ?? MilaStrings.text(.sshKeysTitle)); Text(key.fingerprint).font(.caption); Text("\(MilaStrings.text(.sshKeyAlgorithm)): \(key.algorithm)").font(.caption) }
                        Spacer()
                        if key.isCurrentDevice { Text(MilaStrings.text(.sshKeyThisDevice)).font(.caption) }
                        Button(MilaStrings.text(.sshKeyRevoke)) { Task { await controller.revoke(key) } }.disabled(key.isCurrentDevice)
                    }
                }
            }
        }.navigationTitle(MilaStrings.text(.sshKeysTitle)).task { await controller.load(signedIn: signedIn) }
    }
}

@MainActor public struct MilaNativeApp: App {
    private let adapter: any MilaFFIAdapter
    @StateObject private var session: MilaDeploymentSessionController
    public init() {
        let selectedAdapter: any MilaFFIAdapter = LinkedMilaFFIAdapter()
        self.adapter = selectedAdapter
        self._session = StateObject(wrappedValue: MilaDeploymentSessionController(factory: { _ in selectedAdapter }))
    }
    public init(adapter: any MilaFFIAdapter) {
        self.adapter = adapter
        self._session = StateObject(wrappedValue: MilaDeploymentSessionController(factory: { _ in adapter }))
    }
    public var body: some Scene { WindowGroup { MilaNativeRootView(adapter: adapter) } }
}


private struct MilaTerminalView: View {
    @StateObject private var terminal = MilaTerminalController()
    @State private var command = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MilaStrings.text(.terminal)).font(.title2)
            ScrollView { Text(String(decoding: terminal.output, as: UTF8.self)).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
                .frame(maxHeight: .infinity).background(.black).foregroundStyle(.green)
            HStack { TextField(MilaStrings.text(.input), text: $command).onSubmit { send() }; Button(MilaStrings.text(.send)) { send() }; Button(MilaStrings.text(.reconnect)) { Task { await terminal.reconnect() } } }
            Text("\(String(describing: terminal.state)) · \(terminal.columns)x\(terminal.rows)").font(.caption).foregroundStyle(.secondary)
        }.padding().task { await terminal.attach() }.onDisappear { Task { await terminal.close() } }
    }
    private func send() { let data = Data(command.utf8); command = ""; Task { await terminal.sendInput(data) } }
}
