# Run from Marshall with its pinned dependencies:
# mix run --no-start ../scripts/migrate_localization_catalogs.exs --snapshot PATH [--write|--check]
# Optional exact source inventory: --new-sources PATH
Code.require_file("localization_catalog_migration.ex", __DIR__)
Code.require_file("localization_catalog_migration_cli.ex", __DIR__)
Overalls.LocalizationCatalogMigration.CLI.run(System.argv())
