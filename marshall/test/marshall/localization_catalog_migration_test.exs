Code.require_file("../../../scripts/localization_catalog_migration.ex", __DIR__)
Code.require_file("../../../scripts/localization_catalog_migration_cli.ex", __DIR__)

defmodule Overalls.LocalizationCatalogMigrationTest do
  use ExUnit.Case, async: true

  alias Expo.Message.{Plural, Singular}
  alias Overalls.LocalizationCatalogMigration, as: Migration
  alias Overalls.LocalizationCatalogMigration.CLI

  @type fixture :: %{
          root: Path.t(),
          snapshot: Path.t(),
          app: :marshall | :porsche,
          locale: String.t()
        }

  setup do
    temporary =
      Path.join(System.tmp_dir!(), "localization-migration-#{System.unique_integer([:positive])}")

    File.mkdir_p!(temporary)
    on_exit(fn -> File.rm_rf!(temporary) end)
    %{temporary: temporary}
  end

  test "CLI defaults to dry run and rejects ambiguous or file-writing check arguments" do
    assert %{mode: :dry_run, snapshot: "/snapshot"} = CLI.parse!(["--snapshot", "/snapshot"])
    assert %{mode: :check} = CLI.parse!(["--snapshot", "/snapshot", "--check"])

    assert %{mode: :write, report: "/report"} =
             CLI.parse!(["--snapshot", "/snapshot", "--write", "--report", "/report"])

    for args <- [
          [],
          ["--snapshot", "/snapshot", "--write", "--check"],
          ["--snapshot", "/snapshot", "--report", "/report"],
          ["--snapshot", "/snapshot", "--unknown"]
        ] do
      assert_raise ArgumentError, fn -> CLI.parse!(args) end
    end
  end

  test "dry run preserves files and write/check deterministically migrate exact translations", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)
    before = tree(fixture.root)
    plan = Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    assert :ok = Migration.apply(plan, :dry_run)
    assert tree(fixture.root) == before
    assert_raise ArgumentError, ~r/differs/, fn -> Migration.apply(plan, :check) end
    assert :ok = Migration.apply(plan, :write)

    assert :ok =
             Migration.apply(Migration.plan(fixture.root, fixture.snapshot, [:porsche]), :check)

    assert Migration.report(plan) ==
             Migration.report(Migration.plan(fixture.root, fixture.snapshot, [:porsche]))

    for domain <- Migration.domains(:porsche) do
      [message] = catalog(fixture, domain).messages
      assert message.msgstr == ["translated #{domain}"]
      assert message.references == [[{"new/#{domain}.ex", 10}]]
    end

    refute File.exists?(Path.join(fixture.root, "porsche/priv/gettext/default.pot"))
    refute File.exists?(Path.join(fixture.root, "porsche/priv/gettext/fi/LC_MESSAGES/default.po"))
  end

  test "context, plural forms, comments and fuzzy status survive exact migration", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)

    message = %Plural{
      msgctxt: ["machine count"],
      msgid: ["%{count} machine"],
      msgid_plural: ["%{count} machines"],
      msgstr: %{0 => ["%{count} kone"], 1 => ["%{count} konetta"]},
      comments: [" translator note"],
      flags: [["fuzzy", "elixir-format"]]
    }

    replace_message(fixture, "management", message)
    plan = Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    assert :ok = Migration.apply(plan, :write)
    [actual] = catalog(fixture, "management").messages
    assert Migration.identity(actual) == Migration.identity(message)
    assert actual.msgstr == message.msgstr
    assert actual.comments == message.comments
    assert actual.flags == message.flags
  end

  test "remaining default-domain source calls fail before retired catalogs are removed", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)
    path = Path.join(fixture.root, "porsche/priv/gettext/default.pot")
    write_catalog(path, [%Singular{msgid: ["Still implicit"], msgstr: [""]}])
    before = tree(fixture.root)

    assert_raise ArgumentError, ~r/default-domain source calls/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end

    assert tree(fixture.root) == before
  end

  test "Egyptian Arabic restores six plural forms without replacing existing translations", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)

    message = %Plural{
      msgid: ["%{count} machine"],
      msgid_plural: ["%{count} machines"],
      msgstr: %{0 => ["existing zero"], 1 => ["existing one"]}
    }

    replace_message(fixture, "management", message)

    for base <- [
          Path.join(fixture.snapshot, "porsche/gettext"),
          Path.join(fixture.root, "porsche/priv/gettext")
        ] do
      File.rename!(Path.join(base, "fi"), Path.join(base, "arz"))
      path = Path.join(base, "arz/LC_MESSAGES/default.po")
      catalog = Expo.PO.parse_file!(path)
      headers = Enum.map(catalog.headers, &String.replace(&1, "Language: fi", "Language: arz"))
      File.write!(path, Expo.PO.compose(%{catalog | headers: headers}))
    end

    fixture = %{fixture | locale: "arz"}
    plan = Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    assert :ok = Migration.apply(plan, :write)
    catalog = catalog(fixture, "management")
    [header] = Expo.Messages.get_header(catalog, "Plural-Forms")
    assert Expo.PluralForms.parse!(header).nplurals == 6
    [actual] = catalog.messages
    assert Map.take(actual.msgstr, [0, 1]) == message.msgstr
    assert Map.take(actual.msgstr, [2, 3, 4, 5]) == Map.new(2..5, &{&1, [""]})
  end

  test "shared source identity duplicates translations and exact reviews into every feature", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)
    shared = %Singular{msgid: ["Status"], msgstr: ["Status"]}
    replace_message(fixture, "management", shared)
    replace_message(fixture, "sessions", shared)

    review = %{
      "app" => "porsche",
      "locale" => "fi",
      "domain" => "default",
      "context" => nil,
      "msgid" => "Status",
      "msgid_plural" => nil,
      "form" => 0,
      "reason" => "cognate",
      "note" => "Reviewed invariant Finnish fixture."
    }

    review_path = Path.join(fixture.snapshot, "porsche/gettext/reviewed_source_equal.json")
    File.write!(review_path, JSON.encode!([review]))
    plan = Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    assert :ok = Migration.apply(plan, :write)
    assert hd(catalog(fixture, "management").messages).msgstr == ["Status"]
    assert hd(catalog(fixture, "sessions").messages).msgstr == ["Status"]

    reviews =
      fixture.root
      |> Path.join("porsche/priv/gettext/reviewed_source_equal.json")
      |> File.read!()
      |> JSON.decode!()

    assert Enum.map(reviews, & &1["domain"]) == ["management", "sessions"]
    assert Enum.all?(reviews, &(Map.delete(&1, "domain") == Map.delete(review, "domain")))
  end

  test "unknown target identities and unexplained source loss fail before writes", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)
    target = Path.join(fixture.root, "porsche/priv/gettext/help.pot")
    write_catalog(target, [%Singular{msgid: ["Unknown"], msgstr: [""]}])

    assert_raise ArgumentError, ~r/Unknown source identity/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end

    write_catalog(target, [])

    assert_raise ArgumentError, ~r/Unmapped original/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end
  end

  test "existing domains accept exact default identities without collapsing prior identities", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :marshall)
    incoming = %Singular{msgid: ["Error page prose"], msgstr: ["translated error page"]}
    add_original(fixture, "default", incoming)
    target = Path.join(fixture.root, "marshall/priv/gettext/errors.pot")
    existing = Expo.PO.parse_file!(target).messages
    write_catalog(target, existing ++ [empty(incoming)])

    assert :ok =
             fixture.root
             |> Migration.plan(fixture.snapshot, [:marshall])
             |> Migration.apply(:write)

    assert List.last(catalog(fixture, "errors").messages).msgstr == incoming.msgstr

    add_original(fixture, "default", %Singular{
      msgid: ["message errors"],
      msgstr: ["conflicting error"]
    })

    assert_raise ArgumentError, ~r/Unmapped original marshall\/default/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:marshall])
    end
  end

  test "explicit new sources remain empty gaps and stale additions fail", %{temporary: temporary} do
    fixture = fixture(temporary, :porsche)
    path = Path.join(fixture.root, "porsche/priv/gettext/help.pot")
    existing = Expo.PO.parse_file!(path).messages
    write_catalog(path, existing ++ [%Singular{msgid: ["New source"], msgstr: [""]}])

    addition = %{
      "app" => "porsche",
      "domain" => "help",
      "context" => nil,
      "msgid" => "New source",
      "msgid_plural" => nil
    }

    plan = Migration.plan(fixture.root, fixture.snapshot, [:porsche], [addition])
    assert :ok = Migration.apply(plan, :write)
    assert List.last(catalog(fixture, "help").messages).msgstr == [""]
    assert hd(plan.report["applications"])["new_messages"] == 1

    stale = %{addition | "msgid" => "message help"}

    assert_raise ArgumentError, ~r/Stale new-source inventory/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche], [addition, stale])
    end
  end

  test "conflicting original entries are refused instead of selecting a translation", %{
    temporary: temporary
  } do
    fixture = fixture(temporary, :porsche)
    path = Path.join(fixture.snapshot, "porsche/gettext/fi/LC_MESSAGES/default.po")
    catalog = Expo.PO.parse_file!(path)
    [first | _] = catalog.messages
    write_catalog(path, catalog.messages ++ [%{first | msgstr: ["different translation"]}])

    assert_raise Expo.PO.DuplicateMessagesError, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end
  end

  test "unknown domains and stale original locale identities fail closed", %{temporary: temporary} do
    fixture = fixture(temporary, :porsche)
    path = Path.join(fixture.root, "porsche/priv/gettext/unmapped.pot")
    write_catalog(path, [])

    assert_raise ArgumentError, ~r/Unexpected porsche feature domains/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end

    File.rm!(path)
    write_catalog(Path.join(fixture.snapshot, "porsche/gettext/fi/LC_MESSAGES/default.po"), [])

    assert_raise ArgumentError, ~r/Original identities differ/, fn ->
      Migration.plan(fixture.root, fixture.snapshot, [:porsche])
    end
  end

  @spec fixture(Path.t(), :marshall | :porsche) :: fixture()
  defp fixture(temporary, app) do
    fixture = %{
      root: Path.join(temporary, "root"),
      snapshot: Path.join(temporary, "snapshot"),
      app: app,
      locale: "fi"
    }

    for domain <- Migration.domains(app) do
      target = %Singular{
        msgid: ["message #{domain}"],
        msgstr: [""],
        references: [[{"new/#{domain}.ex", 10}]]
      }

      write_catalog(Path.join([fixture.root, to_string(app), "priv/gettext", domain <> ".pot"]), [
        target
      ])

      original_domain =
        if app == :marshall and domain in ~w(browser documentation errors),
          do: domain,
          else: "default"

      add_original(fixture, original_domain, %{target | msgstr: ["translated #{domain}"]})
    end

    write_catalog(Path.join([fixture.root, to_string(app), "priv/gettext/default.pot"]), [])
    locale_path = Path.join([fixture.root, to_string(app), "priv/gettext/fi/LC_MESSAGES"])
    File.mkdir_p!(locale_path)

    File.cp!(
      Path.join([fixture.snapshot, to_string(app), "gettext/fi/LC_MESSAGES/default.po"]),
      Path.join(locale_path, "default.po")
    )

    fixture
  end

  @spec add_original(fixture(), String.t(), Expo.Message.t()) :: :ok
  defp add_original(fixture, domain, message) do
    root = Path.join([fixture.snapshot, to_string(fixture.app), "gettext"])

    for {relative, translation?} <- [
          {domain <> ".pot", false},
          {"fi/LC_MESSAGES/#{domain}.po", true}
        ] do
      path = Path.join(root, relative)
      existing = if File.exists?(path), do: Expo.PO.parse_file!(path).messages, else: []
      retained = Enum.reject(existing, &(Migration.identity(&1) == Migration.identity(message)))
      value = if translation?, do: message, else: empty(message)
      write_catalog(path, retained ++ [value])
    end

    :ok
  end

  @spec replace_message(fixture(), String.t(), Expo.Message.t()) :: :ok
  defp replace_message(fixture, domain, message) do
    path = Path.join([fixture.root, to_string(fixture.app), "priv/gettext", domain <> ".pot"])
    [replaced] = Expo.PO.parse_file!(path).messages
    write_catalog(path, [%{empty(message) | references: [[{"new/#{domain}.ex", 10}]]}])
    old = Path.join([fixture.snapshot, to_string(fixture.app), "gettext"])

    for relative <- ["default.pot", "fi/LC_MESSAGES/default.po"] do
      original = Path.join(old, relative)

      retained =
        original
        |> Expo.PO.parse_file!()
        |> Map.fetch!(:messages)
        |> Enum.reject(&(Migration.identity(&1) == Migration.identity(replaced)))

      write_catalog(original, retained)
    end

    add_original(fixture, "default", message)
  end

  @spec empty(Expo.Message.t()) :: Expo.Message.t()
  defp empty(%Singular{} = message), do: %{message | msgstr: [""]}
  defp empty(%Plural{} = message), do: %{message | msgstr: %{0 => [""], 1 => [""]}}

  @spec write_catalog(Path.t(), [Expo.Message.t()]) :: :ok
  defp write_catalog(path, messages) do
    File.mkdir_p!(Path.dirname(path))

    catalog = %Expo.Messages{
      headers: [
        "Language: fi\n",
        "Content-Type: text/plain; charset=UTF-8\n",
        "Plural-Forms: nplurals=2; plural=(n != 1);\n"
      ],
      messages: messages
    }

    File.write!(path, Expo.PO.compose(catalog))
  end

  @spec catalog(fixture(), String.t()) :: Expo.Messages.t()
  defp catalog(fixture, domain),
    do:
      Path.join([
        fixture.root,
        to_string(fixture.app),
        "priv/gettext/#{fixture.locale}/LC_MESSAGES",
        domain <> ".po"
      ])
      |> Expo.PO.parse_file!()

  @spec tree(Path.t()) :: %{Path.t() => binary()}
  defp tree(root),
    do:
      root
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Map.new(&{&1, File.read!(&1)})
end
