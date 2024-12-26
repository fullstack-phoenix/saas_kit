defmodule SaasKit.RemoveBinaryId do
  def run(app_name) do
    Path.wildcard("priv/repo/migrations/*.*exs")
    |> Enum.each(&replace_binary_id_in_migration_file/1)

    replace_binary_id_in_schema_file(app_name)
    replace_binary_id_in_config_file()
    replace_binary_id_in_test_files()
    replace_binary_in_schema_files(app_name)

    :ok
  end

  defp replace_binary_id_in_schema_file(app_name) do
    "lib/#{app_name}/schema.ex"
    |> read_file()
    |> String.replace(
      "\n      @primary_key {:id, :binary_id, autogenerate: true}\n      @foreign_key_type :binary_id\n",
      "\n"
    )
    |> write_file("lib/#{app_name}/schema.ex")
  end

  defp replace_binary_id_in_config_file do
    "config/config.exs"
    |> read_file()
    |> String.replace(", type: :binary_id", "")
    |> String.replace(", binary_id: true", "")
    |> write_file("config/config.exs")
  end

  defp replace_binary_id_in_migration_file(filename) do
    filename
    |> read_file()
    |> String.replace(
      ", primary_key: false) do\n      add :id, :binary_id, primary_key: true\n",
      ") do\n"
    )
    |> String.replace(", type: :binary_id", "")
    |> String.replace("_id, :binary\n", "_id, :integer\n")
    |> write_file(filename)
  end

  defp replace_binary_in_schema_files(app_name) do
    ["lib/#{app_name}/users/user.ex", "lib/#{app_name}/users/user_token.ex"]
    |> Enum.each(fn filename ->
      filename
      |> read_file()
      |> String.replace("_id, :binary\n", "_id, :integer\n")
      |> String.replace(
        "  @primary_key {:id, :binary_id, autogenerate: true}\n  @foreign_key_type :binary_id",
        "\n"
      )
      |> write_file(filename)
    end)
  end

  defp replace_binary_id_in_test_files do
    Path.wildcard("test/**/*_test.exs")
    |> Enum.each(fn filename ->
      filename
      |> read_file()
      |> String.replace("\"11111111-1111-1111-1111-111111111111\"", "-1")
      |> write_file(filename)
    end)
  end

  defp read_file(filename) do
    File.read!(filename)
  end

  defp write_file(content, filename) do
    File.write(filename, content)
  end
end
