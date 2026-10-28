[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PublishDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PublishDirectory).Path
$required = @('Mila.Windows.exe', 'mila_native.dll')
foreach ($name in $required) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "native Windows release is missing $name"
    }
}
$forbidden = @(
    ('fl' + 'utter_windows.dll'), ('fl' + 'utter_tester.exe'), ('da' + 'rt.exe'), ('fl' + 'utter_assets'),
    ('.' + 'da' + 'rt_tool'), 'Generated.xcconfig', 'kernel_blob.bin', 'isolate_snapshot_data'
)
foreach ($name in $forbidden) {
    $match = Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $match) {
        throw "retired runtime artifact is present in native release: $($match.FullName)"
    }
}
Write-Output 'native-windows-dotnet-release=ok'
