using System.Text.Json;
using System.Text.RegularExpressions;

namespace Mila.Windows.Interop;

internal sealed record MilaSettings(string Locale, bool DarkMode)
{
    internal static MilaSettings Defaults => new("en", false);

    internal static bool IsValidLocale(string locale)
    {
        string normalized = locale.Trim().Replace('_', '-');
        return normalized.Length is >= 2 and <= 35 && Regex.IsMatch(normalized, "^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$", RegexOptions.CultureInvariant);
    }

    internal MilaSettings Normalize()
    {
        string[] parts = Locale.Trim().Replace('_', '-').Split('-', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return this with { Locale = string.Empty };
        parts[0] = parts[0].ToLowerInvariant();
        for (int index = 1; index < parts.Length; index++)
        {
            parts[index] = parts[index].Length == 4
                ? char.ToUpperInvariant(parts[index][0]) + parts[index][1..].ToLowerInvariant()
                : parts[index].Length is 2 or 3
                    ? parts[index].ToUpperInvariant()
                    : parts[index];
        }
        return this with { Locale = string.Join('-', parts) };
    }

    internal LocaleDirection Direction()
    {
        string language = Normalize().Locale.Split('-')[0];
        return language is "ar" or "fa" or "he" or "ur" ? LocaleDirection.Rtl : LocaleDirection.Ltr;
    }
}

internal enum LocaleDirection { Ltr, Rtl }

internal static class MilaSettingsStore
{
    private static string FilePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Mila", "settings.json");
    internal static MilaSettings Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return MilaSettings.Defaults;
            MilaSettings? value = JsonSerializer.Deserialize<MilaSettings>(File.ReadAllText(FilePath));
            return value is not null && MilaSettings.IsValidLocale(value.Locale) ? value.Normalize() : MilaSettings.Defaults;
        }
        catch (IOException) { return MilaSettings.Defaults; }
        catch (JsonException) { return MilaSettings.Defaults; }
    }
    internal static void Save(MilaSettings settings)
    {
        MilaSettings normalized = settings.Normalize();
        if (!MilaSettings.IsValidLocale(normalized.Locale)) throw new ArgumentException("Invalid locale", nameof(settings));
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(normalized));
    }
}
