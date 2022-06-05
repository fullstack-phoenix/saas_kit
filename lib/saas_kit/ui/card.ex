defmodule SaasKit.UI.Card do
  use Phoenix.Component

  def card(assigns) do
    ~H"""
    <div class={"card rounded shadow #{assigns[:class]}"}>
      <%= render_block(@inner_block) %>
    </div>
    """
  end
end
