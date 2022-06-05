defmodule SaasKit.MixUtils.TemplatesLoader do
  def build_resource({context, schema}) do
    opts = Enum.into(schema.opts , %{})

    associations =
      Enum.map(schema.assocs, &extract_associations/1)
      |> Enum.reject(&is_nil/1)

    account_scoped =
      Enum.reduce(schema.assocs, false, fn assocs, acc  ->
        acc == true || is_account_scoped?(assocs)
      end)

    fields =
      schema.types
      |> Enum.map(fn {field, type} -> "#{field}:#{type}" end)
      |> Enum.join(" ")

    %{
      app_name_lower: "#{context.context_app}",
      app_name: Macro.camelize("#{context.context_app}"),
      context_name: context.name,
      schema_name: schema.human_singular,
      table_name: schema.table,
      fields: fields,
      types: schema.types,
      web_namespace: schema.web_namespace,
      indexes: schema.indexes,
      migration: schema.migration?,
      embedded: schema.embedded?,
      binary_id: schema.binary_id,
      route_helper: schema.route_helper,
      account_scoped: account_scoped,
      associations: associations
    }
    |> Map.merge(opts)
  end

  def load_templates(args, name) do
    SaasKit.ApiAdapter.run(args, name)
  end

  defp is_account_scoped?({:account, _, _, _}), do: true
  defp is_account_scoped?(_), do: false

  defp extract_associations({singular, foreign_key, schema_module, table_name}) do
    %{
      singular: singular,
      foreign_key: foreign_key,
      schema_module: schema_module,
      table_name: table_name
    }
  end
  defp extract_associations(_), do: nil
end

# %Mix.Phoenix.Schema{
#   file: "lib/racer/ninjas/ninja.ex",
#   migration_module: Ecto.Migration,
#   indexes: ["create index(:ninjas, [:ninja_level_id])",
#    "create index(:ninjas, [:account_id])"],
#   table: "ninjas",
#   web_namespace: nil,
#   params: %{
#     create: %{name: "some name", skill: 42},
#     default_key: :name,
#     update: %{name: "some updated name", skill: 43}
#   },
#   repo: Racer.Repo,
#   alias: Ninja,
#   generate?: true,
#   web_path: nil,
#   sample_id: "11111111-1111-1111-1111-111111111111",
#   opts: [binary_id: true, schema: true, context: true],
#   singular: "ninja",
#   human_plural: "Ninjas",
#   plural: "ninjas",
#   uniques: [],
#   attrs: [name: :string, skill: :integer],
#   defaults: %{name: "", skill: ""},
#   assocs: [
#     {:ninja_level_id, :ninja_level_id, "Racer.Ninjas.NinjaLevel",
#      :ninja_levels},
#     {:account, :account_id, "Racer.Ninjas.Account", :accounts}
#   ],
#   string_attr: :name,
#   migration?: true,
#   redacts: [],
#   human_singular: "Ninja",
#   module: Racer.Ninjas.Ninja,
#   collection: "ninjas",
#   context_app: :racer,
#   route_helper: "ninja",
#   fixture_unique_functions: %{},
#   embedded?: false,
#   types: %{name: :string, skill: :integer},
#   migration_defaults: %{name: "", skill: ""},
#   prefix: nil,
#   binary_id: true,
#   fixture_params: %{name: "\"some name\"", skill: "42"}
# }

# %Mix.Phoenix.Context{
#   alias: Sites,
#   base_module: Fueled,
#   basename: "sites",
#   context_app: :fueled,
#   dir: "lib/fueled/sites",
#   file: "lib/fueled/sites.ex",
#   generate?: true,
#   module: Fueled.Sites,
#   name: "Sites",
#   opts: [schema: true, context: true],
#   schema: %Mix.Phoenix.Schema{
#     context_app: :fueled,
#     migration_module: Ecto.Migration,
#     types: %{css_framework: :string, name: :string, type: :string},
#     web_path: nil,
#     singular: "site",
#     defaults: %{css_framework: "", name: "", type: ""},
#     route_helper: "site",
#     params: %{
#       create: %{
#         css_framework: "some css_framework",
#         name: "some name",
#         type: "some type"
#       },
#       default_key: :css_framework,
#       update: %{
#         css_framework: "some updated css_framework",
#         name: "some updated name",
#         type: "some updated type"
#       }
#     },
#     indexes: ["create index(:sites, [:account_id])"],
#     human_plural: "Sites",
#     attrs: [name: :string, type: :string, css_framework: :string],
#     prefix: nil,
#     web_namespace: nil,
#     repo: Fueled.Repo,
#     embedded?: false,
#     migration_defaults: %{css_framework: "", name: "", type: ""},
#     fixture_params: %{
#       css_framework: "\"some css_framework\"",
#       name: "\"some name\"",
#       type: "\"some type\""
#     },
#     plural: "sites",
#     redacts: [],
#     uniques: [],
#     table: "sites",
#     module: Fueled.Sites.Site,
#     sample_id: "11111111-1111-1111-1111-111111111111",
#     assocs: [{:account, :account_id, "Fueled.Sites.Account", :accounts}],
#     generate?: true,
#     fixture_unique_functions: %{},
#     string_attr: :css_framework,
#     opts: [binary_id: true, schema: true, context: true],
#     file: "lib/fueled/sites/site.ex",
#     binary_id: true,
#     alias: Site,
#     collection: "sites",
#     human_singular: "Site",
#     migration?: true
#   },
#   test_file: "test/fueled/sites_test.exs",
#   test_fixtures_file: "test/support/fixtures/sites_fixtures.ex",
#   web_module: FueledWeb
# }
