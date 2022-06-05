defmodule SaasKit.MixUtils do
  alias SaasKit.MixUtils.AccountScoped
  alias SaasKit.MixUtils.TemplatesLoader
  alias SaasKit.MixUtils.InstructionParser

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @switches [binary_id: :boolean, table: :string, web: :string,
             schema: :boolean, context: :boolean, context_app: :string]

  @default_opts [schema: true, context: true]

  defdelegate account_scoped_question(args), to: AccountScoped
  defdelegate load_templates(resource, name), to: TemplatesLoader
  defdelegate follow_instructions(instructions), to: InstructionParser

  def refute_umbrella(task_name \\ "task") do
    if Mix.Project.umbrella?() do
      Mix.raise "mix #{task_name} must be invoked from within your *_web application root directory"
    end
  end

  def build_resource_from_args(args, help) do
    build(args, help)
    # |> inject_additional_args(args)
    |> TemplatesLoader.build_resource()
  end

  def build(args, help \\ __MODULE__) do
    {opts, parsed, _} = parse_opts(args)
    [context_name, schema_name, plural | schema_args] = validate_args!(parsed, help)
    schema_module = inspect(Module.concat(context_name, schema_name))
    schema = Gen.Schema.build([schema_module, plural | schema_args], opts, help)
    context = Context.new(context_name, schema, opts)
    {context, schema}
  end

  defp parse_opts(args) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)
    merged_opts =
      @default_opts
      |> Keyword.merge(opts)
      |> put_context_app(opts[:context_app])

    {merged_opts, parsed, invalid}
  end

  defp put_context_app(opts, nil), do: opts

  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  defp validate_args!([context, schema, _plural | _] = args, help) do
    cond do
      not Context.valid?(context) ->
        help.raise_with_help "Expected the context, #{inspect context}, to be a valid module name"
      not Schema.valid?(schema) ->
        help.raise_with_help "Expected the schema, #{inspect schema}, to be a valid module name"
      context == schema ->
        help.raise_with_help "The context and schema should have different names"
      context == Mix.Phoenix.base() ->
        help.raise_with_help "Cannot generate context #{context} because it has the same name as the application"
      schema == Mix.Phoenix.base() ->
        help.raise_with_help "Cannot generate schema #{schema} because it has the same name as the application"
      true ->
        args
    end
  end

  defp validate_args!(_, help) do
    help.raise_with_help "Invalid arguments"
  end
end
