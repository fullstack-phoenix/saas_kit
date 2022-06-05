defmodule MockStripe.PaymentIntent do
  defstruct [
    :id
  ]

  # alias MockStripe.List
  # alias MockStripe.PaymentIntent

  def retrieve(_ ,attrs) do
    attrs
  end
end
