defmodule MockStripe.Product do
  defstruct [
    :created,
    :id,
    :name,
    :object,
    :updated,
    :active
  ]

  alias MockStripe.List
  alias MockStripe.Product

  def retrieve() do
    stripe_id = "prod_#{MockStripe.token()}"
    retrieve(stripe_id)
  end

  def retrieve("prod_" <> _ = stripe_id) do
    %Product{
      created: 1_600_353_622,
      id: stripe_id,
      name: "Premium Plan",
      object: "product",
      updated: 1_600_798_919,
      active: true
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
       url: "/v1/products"
     }}
  end

  def create(attrs \\ %{}) do
    {:ok,
     %Product{
       created: 1_622_123_382,
       id: "prod_#{MockStripe.token()}",
       name: Map.get(attrs, :name, "Product Name"),
       object: "product",
       updated: 1_622_123_382,
       active: true
     }}
  end

  def update(stripe_id, attrs \\ %{}) do
    {:ok,
     %Product{
       created: 1_622_123_382,
       id: stripe_id,
       name: Map.get(attrs, :name, "Product Name"),
       object: "product",
       updated: 1_622_123_382,
       active: true
     }}
  end
end
