---
name: 404-page
description: Use when the app needs branded 404 and 500 error pages and a way to raise not-found from LiveViews. Covers install, the Fallback exception, and tweaking the templates.
user-invocable: true
---

# 404 and 500 Pages

Replaces Phoenix's plain-text default error pages with branded, responsive 404
and 500 HTML templates, enables `embed_templates` in the `ErrorHTML` controller,
and adds a `Fallback` exception module so LiveViews can raise a 404 for missing
resources.

## When to use

- The app should show styled, on-brand error pages instead of the framework
  defaults.
- A LiveView needs to return a real 404 when a resource isn't found, instead of
  letting `Ecto.NoResultsError` bubble up.
- Don't bother if you're fine with Phoenix's built-in `"Not Found"` /
  `"Internal Server Error"` plain pages.

## Dependencies

- Requires: None.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install 404_page
```

No decisions to answer. The installer uncomments `embed_templates` in the error
controller, drops in the HEEx templates and the `Fallback` module, relaxes the
two error-html test assertions to regex matches, and runs `mix format`.

## What it generates

- `lib/my_app_web/controllers/error_html.ex` — uncomments
  `embed_templates "error_html/*"` so the new HEEx templates are used.
- `lib/my_app_web/controllers/error_html/404.html.heex` — branded 404 page
  (daisyUI/Tailwind classes, `gettext/1` strings, link back home).
- `lib/my_app_web/controllers/error_html/500.html.heex` — branded 500 page.
- `lib/my_app_web/fallback.ex` — `MyAppWeb.Fallback` exception with
  `plug_status: 404`.
- `test/my_app_web/controllers/error_html_test.exs` — assertions switched from
  `==` to `=~` so they tolerate the custom markup.

## Configuration

No config keys are added. To preview the live pages in development, temporarily
disable `debug_errors`:

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  debug_errors: false
```

Set it back to `true` when you're done so you keep the dev exception trace.

## Tweaking for your app

Raise a 404 from a LiveView when a record is missing:

```elixir
# lib/my_app_web/live/post_live.ex
defmodule MyAppWeb.PostLive do
  use MyAppWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    case MyApp.Posts.get_post(id) do
      nil -> raise MyAppWeb.Fallback
      post -> {:ok, assign(socket, :post, post)}
    end
  end
end
```

Rebrand the 404 copy and CTA in
`lib/my_app_web/controllers/error_html/404.html.heex`:

```heex
<h1 class="mb-4 text-7xl tracking-tight font-extrabold lg:text-9xl text-info">
  404
</h1>
<p class="mb-4 text-3xl tracking-tight font-bold text-base-content md:text-4xl">
  {gettext("Something's missing.")}
</p>
<.link href={~p"/"} class="btn btn-info btn-lg my-4">
  {gettext("Back to Homepage")}
</.link>
```

- Swap the `text-info` / `btn-info` classes for your theme color.
- Keep strings wrapped in `gettext/1` so they stay translatable.
- Apply the same treatment to `500.html.heex` for server errors.

## After install

- [ ] In `config/dev.exs`, set `debug_errors: false` temporarily to preview the
      live error pages.
- [ ] Customize `lib/my_app_web/controllers/error_html/404.html.heex` and
      `500.html.heex` to match your brand.
- [ ] In LiveViews, `raise MyAppWeb.Fallback` for not-found resources instead of
      letting `Ecto.NoResultsError` bubble up.
