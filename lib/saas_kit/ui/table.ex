defmodule SaasKit.UI.Table do
  use Phoenix.Component

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class={"table w-full #{if assigns[:stripe], do: "table-zebra"}"}>
        <%= render_block(@inner_block) %>
      </table>
    </div>
    """
  end

  def sort_link(assigns) do
    assigns = Map.put_new(assigns, :sort_direction, "asc")
    assigns = Map.put_new(assigns, :sort_field, nil)

    ~H"""
    <th>
      <%= render_block(@inner_block) %>
    </th>
    """
  end

  # defp reverse("desc"), do: "asc"
  # defp reverse(_), do: "desc"
  #
  # defp caret("asc") do
  #   """
  #   <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="currentColor" class="w-3 h-3 ml-1" viewBox="0 0 16 16">
  #     <path d="M7.247 11.14 2.451 5.658C1.885 5.013 2.345 4 3.204 4h9.592a1 1 0 0 1 .753 1.659l-4.796 5.48a1 1 0 0 1-1.506 0z"/>
  #   </svg>
  #   """
  # end
  #
  # defp caret(_) do
  #   """
  #   <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="currentColor" class="w-3 h-3 ml-1" viewBox="0 0 16 16">
  #     <path d="m7.247 4.86-4.796 5.481c-.566.647-.106 1.659.753 1.659h9.592a1 1 0 0 0 .753-1.659l-4.796-5.48a1 1 0 0 0-1.506 0z"/>
  #   </svg>
  #   """
  # end
end
