defmodule MockStripe.Invoice do
  defstruct [
    :amount,
    :currency,
    :id,
    :status
  ]

  alias MockStripe.List
  alias MockStripe.Invoice

  def retrieve() do
    stripe_id = "in_#{MockStripe.token()}"
    retrieve(stripe_id)
  end

  def retrieve("in_" <> _ = stripe_id) do
    %Invoice{
      amount: 9900,
      currency: "usd",
      id: stripe_id,
      status: "paid",
    }
  end

  def list(_attrs \\ %{}) do
    {:ok,
     %List{
       data: [
         retrieve()
       ],
       has_more: false,
       object: "list",
       total_count: nil,
       url: "/v1/invoices"
     }}
  end
end
