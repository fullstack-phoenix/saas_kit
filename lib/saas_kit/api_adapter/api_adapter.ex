defmodule SaasKit.ApiAdapter do
  @base_url "http://localhost:4000"

  def run(resource, name) do
    fields =
      Map.get(resource, :types, %{})
      |> Enum.map(fn {k, v} ->
        %{name: k, type: v}
      end)

    %{
      generator: %{
        id: String.replace(name, ".", "-"),
        fields: fields,
        data: resource
      }
    }
    |> IO.inspect()
    |> Jason.encode!()
    |> post()
    |> parse_data()
  end

  defp post(params) do
    api_key = Application.get_env(:saas_kit, :api_key)

    HTTPoison.post("#{@base_url}/api/generators", params, [
      {"Content-Type", "application/json"},
      {"x-api-key", api_key}
    ])
  end

  defp parse_data({:ok, %HTTPoison.Response{body: body}}) do
    try do
      body
      |> Jason.decode!()
      |> case do
        %{"data" => %{"instructions" => instructions}} -> instructions
        %{"data" => [_|_] = instructions} -> instructions
        _ -> []
      end
    rescue
      _ ->
        Mix.shell().error """
        There was an error parsing the data.
        """
        []
    end
  end

  defp parse_data(_), do: {:error, "There was an error"}
end
