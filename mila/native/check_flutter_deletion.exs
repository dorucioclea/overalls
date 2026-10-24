# Typed migration gate for retiring Mila's Flutter client.
defmodule MilaFlutterDeletionGate do
  @moduledoc "Checks that native parity and release wiring are ready before Flutter removal."
  @type check :: %{name: String.t(), ok: boolean(), detail: String.t()}

  @spec run(Path.t()) :: [check()]
  def run(root) do
    matrix = Path.join(root, "mila/native/PARITY_MATRIX.md")
    checks = [
      parity_check(matrix),
      path_absence_check(root, "mila/app"),
      path_absence_check(root, "mila/packages"),
      path_absence_check(root, "mila/tool"),
      release_check(root),
      windows_source_bundle_check(root),
      compatibility_milestone_check(root)
    ]
    checks ++ flutter_reference_check(root)
  end

  @spec parity_check(Path.t()) :: check()
  defp parity_check(path) do
    text = File.read!(path)
    partial = Regex.scan(~r/^\|.*(?:open|partial).*$/im, text) |> length()
    %{name: "parity matrix", ok: partial == 0, detail: "#{partial} open/partial rows"}
  end

  @spec path_absence_check(Path.t(), Path.t()) :: check()
  defp path_absence_check(root, relative) do
    present = File.exists?(Path.join(root, relative))
    %{name: "removed #{relative}", ok: not present, detail: if(present, do: "present", else: "absent")}
  end

  @spec release_check(Path.t()) :: check()
  defp release_check(root) do
    path = Path.join(root, "nix/domains/artifacts/mila/default.nix")
    text = File.read!(path)
    linux = String.contains?(text, "nativeLinux") and String.contains?(text, "tar --sort=name")
    ok = linux
    detail = cond do
      not linux -> "native Linux release still wired to Flutter"
      true -> "native Linux release wired; Windows bundle reported separately"
    end
    %{name: "native release/source bundle", ok: ok, detail: detail}
  end

  @spec windows_source_bundle_check(Path.t()) :: check()
  defp windows_source_bundle_check(root) do
    path = Path.join(root, "nix/domains/artifacts/mila/windows-source-bundle.nix")
    text = File.read!(path)
    required = ["windows-dotnet", "rust", "app/lib/l10n"]
    missing = Enum.reject(required, &String.contains?(text, &1))
    forbidden = Regex.scan(~r/Flutter|Dart|pub-cache|mila\/app\/pubspec/i, text) |> length()
    ok = missing == [] and forbidden == 0
    detail = cond do
      missing != [] -> "missing native Windows inputs: #{Enum.join(missing, ", ")}"
      forbidden != 0 -> "contains #{forbidden} Flutter/Dart compatibility input reference(s)"
      true -> "native Windows host, Rust lock and locale inputs are source-only"
    end
    %{name: "native Windows source bundle", ok: ok, detail: detail}
  end

  @spec compatibility_milestone_check(Path.t()) :: check()
  defp compatibility_milestone_check(root) do
    retained = ["mila/app", "mila/packages", "mila/tool"]
      |> Enum.filter(&File.exists?(Path.join(root, &1)))
    detail = if retained == [], do: "Flutter compatibility tree removed; deletion milestone reached", else: "retained compatibility trees: #{Enum.join(retained, ", ")}"
    %{name: "Flutter compatibility removal milestone", ok: retained == [], detail: detail}
  end

  @spec flutter_reference_check(Path.t()) :: [check()]
  defp flutter_reference_check(root) do
    {output, status} = System.cmd("rg", ["-l", "(flutter|dart|buildFlutterApplication)", root, "--glob", "!.git/**", "--glob", "!mila/native/check_flutter_deletion.exs"], stderr_to_stdout: true)
    files = output |> String.split("\n", trim: true)
    [%{name: "Flutter references", ok: status == 1 and files == [], detail: if(files == [], do: "none", else: Enum.join(files, ", "))}]
  end
end

root = Path.expand("../..", __DIR__)
checks = MilaFlutterDeletionGate.run(root)
Enum.each(checks, fn check -> IO.puts("#{if check.ok, do: "PASS", else: "FAIL"} #{check.name}: #{check.detail}") end)
if Enum.any?(checks, &(not &1.ok)), do: System.halt(1)
