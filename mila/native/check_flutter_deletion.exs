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
      android_release_check(root),
      apple_release_check(root),
      source_bundle_check(root),
      windows_source_bundle_check(root),
      compatibility_milestone_check(root)
    ]
    checks ++ flutter_reference_check(root)
  end

  @spec android_release_check(Path.t()) :: check()
  defp android_release_check(root) do
    workflow = Path.join(root, ".github/workflows/mila-release.yml")
    build = Path.join(root, "mila/native/android/app/build.gradle.kts")

    with {:ok, workflow_text} <- File.read(workflow),
         {:ok, build_text} <- File.read(build) do
      required_workflow = [
        "assembleRelease",
        "app-release-unsigned.apk",
        "SHA256SUMS",
        "if-no-files-found: error"
      ]
      missing = Enum.reject(required_workflow, &String.contains?(workflow_text, &1))
      # The Gradle task invokes the cargo-ndk subcommand as two argv entries;
      # inspect both tokens rather than requiring a non-existent literal.
      native_markers = ["com.android.application", "cargo", "ndk", "mila-ffi"]
      missing_build = Enum.reject(native_markers, &String.contains?(build_text, &1))
      forbidden = Regex.scan(~r/flutter|dart|pubspec/i, build_text) |> length()
      ok = missing == [] and missing_build == [] and forbidden == 0
      detail = cond do
        missing != [] -> "release workflow missing: #{Enum.join(missing, ", ")}"
        missing_build != [] -> "Android build is missing native markers: #{Enum.join(missing_build, ", ")}"
        forbidden != 0 -> "Android build contains #{forbidden} Flutter/Dart reference(s)"
        true -> "native APK, digest manifest and fail-closed artifact upload are wired"
      end
      %{name: "native Android release artifact", ok: ok, detail: detail}
    else
      {:error, reason} -> %{name: "native Android release artifact", ok: false, detail: "cannot read release inputs: #{inspect(reason)}"}
    end
  end

  @spec source_bundle_check(Path.t()) :: check()
  defp source_bundle_check(root) do
    path = Path.join(root, "nix/domains/artifacts/mila/source-bundle.nix")
    case File.read(path) do
      {:ok, text} ->
        required = ["mila/native/android", "mila/rust/Cargo.lock", "SHA256SUMS"]
        missing = Enum.reject(required, &String.contains?(text, &1))
        %{name: "native Android source bundle", ok: missing == [], detail: if(missing == [], do: "bundle checksums and native Android source inputs are declared", else: "missing source-bundle inputs: #{Enum.join(missing, ", ")}")}
      {:error, reason} -> %{name: "native Android source bundle", ok: false, detail: "cannot read source bundle definition: #{inspect(reason)}"}
    end
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
    release_block = case Regex.run(~r/linuxRelease\s*=\s*(.*?)(?=\n\s*# The demo)/ms, text) do
      [_, block] -> block
      _ -> ""
    end
    linux = String.contains?(release_block, "nativeLinux") and
      String.contains?(release_block, "tar --sort=name") and
      not Regex.match?(~r/flutter|buildFlutterApplication/i, release_block)
    ok = linux
    detail = cond do
      not linux -> "native Linux release still wired to Flutter"
      true -> "native Linux release wired; Windows bundle reported separately"
    end
    %{name: "native release/source bundle", ok: ok, detail: detail}
  end

  @spec apple_release_check(Path.t()) :: check()
  defp apple_release_check(root) do
    path = Path.join(root, ".github/workflows/mila-release.yml")
    text = File.read!(path)
    required = [
      "  apple:",
      "working-directory: mila/native/apple",
      "swift build -c release",
      "swift test -c release",
      "if rg -n -i 'flutter' Package.swift Sources Tests",
      "SHA256SUMS"
    ]
    missing = Enum.reject(required, &String.contains?(text, &1))
    ok = missing == []
    detail = if ok, do: "Apple release runs standalone Swift release checks and publishes a digest", else: "missing Apple release checks: #{Enum.join(missing, ", ")}"
    %{name: "native Apple release", ok: ok, detail: detail}
  end

  @spec windows_source_bundle_check(Path.t()) :: check()
  defp windows_source_bundle_check(root) do
    path = Path.join(root, "nix/domains/artifacts/mila/windows-source-bundle.nix")
    text = File.read!(path)
    required = ["windows-dotnet", "rust", "localization/catalogs"]
    missing = Enum.reject(required, &String.contains?(text, &1))
    # The bundle's self-check may mention legacy filename extensions; only
    # reject actual compatibility source paths or build integrations here.
    forbidden = Regex.scan(~r/pub-cache|mila\/app\/pubspec|buildFlutterApplication/i, text) |> length()
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
