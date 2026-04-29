defmodule SaasKit.API do
  @moduledoc """
  Thin wrapper around the livesaaskit.com HTTP API.

  Tasks call through this module so URL construction, auth handling, and
  HTTP client setup live in one place.
  """

  @default_base_url "https://livesaaskit.com"

  @doc "Returns the configured base URL, or the livesaaskit.com default."
  def base_url do
    Application.get_env(:saas_kit, :base_url) || @default_base_url
  end

  @doc "Returns the configured boilerplate token, or nil if unconfigured."
  def token do
    Application.get_env(:saas_kit, :boilerplate_token)
  end

  @doc """
  Fetches the feature list for the configured boilerplate.

  Returns:
    * `{:ok, boilerplate, features}` on success
    * `{:error, :not_found}` when the token does not resolve
    * `{:error, :api_unreachable}` on network / non-200 failure
  """
  def fetch_features do
    Application.ensure_all_started([:req, :hex])
    url = "#{base_url()}/api/boilerplate/features/#{token()}"

    case Req.get(url) do
      {:ok, %{status: 200, body: %{"boilerplate" => bp, "features" => features}}} ->
        {:ok, bp, features}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      _ ->
        {:error, :api_unreachable}
    end
  end
end
