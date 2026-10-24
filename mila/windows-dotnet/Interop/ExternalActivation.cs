namespace Mila.Windows.Interop;

/// <summary>Typed external activation accepted by the Windows host.</summary>
internal readonly record struct MilaExternalActivation(MilaRoute Route, bool IsShareTarget);

internal static class MilaShareTarget
{
    /// <summary>Authorizes a share activation before it reaches native controls.</summary>
    /// <remarks>Sharing a route is navigation only; it must never implicitly mutate data.</remarks>
    internal static bool TryAuthorize(
        MilaExternalActivation activation,
        bool authenticated,
        string? activeHost,
        out MilaRoute route)
    {
        route = default;
        if (!activation.IsShareTarget || !authenticated ||
            !string.Equals(activeHost, activation.Route.Host, StringComparison.OrdinalIgnoreCase) ||
            activation.Route.Kind is not (MilaRouteKind.Machine or MilaRouteKind.Thread or MilaRouteKind.Threads))
            return false;
        route = activation.Route;
        return true;
    }
}

internal sealed class MilaExternalActivationGate
{
    private long _generation;
    internal long Generation => _generation;
    internal long Reset() => ++_generation;
    internal bool TryAuthorize(MilaExternalActivation activation, long activationGeneration, bool authenticated, string? activeHost, out MilaRoute route)
    {
        if (activationGeneration != _generation) { route = default; return false; }
        return MilaShareTarget.TryAuthorize(activation, authenticated, activeHost, out route);
    }
}

internal static class MilaExternalActivationParser
{
    private const int MaxActivationText = 4096;

    /// <summary>
    /// Parses protocol activation or a share payload. Share payloads are treated
    /// as navigation only after the Rust-aligned canonical route parser accepts
    /// them; arbitrary text and command-like query strings are rejected.
    /// </summary>
    internal static MilaExternalActivation? Parse(string? value, bool shareTarget = false)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        string candidate = value.Trim().Trim('"');
        if (candidate.Length > MaxActivationText || candidate.Any(char.IsControl)) return null;
        MilaRoute? route = MilaRouteParser.Parse(candidate);
        return route is null ? null : new MilaExternalActivation(route.Value, shareTarget);
    }

    /// <summary>Parses the bounded command line supplied by WinUI activation.</summary>
    /// <remarks>
    /// Protocol activation is a single URI. Share/open activation uses the
    /// explicit <c>--share</c> marker so arbitrary command-line text cannot be
    /// interpreted as a route. The payload is still accepted only by the same
    /// canonical route grammar.
    /// </remarks>
    internal static MilaExternalActivation? ParseArguments(string? arguments)
    {
        if (string.IsNullOrWhiteSpace(arguments) || arguments.Length > MaxActivationText || arguments.Any(char.IsControl)) return null;
        string value = arguments.Trim();
        const string marker = "--share";
        if (value.StartsWith(marker, StringComparison.Ordinal))
        {
            if (value.Length == marker.Length || !char.IsWhiteSpace(value[marker.Length])) return null;
            return Parse(value[marker.Length..], shareTarget: true);
        }
        return Parse(value);
    }
}
