defmodule SaasKit.UI.Modal do
  use Phoenix.Component

  def modal(assigns) do
    ~H"""
    <div id="my-modal">
      <.modal_body>
        MODAL CONTENT
      </.modal_body>
    </div>
    """
  end

  def modal_body(assigns) do
    ~H"""
    <div id="my-modal-body">
      <%= render_block(@inner_block) %>
    </div>
    """
  end
end
