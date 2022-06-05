defmodule MockStripe.Subscription do
  defstruct [
    :id
  ]

  # alias MockStripe.List
  alias MockStripe.Subscription

  def create(_attrs \\ %{}) do
    {:ok,
     %Subscription{
       id: "prod_#{MockStripe.token()}"
     }}
  end
end
