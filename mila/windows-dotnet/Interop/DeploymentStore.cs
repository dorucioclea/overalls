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
        => LoadAll().FirstOrDefault();
    internal static IReadOnlyList<MilaDeployment> LoadAll()
    {
        try
        {
            string json = File.ReadAllText(PathName);
            try
            {
                if (JsonSerializer.Deserialize<List<MilaDeployment>>(json) is { } many)
                    return many.Select(static deployment => deployment.Normalize()).Distinct().ToArray();
            }
            catch (JsonException) { }
            if (JsonSerializer.Deserialize<MilaDeployment>(json) is { } one)
                return new[] { one.Normalize() };
        }
        catch (IOException) { }
        catch (JsonException) { }
        return Array.Empty<MilaDeployment>();
    }
    internal static void Save(MilaDeployment deployment)
    {
        ArgumentNullException.ThrowIfNull(deployment);
        deployment = deployment.Normalize();
        string? directory = Path.GetDirectoryName(PathName);
        if (directory is null) return;
        Directory.CreateDirectory(directory);
        List<MilaDeployment> deployments = LoadAll().Where(existing => existing != deployment).Append(deployment).ToList();
        File.WriteAllText(PathName, JsonSerializer.Serialize(deployments));
    }

    internal static bool Forget(MilaDeployment deployment)
    {
        ArgumentNullException.ThrowIfNull(deployment);
        IReadOnlyList<MilaDeployment> current = LoadAll();
        List<MilaDeployment> remaining = current.Where(existing => existing != deployment).ToList();
        if (remaining.Count == current.Count) return false;
        string? directory = Path.GetDirectoryName(PathName);
        if (directory is null) return false;
        Directory.CreateDirectory(directory);
        File.WriteAllText(PathName, JsonSerializer.Serialize(remaining));
        return true;
    }
}
