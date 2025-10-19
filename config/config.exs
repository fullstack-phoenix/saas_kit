import Config

config :phoenix, :json_library, Jason

config :saas_kit,
  api_url: System.get_env("API_URL") || "https://livesaaskit.com"
