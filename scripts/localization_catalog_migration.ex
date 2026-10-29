defmodule Overalls.LocalizationCatalogMigration do
  @moduledoc "Exact, deterministic migration from application catalogs to native feature domains."

  alias Expo.Message.{Plural, Singular}

  @type app :: :marshall | :porsche
  @type identity :: {String.t() | nil, String.t(), String.t() | nil}
  @type json :: nil | boolean() | integer() | String.t() | [json()] | %{String.t() => json()}
  @type mapping :: %{app: app(), from: String.t() | nil, to: String.t(), identity: identity()}
  @type additions :: MapSet.t({app(), String.t(), identity()})
  @type plan :: %{
          files: %{Path.t() => binary()},
          removals: [Path.t()],
          report: json()
        }
  @type app_plan :: %{
          files: %{Path.t() => binary()},
          removals: [Path.t()],
          additions: [{app(), String.t(), identity()}],
          report: json()
        }

  @apps [:marshall, :porsche]
  @preserved ~w(browser documentation errors)
  @marshall_domains ~w(shared auth account teams machines terminal agents integrations git inference editor ssh downloads admin_access admin_audit admin_git admin_jobs admin_nodes admin_operations admin_users admin_workloads browser documentation errors)
  @porsche_domains ~w(onboarding help management sessions)
  @review_fields ~w(app locale domain context msgid msgid_plural form reason note)
  @arabic_plural "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 && n%100<=99 ? 4 : 5);"

  @spec domains(app()) :: [String.t()]
  def domains(:marshall), do: @marshall_domains
  def domains(:porsche), do: @porsche_domains

  # @cc [owner:ghuntley,label:verification] localization-migration-exact-preservation
  # Every target message MUST reuse exactly one original domain/context/source/
  # plural identity. Translations and review records MUST be preserved in every
  # destination. Explicit new-source records MAY initialize empty translations, but
  # MUST remain separately reported. Unknown or conflicting identities MUST fail.
  @spec plan(Path.t(), Path.t(), [app()], term()) :: plan()
  def plan(root, snapshot, apps \\ @apps, new_sources \\ []) do
    unless apps != [] and Enum.all?(apps, &(&1 in @apps)) and Enum.uniq(apps) == apps,
      do: raise(ArgumentError, "Invalid application selection")

    additions = parse_additions!(new_sources)

    results = Enum.map(apps, &app_plan(root, snapshot, &1, additions))
    used_additions = results |> Enum.flat_map(& &1.additions) |> MapSet.new()
    unless additions == used_additions, do: raise(ArgumentError, "Stale new-source inventory")
    files = Enum.reduce(results, %{}, &Map.merge(&2, &1.files))
    removals = results |> Enum.flat_map(& &1.removals) |> Enum.sort()

    %{
      files: files,
      removals: removals,
      report: %{
        "version" => 1,
        "applications" => Enum.map(results, & &1.report),
        "written_files" => map_size(files),
        "retired_files" => length(removals)
      }
    }
  end

  @spec identity(Expo.Message.t()) :: identity()
  def identity(%Singular{} = message),
    do: {text(message.msgctxt), text(message.msgid), nil}

  def identity(%Plural{} = message),
    do: {text(message.msgctxt), text(message.msgid), text(message.msgid_plural)}

  # @cc [owner:ghuntley,label:verification] localization-migration-nonmutating-check
  # Dry runs and checks MUST NOT modify catalogs. A check MUST fail when any
  # expected byte differs or any retired catalog still exists. Writes MUST use
  # the already validated complete plan, never a partially validated migration.
  @spec apply(plan(), :dry_run | :check | :write) :: :ok
  def apply(_plan, :dry_run), do: :ok

  def apply(plan, :check) do
    stale =
      Enum.flat_map(plan.files, fn {path, expected} ->
        if File.read(path) == {:ok, expected}, do: [], else: [path]
      end) ++ Enum.filter(plan.removals, &File.exists?/1)

    if stale != [],
      do:
        raise(
          ArgumentError,
          "Localization migration differs: #{Enum.join(Enum.sort(stale), ", ")}"
        )

    :ok
  end

  def apply(plan, :write) do
    for {path, contents} <- Enum.sort(plan.files) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
    end

    for path <- plan.removals, File.exists?(path), do: File.rm!(path)
    :ok
  end

  @spec report(plan()) :: binary()
  def report(plan), do: IO.iodata_to_binary([encode_json(plan.report), "\n"])

  @spec app_plan(Path.t(), Path.t(), app(), additions()) :: app_plan()
  defp app_plan(root, snapshot, app, additions) do
    app_name = Atom.to_string(app)
    destination = Path.join([root, app_name, "priv/gettext"])
    original = Path.join([snapshot, app_name, "gettext"])
    templates = read_templates(destination, app)
    old_templates = read_catalogs(original, "*.pot")
    mappings = mappings(app, templates, old_templates, additions)
    mapping_index = Map.new(mappings, &{{&1.to, &1.identity}, &1.from})
    :ok = validate_mapped!(app, old_templates, mappings)

    locales =
      original
      |> Path.join("*/LC_MESSAGES")
      |> Path.wildcard()
      |> Enum.map(&Path.basename(Path.dirname(&1)))
      |> Enum.sort()

    if locales == [], do: raise(ArgumentError, "No original locales for #{app}")

    catalog_files =
      Enum.reduce(locales, %{}, fn locale, files ->
        catalogs = read_catalogs(Path.join([original, locale, "LC_MESSAGES"]), "*.po")
        validate_original!(catalogs, old_templates, locale)
        indexes = Map.new(catalogs, fn {domain, catalog} -> {domain, message_index(catalog)} end)

        Enum.reduce(templates, files, fn {domain, template}, acc ->
          header_domain =
            if app == :marshall and domain in @preserved, do: domain, else: "default"

          catalog = catalogs |> Map.fetch!(header_domain) |> normalize_headers(locale)
          [plural_header] = Expo.Messages.get_header(catalog, "Plural-Forms")
          nplurals = Expo.PluralForms.parse!(plural_header).nplurals

          messages =
            Enum.map(template.messages, fn target ->
              id = identity(target)
              source_domain = Map.fetch!(mapping_index, {domain, id})

              source =
                if is_nil(source_domain),
                  do: target,
                  else: indexes |> Map.fetch!(source_domain) |> Map.fetch!(id)

              source = normalize_forms(source, nplurals)

              %{
                source
                | references: target.references,
                  extracted_comments: target.extracted_comments
              }
            end)

          output = %{catalog | messages: messages}
          path = Path.join([destination, locale, "LC_MESSAGES", domain <> ".po"])
          Map.put(acc, path, IO.iodata_to_binary(Expo.PO.compose(output)))
        end)
      end)

    files = migrate_reviews(original, destination, app, mappings, catalog_files)
    expected = MapSet.new(Map.keys(files))

    retired_domains = Map.keys(old_templates) -- Enum.map(templates, &elem(&1, 0))

    removals =
      Enum.flat_map(retired_domains, fn domain ->
        [Path.join(destination, domain <> ".pot")] ++
          Enum.map(locales, &Path.join([destination, &1, "LC_MESSAGES", domain <> ".po"]))
      end)

    retired = MapSet.new(removals)

    for path <- Path.wildcard(Path.join(destination, "*/LC_MESSAGES/*.po")),
        not MapSet.member?(expected, path),
        not MapSet.member?(retired, path),
        do: raise(ArgumentError, "Unexpected destination catalog: #{path}")

    %{
      files: files,
      removals: removals,
      additions:
        for(mapping <- mappings, is_nil(mapping.from), do: {app, mapping.to, mapping.identity}),
      report: %{
        "application" => app_name,
        "locales" => locales,
        "domains" =>
          Enum.map(templates, fn {domain, template} ->
            %{"name" => domain, "messages" => length(template.messages)}
          end),
        "mappings" => Enum.map(mappings, &mapping_json/1),
        "new_messages" => Enum.count(mappings, &is_nil(&1.from))
      }
    }
  end

  @spec read_templates(Path.t(), app()) :: [{String.t(), Expo.Messages.t()}]
  defp read_templates(path, app) do
    catalogs = read_catalogs(path, "*.pot")

    case Map.get(catalogs, "default") do
      nil -> :ok
      %Expo.Messages{messages: []} -> :ok
      _ -> raise(ArgumentError, "Native extraction still contains default-domain source calls")
    end

    templates = Map.delete(catalogs, "default")
    actual = templates |> Map.keys() |> Enum.sort()

    if actual != Enum.sort(domains(app)),
      do: raise(ArgumentError, "Unexpected #{app} feature domains: #{inspect(actual)}")

    Enum.sort(templates)
  end

  @spec read_catalogs(Path.t(), String.t()) :: %{String.t() => Expo.Messages.t()}
  defp read_catalogs(path, wildcard) do
    path
    |> Path.join(wildcard)
    |> Path.wildcard()
    |> Map.new(fn file ->
      catalog = Expo.PO.parse_file!(file)
      _ = message_index(catalog)
      {Path.basename(file, Path.extname(file)), catalog}
    end)
  end

  @spec message_index(Expo.Messages.t()) :: %{identity() => Expo.Message.t()}
  defp message_index(catalog) do
    if Enum.any?(catalog.messages, & &1.obsolete),
      do: raise(ArgumentError, "Obsolete messages in #{catalog.file}")

    index = Map.new(catalog.messages, &{identity(&1), &1})

    if map_size(index) != length(catalog.messages),
      do: raise(ArgumentError, "Duplicate identities")

    index
  end

  @spec mappings(
          app(),
          [{String.t(), Expo.Messages.t()}],
          %{String.t() => Expo.Messages.t()},
          additions()
        ) ::
          [mapping()]
  defp mappings(app, templates, originals, additions) do
    indexes = Map.new(originals, fn {domain, catalog} -> {domain, message_index(catalog)} end)

    Enum.flat_map(templates, fn {domain, catalog} ->
      Enum.map(catalog.messages, fn message ->
        id = identity(message)
        from = source_domain(app, domain, id, indexes, additions)

        %{app: app, from: from, to: domain, identity: id}
      end)
    end)
  end

  @spec source_domain(
          app(),
          String.t(),
          identity(),
          %{
            String.t() => %{identity() => Expo.Message.t()}
          },
          additions()
        ) :: String.t() | nil
  defp source_domain(app, domain, id, indexes, additions) do
    candidates =
      if app == :marshall and domain in @preserved, do: [domain, "default"], else: ["default"]

    original =
      Enum.find(candidates, fn candidate -> Map.has_key?(Map.get(indexes, candidate, %{}), id) end)

    cond do
      original != nil -> original
      MapSet.member?(additions, {app, domain, id}) -> nil
      true -> raise(ArgumentError, "Unknown source identity for #{app}/#{domain}: #{inspect(id)}")
    end
  end

  @spec normalize_headers(Expo.Messages.t(), String.t()) :: Expo.Messages.t()
  defp normalize_headers(catalog, "arz") do
    headers = Enum.reject(catalog.headers, &String.starts_with?(&1, "Plural-Forms:"))
    %{catalog | headers: headers ++ ["Plural-Forms: #{@arabic_plural}\n"]}
  end

  defp normalize_headers(catalog, _locale), do: catalog

  @spec normalize_forms(Expo.Message.t(), pos_integer()) :: Expo.Message.t()
  defp normalize_forms(%Singular{} = message, _nplurals), do: message

  defp normalize_forms(%Plural{} = message, nplurals) do
    unless Enum.all?(Map.keys(message.msgstr), &(&1 in 0..(nplurals - 1))),
      do: raise(ArgumentError, "Plural forms exceed locale header")

    %{message | msgstr: Map.new(0..(nplurals - 1), &{&1, Map.get(message.msgstr, &1, [""])})}
  end

  @spec parse_additions!(term()) :: additions()
  defp parse_additions!(records) when is_list(records) do
    additions =
      Enum.map(records, fn record ->
        unless is_map(record) and
                 Enum.sort(Map.keys(record)) == ~w(app context domain msgid msgid_plural) and
                 record["app"] in ~w(marshall porsche) and is_binary(record["domain"]) and
                 is_binary(record["msgid"]) and record["msgid"] != "" and
                 Enum.all?(
                   ~w(context msgid_plural),
                   &(is_nil(record[&1]) or is_binary(record[&1]))
                 ),
               do: raise(ArgumentError, "Invalid new-source record")

        app = if record["app"] == "marshall", do: :marshall, else: :porsche
        {app, record["domain"], {record["context"], record["msgid"], record["msgid_plural"]}}
      end)

    if length(Enum.uniq(additions)) != length(additions),
      do: raise(ArgumentError, "Duplicate new-source record")

    MapSet.new(additions)
  end

  defp parse_additions!(_records), do: raise(ArgumentError, "New-source inventory must be a list")

  @spec validate_mapped!(app(), %{String.t() => Expo.Messages.t()}, [mapping()]) :: :ok
  defp validate_mapped!(app, originals, mappings) do
    used = MapSet.new(mappings, &{&1.from, &1.identity})

    for {domain, catalog} <- originals, message <- catalog.messages do
      id = identity(message)

      unless MapSet.member?(used, {domain, id}),
        do: raise(ArgumentError, "Unmapped original #{app}/#{domain} identity: #{inspect(id)}")
    end

    :ok
  end

  @spec validate_original!(
          %{String.t() => Expo.Messages.t()},
          %{String.t() => Expo.Messages.t()},
          String.t()
        ) :: :ok
  defp validate_original!(catalogs, templates, locale) do
    unless Enum.sort(Map.keys(catalogs)) == Enum.sort(Map.keys(templates)),
      do: raise(ArgumentError, "Original domains differ for #{locale}")

    Enum.each(templates, fn {domain, template} ->
      expected = template |> message_index() |> Map.keys() |> MapSet.new()
      actual = catalogs |> Map.fetch!(domain) |> message_index() |> Map.keys() |> MapSet.new()

      unless expected == actual,
        do: raise(ArgumentError, "Original identities differ for #{locale}/#{domain}")
    end)
  end

  @spec migrate_reviews(Path.t(), Path.t(), app(), [mapping()], %{Path.t() => binary()}) :: %{
          Path.t() => binary()
        }
  defp migrate_reviews(original, destination, app, mappings, files) do
    path = Path.join(original, "reviewed_source_equal.json")

    if File.exists?(path) do
      records = path |> File.read!() |> JSON.decode!()
      unless is_list(records), do: raise(ArgumentError, "Invalid source review manifest")

      reviews =
        Enum.flat_map(records, fn record ->
          validate_review!(record, app)
          validate_review_source!(record, original)

          id = {record["context"], record["msgid"], record["msgid_plural"]}

          destinations =
            Enum.filter(mappings, &(&1.from == record["domain"] and &1.identity == id))

          if destinations == [],
            do: raise(ArgumentError, "Unmapped source review: #{inspect(id)}")

          Enum.map(destinations, &Map.put(record, "domain", &1.to))
        end)
        |> Enum.sort_by(
          &{&1["app"], &1["locale"], &1["domain"], &1["context"], &1["msgid"], &1["msgid_plural"],
           &1["form"]}
        )

      keys =
        Enum.map(reviews, &Map.take(&1, ~w(app locale domain context msgid msgid_plural form)))

      if length(keys) != length(Enum.uniq(keys)),
        do: raise(ArgumentError, "Duplicate reviewed source identities")

      Map.put(
        files,
        Path.join(destination, "reviewed_source_equal.json"),
        IO.iodata_to_binary([encode_json(reviews), "\n"])
      )
    else
      files
    end
  end

  @spec validate_review_source!(%{String.t() => json()}, Path.t()) :: :ok
  defp validate_review_source!(record, original) do
    catalog =
      Path.join([original, record["locale"], "LC_MESSAGES", record["domain"] <> ".po"])
      |> Expo.PO.parse_file!()

    id = {record["context"], record["msgid"], record["msgid_plural"]}
    message = catalog |> message_index() |> Map.fetch!(id)

    forms =
      case message do
        %Singular{} -> %{0 => message.msgstr}
        %Plural{} -> message.msgstr
      end

    value = forms |> Map.fetch!(record["form"]) |> IO.iodata_to_binary()

    unless value != "" and value in [record["msgid"], record["msgid_plural"]] and
             not Expo.Message.has_flag?(message, "fuzzy"),
           do: raise(ArgumentError, "Stale or ineligible source review")

    :ok
  end

  @spec validate_review!(term(), app()) :: :ok
  defp validate_review!(record, app) do
    unless is_map(record) and Enum.sort(Map.keys(record)) == Enum.sort(@review_fields) and
             record["app"] == Atom.to_string(app) and
             Enum.all?(~w(app locale domain msgid reason note), fn field ->
               is_binary(record[field]) and String.trim(record[field]) != ""
             end) and
             Enum.all?(~w(context msgid_plural), fn field ->
               is_nil(record[field]) or is_binary(record[field])
             end) and is_integer(record["form"]) and record["form"] >= 0 and
             record["reason"] in ~w(brand unit cognate technical_literal),
           do: raise(ArgumentError, "Invalid source review record")

    :ok
  end

  @spec mapping_json(mapping()) :: json()
  defp mapping_json(mapping) do
    {context, source, plural} = mapping.identity

    %{
      "from" => mapping.from,
      "to" => mapping.to,
      "context" => context,
      "msgid" => source,
      "msgid_plural" => plural
    }
  end

  @spec text(nil | iodata()) :: String.t() | nil
  defp text(nil), do: nil
  defp text(value), do: IO.iodata_to_binary(value)

  @spec encode_json(json()) :: iodata()
  defp encode_json(value) when is_map(value) do
    entries =
      value
      |> Enum.sort()
      |> Enum.map(fn {key, nested} -> [JSON.encode!(key), ":", encode_json(nested)] end)

    ["{", Enum.intersperse(entries, ","), "}"]
  end

  defp encode_json(value) when is_list(value),
    do: ["[", Enum.intersperse(Enum.map(value, &encode_json/1), ","), "]"]

  defp encode_json(value), do: JSON.encode!(value)
end
