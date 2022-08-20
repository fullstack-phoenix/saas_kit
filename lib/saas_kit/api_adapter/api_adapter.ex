defmodule SaasKit.ApiAdapter do
  @base_url "https://livesaaskit.com/"

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
    |> maybe_debug()
    |> Jason.encode!()
    |> post()
    |> parse_data()
  end

  defp get_url do
    Application.get_env(:saas_kit, :url) || @base_url
  end

  defp post(params) do
    api_key = Application.get_env(:saas_kit, :api_key)

    HTTPoison.post("#{get_url()}/api/generators", params, [
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

  defp maybe_debug(data) do
    if Application.get_env(:saas_kit, :debug) do
      IO.inspect data
    end

    data
  end
end
