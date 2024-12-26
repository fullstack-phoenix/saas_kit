defmodule SaasKit.ApiAdapter.Kit do
  @base_url "https://livesaaskit.com"

  defp get_api_key, do: Application.get_env(:saas_kit, :api_key)
  defp get_url, do: (Application.get_env(:saas_kit, :url) || @base_url)

  def get_instructions(token, options \\ %{}) do
    token
    |> get(options)
    |> maybe_debug()
    |> parse_data()
  end

  defp get(token, options) do
    HTTPoison.get("#{get_url()}/api/kits/#{token}?#{querystring(options)}", [
      {"Content-Type", "application/json"},
      {"x-api-key", get_api_key()}
    ])
  end

  defp querystring(options) do
    options
    |> Enum.reduce([], fn {k, v}, memo -> ["#{k}=#{v}"|memo] end)
    |> Enum.join("&")
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
