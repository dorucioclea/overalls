namespace Mila.Windows.Interop;

internal static class MilaWebOrigin
{
    internal static bool IsAllowed(Uri origin, Uri target)
    {
        return origin.IsAbsoluteUri && target.IsAbsoluteUri &&
            origin.Scheme == Uri.UriSchemeHttps && target.Scheme == Uri.UriSchemeHttps &&
            string.Equals(origin.Host, target.Host, StringComparison.OrdinalIgnoreCase) &&
            origin.Port == target.Port && string.IsNullOrEmpty(target.UserInfo) &&
            string.IsNullOrEmpty(origin.UserInfo) && string.IsNullOrEmpty(target.Fragment);
    }
}
