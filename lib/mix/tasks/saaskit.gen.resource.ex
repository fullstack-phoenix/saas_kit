defmodule Mix.Tasks.Saaskit.Gen.Resource do
  @shortdoc "Generates a resource with functions around an Ecto schema"

  use Mix.Task
  import SaasKit.MixUtils

  @name "saaskit.gen.resource"

  @doc false
  # ["Ninjas", "Ninja", "ninjas", "name", "skill:integer",
  # "user_id:references:users", "--web", "Admin", "--i"]
  def run(args) do
    refute_umbrella(@name)

    Application.ensure_all_started(:hackney)

    args
    |> maybe_ask_account_scoped_question()
    |> build_resource_from_args(__MODULE__)
    |> additional_questions()
    |> load_templates(@name)
    |> follow_instructions()
  end

  def raise_with_help(msg) do
    Mix.raise """
    #{msg}

    mix saaskit.gen.resource
    expect a context module name, followed by singular and plural names
    of the generated resource, ending with any number of attributes.
    For example:

        mix saaskit.gen.resouerce Accounts User users name:string

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """
  end

  # %{
  #   account_scoped: false,
  #   app_name: "Racer",
  #   app_name_lower: "racer",
  #   associations: [
  #     %{
  #       foreign_key: :ninja_level_id,
  #       schema_module: "Racer.Ninjas.NinjaLevel",
  #       singular: :ninja_level,
  #       table_name: :ninja_levels
  #     }
  #   ],
  #   binary_id: true,
  #   context: true,
  #   context_name: "Ninjas",
  #   embedded: false,
  #   fields: "name:string skill:integer",
  #   indexes: ["create index(:ninjas, [:ninja_level_id])"],
  #   migration: true,
  #   route_helper: "ninja",
  #   schema: true,
  #   schema_name: "Ninja",
  #   table_name: "ninjas",
  #   types: %{name: :string, skill: :integer},
  #   web_namespace: nil
  # }
  defp maybe_ask_account_scoped_question(args) do
    case Enum.any?(args, fn arg -> String.contains?(arg, ":references:") end) do
      true -> args
      _ -> account_scoped_question(args)
    end
  end

  def additional_questions(argument_map) do
    argument_map
    |> ask_about_associations()
    |> ask_about_live(true)
    |> ask_about_admin(Application.get_env(:saas_kit, :admin) == true)
  end

  def ask_about_live(argument_map, false), do: argument_map
  def ask_about_live(argument_map, true) do
    Mix.shell().info """

    ===============================================================
    === Live CRUD Interface =======================================
    ===============================================================
    Do you want to add an LiveView interface with the CRUD actions
    """

    if Mix.shell().yes?(
      """
      #{IO.ANSI.green}Do you want to add an LiveView interface?#{IO.ANSI.reset}
      """ |> String.trim_trailing()) do

      argument_map
      |> Map.put(:live_view, true)
    else
      argument_map
      |> Map.put(:live_view, false)
    end
  end

  def ask_about_admin(argument_map, false), do: argument_map
  def ask_about_admin(%{web_namespace: "Admin"} = argument_map, true), do: Map.put(argument_map, :admin, true)
  def ask_about_admin(argument_map, true) do
    Mix.shell().info """

    ===============================================================
    === Admin Interface ===========================================
    ===============================================================
    Do you want to add an admin interface with the CRUD actions
    """

    if Mix.shell().yes?(
      """
      #{IO.ANSI.green}Do you want to add an admin interface?#{IO.ANSI.reset}
      """ |> String.trim_trailing()) do

      argument_map
      |> Map.put(:admin, true)
      |> Map.put_new(:web_namespace, "Admin")
    else
      argument_map
    end
  end

  def ask_about_associations(%{associations: []} = argument_map), do: argument_map
  def ask_about_associations(%{associations: [_|_] = associations} = argument_map) do
    associations =
      Enum.map(associations, &ask_about_association(&1))

    Map.put(argument_map, :associations, associations)
  end

  defp ask_about_association(%{table_name: table_name} = association) when table_name in ["accounts", :accounts] do
    association
  end
  defp ask_about_association(%{schema_module: schema_module, table_name: table_name} = association) do
    Mix.shell().info """

    ===============================================================
    === Associations ==============================================
    ===============================================================
    The resource seems to belong to another schema.
    """

    if Mix.shell().yes?(
      """
      Is this the correct context and schema?
      #{IO.ANSI.green}#{schema_module}#{IO.ANSI.reset}
      """ |> String.trim_trailing()) do
      association
    else
      [app_name, _, schema_name] = schema_module |> String.split(".")
      context_name = Macro.camelize "#{table_name}"

      maybe_schema_module = Enum.join([app_name, context_name, schema_name], ".")

      if Mix.shell().yes?(
        """
        Ok, is this then the correct context and schema?
        #{IO.ANSI.green}#{maybe_schema_module}#{IO.ANSI.reset}
        """ |> String.trim_trailing()) do
        Map.put(association, :schema_module, maybe_schema_module)
      else
        new_schema_module = question_with_fallback(
        """

        Add the new schema name (ex: MyApp.Todos.Todo):
        """, :schema_module)
        Map.put(association, :schema_module, new_schema_module)
      end
    end
  end

  def question_with_fallback(question, rule, valid \\ true) do
    if valid == false do
      Mix.shell().error """

      You entered an invalid value, try to enter again.
      """
    end

    response = Mix.shell().prompt(question)
    response = String.trim("#{response}")

    if response |> String.split(".") |> length() == 3 do
      String.trim(response)
    else
      question_with_fallback(question, rule, false)
    end
  end
end
