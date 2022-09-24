defmodule SaasKit.LiveComponents.DataTable do
  @moduledoc """
  Data tables are used to display large sets of data in a structured way
  with sorting and pagination.
  """
  import Phoenix.Component
  import Phoenix.LiveView.Helpers

  def data_table_link(assigns) do
    params = Map.get(assigns, :params, %{})
    sort_by = Map.get(assigns, :sort)

    assigns =
      assigns
      |> assign_new(:querystring, fn ->
        opts = opts_from_params(params, sort_by)
        "?#{querystring(params, opts)}"
      end)
      |> assign_new(:class, fn -> "" end)

    ~H"""
    <a class={@class} data-phx-link="patch" data-phx-link-state="push" href={@querystring}>
      <%= render_slot(@inner_block) %>
    </a>
    """
  end

  @doc false
  def opts_from_params(%{} = sort_params, field) do
    sort_field = Map.get(sort_params, "sort_field", "")
    direction = Map.get(sort_params, "sort_direction")

    [
      page: nil,
      sort_field: field,
      sort_direction: (if sort_field == to_string(field), do: reverse(direction), else: "desc")
    ]
  end

  def querystring(params, opts \\ %{}) do
    params = params |> Plug.Conn.Query.encode() |> URI.decode_query()

    opts = %{
      "page" => opts[:page], # For the pagination
      "sort_field" => opts[:sort_field] || params["sort_field"] || nil,
      "sort_direction" => opts[:sort_direction] || params["sort_direction"] || nil
    }

    params
    |> Map.merge(opts) # map
    |> Enum.filter(fn {_, v} -> v != nil end) # returns a list of tuples
    |> Enum.into(%{}) # back into map
    |> URI.encode_query() # string
  end

  defp reverse("desc"), do: "asc"
  defp reverse(_), do: "desc"

  ##############################################################################################

  def pagination(assigns) do
    assigns =
      assigns
      |> assign(:pagination_links, SaasKit.Pagination.LinkBuilder.raw_pagination_links(assigns))

    ~H"""
    <div class="flex justify-center">
      <%= if show_pagination?(@total_pages) do %>
        <nav class="flex" role="navigation" aria-label="Navigation">
          <.prev pagination_links={@pagination_links} params={@params} />
          <div class="btn-group flex">
            <%= for page <- @pagination_links do %>
              <.pagination_link page={page} page_number={@page_number} params={@params} />
            <% end %>
          </div>
          <.next pagination_links={@pagination_links} params={@params} />
        </nav>
      <% end %>
    </div>
    """
  end

  defp prev(assigns) do
    prev_page =
      case Enum.find(assigns.pagination_links, fn {sym, _page} -> sym == "<<" end) do
        {_, page} -> page
        _ -> nil
      end

    assigns =
      assigns
      |> assign(:page, prev_page)

    if prev_page do
      ~H"""
      <%= live_patch to: build_querystring(@params, @page), class: "btn mr-2" do %>
        «
      <% end %>
      """
    else
      ~H"""
      <a class="btn mr-2 btn-disabled">
        «
      </a>
      """
    end
  end

  defp next(assigns) do
    next_page =
      case Enum.find(assigns.pagination_links, fn {sym, _page} -> sym == ">>" end) do
        {_, page} -> page
        _ -> nil
      end

    assigns =
      assigns
      |> assign(:page, next_page)

    if next_page do
      ~H"""
      <%= live_patch to: build_querystring(@params, @page), class: "btn ml-2" do %>
        »
      <% end %>
      """
    else
      ~H"""
      <a class="btn ml-2 btn-disabled">»</a>
      """
    end
  end

  defp pagination_link(%{page: {:ellipsis, _}} = assigns) do
    ~H"""
    <a class="btn">…</a>
    """
  end

  defp pagination_link(%{page: {_, page}, page_number: page_number} = assigns) when page == page_number do
    ~H"""
    <a class="btn btn-disabled">
      <%= @page_number %>
    </a>
    """
  end

  defp pagination_link(%{page: {sym, _}} = assigns) when sym in ["<<", ">>"] do
    ~H""
  end

  defp pagination_link(%{page: {_, page}} = assigns) do
    assigns = assign(assigns, :page, page)
    ~H"""
    <%= live_patch to: build_querystring(@params, @page), class: "btn" do %>
      <%= @page %>
    <% end %>
    """
  end

  defp build_querystring(params, page) do
    string =
      params
      |> Map.merge(%{"page" => page}) # map
      |> URI.encode_query()

    "?#{string}"
  end

  defp show_pagination?(total_pages), do: total_pages > 1
end
