namespace Mila.Windows;

using System.Text.Json;

/// Stable message identities shared by all native clients. Platform resource bundles may
/// override these values; English is the deterministic fallback for an incomplete bundle.
internal static class MilaStrings
{
    private static Dictionary<string, string> Catalog = LoadCatalog(System.Globalization.CultureInfo.CurrentUICulture.Name);
    internal static string AppName => "Mila";
    internal static string Machines => "Machines";
    internal static string Threads => "Threads";
    internal static string Settings => "Settings";
    internal static string Ready => "Ready";
    internal static string Connected => "Connected";
    internal static string RuntimeUnavailable => "Native runtime unavailable";

    internal static string Text(string id, string fallback) => Catalog.GetValueOrDefault(id, fallback);

    internal static void SetLocale(string locale)
    {
        Catalog = LoadCatalog(locale);
    }

    private static Dictionary<string, string> LoadCatalog(string requestedLocale)
    {
        string locale = requestedLocale.Replace('_', '-');
        foreach (string candidate in new[] { locale, locale.Split('-')[0], "en" })
        {
            string path = Path.Combine(AppContext.BaseDirectory, "Resources", "locales", $"{candidate}.json");
            if (!File.Exists(path)) continue;
            try
            {
                using JsonDocument document = JsonDocument.Parse(File.ReadAllText(path));
                JsonElement messages = document.RootElement.GetProperty("domains").GetProperty("mila").GetProperty("messages");
                return messages.EnumerateArray().Where(x => x.GetProperty("forms").GetArrayLength() > 0)
                    .ToDictionary(x => x.GetProperty("id").GetString()!, x => x.GetProperty("forms")[0].GetString()!);
            }
            catch (JsonException) { }
        }
        return new Dictionary<string, string>();
    }
}
