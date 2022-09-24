defmodule SaasKit.UI do
  defmacro __using__(_opts) do
    quote do
      alias SaasKit.UI
      # import SaasKit.UI.Card
      # import SaasKit.UI.Modal
      # import SaasKit.UI.Table
    end
  end

  import Phoenix.Component, only: [assign_new: 3]

  def maybe_assign_dom_id(assigns) do
    assigns |> assign_new(:id, fn -> set_id() end)
  end

  def set_id do
    rand = :crypto.strong_rand_bytes(8)

    hash =
      :crypto.hash(:md5, rand)
      |> Base.encode16(case: :lower)

    "x#{hash}"
  end
end
