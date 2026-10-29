defmodule Overalls.LocalizationCatalogMigration.CLI do
  @moduledoc "Validated command-line boundary for the exact catalog migration."
  alias Overalls.LocalizationCatalogMigration, as: Migration

  @type options :: %{
          snapshot: Path.t(),
          root: Path.t(),
          mode: :dry_run | :check | :write,
          report: Path.t() | nil,
          new_sources: Path.t() | nil
        }
  @usage "usage: migrate_localization_catalogs.exs --snapshot PATH [--root PATH] [--new-sources PATH] [--write|--check] [--report PATH]"

  @spec run([String.t()]) :: :ok
  def run(args) do
    options = parse!(args)

    new_sources =
      if is_nil(options.new_sources),
        do: [],
        else: options.new_sources |> File.read!() |> JSON.decode!()

    plan =
      Migration.plan(
        options.root,
        options.snapshot,
        [:marshall, :porsche],
        new_sources
      )

    :ok = Migration.apply(plan, options.mode)
    report = Migration.report(plan)
    if is_nil(options.report), do: IO.write(report), else: File.write!(options.report, report)
  end

  # @cc [owner:ghuntley,label:verification] localization-cli-explicit-write
  # Missing or conflicting mode arguments MUST fail before migration work. Dry
  # runs and checks MUST write neither catalogs nor report files; report-file
  # output MUST require the explicit --write mode.
  @spec parse!([String.t()]) :: options()
  def parse!(args) do
    {options, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          snapshot: :string,
          root: :string,
          write: :boolean,
          check: :boolean,
          report: :string,
          new_sources: :string
        ]
      )

    write? = Keyword.get(options, :write, false)
    check? = Keyword.get(options, :check, false)

    unless rest == [] and invalid == [] and is_binary(options[:snapshot]) and
             not (write? and check?) and (is_nil(options[:report]) or write?),
           do: raise(ArgumentError, @usage)

    mode =
      cond do
        write? -> :write
        check? -> :check
        true -> :dry_run
      end

    %{
      snapshot: options[:snapshot],
      root: options[:root] || Path.expand("..", __DIR__),
      mode: mode,
      report: options[:report],
      new_sources: options[:new_sources]
    }
  end
end
