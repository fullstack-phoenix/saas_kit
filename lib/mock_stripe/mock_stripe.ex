defmodule MockStripe do
  # NEEDED FOR GENERATING STRIPE LIKE CUSTOM TOKENS
  def token do
    :crypto.strong_rand_bytes(25)
    |> Base.url_encode64()
    |> binary_part(0, 25)
    |> String.replace(~r/(_|-)/, "")
    |> String.slice(0..15)
  end
end
