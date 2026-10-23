using System.Text.Json;

namespace Mila.Windows.Interop;

/// <summary>Persisted endpoint for one Porsche management gateway.</summary>
internal sealed record MilaDeployment(string Host, ushort Port = 22)
{
    /// <summary>Porsche's public management SSH listener.</summary>
    internal const ushort DefaultPort = 22;

    /// <summary>
    /// Backward-compatible normalization for deployment.json files written by
    /// the host-only schema. A missing numeric property can deserialize as zero;
    /// zero is never a valid session port, so it maps to Porsche's default.
    /// </summary>
    internal MilaDeployment Normalize()
        => Port == 0 ? this with { Port = DefaultPort } : this;
}

internal static class MilaDeploymentStore
{
    private static string PathName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Mila", "deployment.json");
    internal static MilaDeployment? Load()
    {
        try { return JsonSerializer.Deserialize<MilaDeployment>(File.ReadAllText(PathName))?.Normalize(); }
        catch (IOException) { return null; }
        catch (JsonException) { return null; }
    }
    internal static void Save(MilaDeployment deployment)
    {
        ArgumentNullException.ThrowIfNull(deployment);
        deployment = deployment.Normalize();
        string? directory = Path.GetDirectoryName(PathName);
        if (directory is null) return;
        Directory.CreateDirectory(directory);
        File.WriteAllText(PathName, JsonSerializer.Serialize(deployment));
    }
}
