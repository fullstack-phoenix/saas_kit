defmodule SaasKit.UI.Dropdown do
  use Phoenix.Component

  def dropdown(assigns) do
    ~H"""
    <div class="dropdown">
      <%= render_block(@inner_block) %>
    </div>
    """
  end

  def dropdown_toggle(assigns) do
    ~H"""
    <div tabindex="0" class="m-1 btn">
      <%= render_block(@inner_block) %>
    </div>
    """
  end

  def dropdown_menu(assigns) do
    ~H"""
    <ul tabindex="0" class="p-2 shadow menu dropdown-content bg-base-100 rounded-box w-52">
      <%= render_block(@inner_block) %>
    </ul>
    """
  end

  def dropdown_divider(assigns) do
    ~H"""
    <li class="my-2 border border-t border-base-content border-opacity-10"></li>
    """
  end

  def dropdown_item(assigns) do
    ~H"""
    <li>
      <%= render_block(@inner_block) %>
    </li>
    """
  end
end
