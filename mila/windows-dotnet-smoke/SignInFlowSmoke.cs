using Mila.Windows.Interop;

/// Windows approval and reconnect lifecycle stays generation-scoped.
/// @cc [owner:ghuntley,label:verification] mila-windows-signin-flow-smoke
/// The smoke path exercises stale-generation refusal, HTTPS approval validation,
/// expiry, authentication, disconnect, reconnect, and sign-out cleanup.
internal static class SignInFlowSmoke
{
    internal static void Run()
    {
        MilaSignInFlow flow = new();
        long generation = flow.Start();
        Program.Require(flow.State is { Phase: MilaSignInPhase.Connecting, Generation: 1 }, "sign-in start generation");
        Program.Require(!flow.SetApproval(generation, "http://example.test/approve", "SHA256:test", 1),
            "non-HTTPS approval refusal");
        Program.Require(flow.AwaitApproval(generation), "approval phase");
        Program.Require(flow.SetApproval(generation, "https://example.test/approve", "SHA256:test", 1),
            "approval metadata validation");
        Program.Require(!flow.Authenticated(generation - 1, "operator@example.test"), "stale approval outcome refusal");
        Program.Require(flow.Expire(generation, 601) && flow.State.Phase == MilaSignInPhase.Expired,
            "approval expiry");

        generation = flow.Start();
        Program.Require(flow.Authenticated(generation, "operator@example.test"), "authenticated transition");
        Program.Require(flow.Disconnected(generation) && flow.State.Phase == MilaSignInPhase.Disconnected,
            "disconnect transition");
        long reconnectGeneration = flow.Start();
        Program.Require(reconnectGeneration == generation + 1 && flow.State.Phase == MilaSignInPhase.Connecting,
            "reconnect starts fresh generation");
        Program.Require(!flow.Authenticated(generation, "stale@example.test"),
            "stale reconnect authentication refusal");
        Program.Require(!flow.Disconnected(generation), "stale disconnect refusal");
        Program.Require(flow.AwaitApproval(reconnectGeneration), "reconnect approval phase");
        Program.Require(flow.SetApproval(reconnectGeneration, "https://example.test/reconnect", "SHA256:reconnect", 100),
            "reconnect approval metadata");
        flow.SignOut();
        Program.Require(flow.State is { Phase: MilaSignInPhase.SignedOut, Approval: null }, "sign-out clears approval");
    }
}
