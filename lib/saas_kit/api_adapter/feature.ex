defmodule SaasKit.ApiAdapter.Feature do
  @base_url "https://livesaaskit.com/"
  # @resource "feature"

  defp get_api_key, do: Application.get_env(:saas_kit, :api_key)
  defp get_url, do: (Application.get_env(:saas_kit, :url) || @base_url)

  def get_features() do
    get()
    |> parse_data()
  end

  def get_feature(params) do
    %{feature: params}
    |> Jason.encode!()
    |> post()
    |> parse_data()
  end

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

  defp get(path \\ "features") do
    HTTPoison.get("#{get_url()}/api/#{path}", [
      {"Content-Type", "application/json"},
      {"x-api-key", get_api_key()}
    ])
  end

  defp post(params, path \\ "features") do
    HTTPoison.post("#{get_url()}/api/#{path}", params, [
      {"Content-Type", "application/json"},
      {"x-api-key", get_api_key()}
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
