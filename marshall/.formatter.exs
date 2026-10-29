[
  import_deps: [
    :ash_paper_trail,
    :cinder,
    :ash_state_machine,
    :ash_oban,
    :oban,
    :ash_admin,
    :ash_authentication_phoenix,
    :ash_authentication,
    :ash_scim,
    :ash_postgres,
    :ash_phoenix,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,lib,test,scripts}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "../scripts/*.{ex,exs}",
    "../.formatter.exs"
  ]
]
