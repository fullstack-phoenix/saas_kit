---
name: command-palette
description: Use when the app needs a Cmd+K/Ctrl+K command palette for quick navigation and search. Covers installing the LiveView palette, its protocol-based result formatting, and how to make resources searchable.
user-invocable: true
---

# Command Palette

Adds a keyboard-driven command palette to the app. Press `Cmd+K` (macOS) or
`Ctrl+K` (Windows/Linux) to open an overlay that searches routes and database
records, then jumps to the result. It ships as a `live_render`ed LiveView mounted
in the root layout, a `CommandPalette` search module with per-context scopes
(`app`, and `admin` when present), and a `CommandPalette.Format` protocol you
implement to make any schema searchable.

## When to use

- The app has grown enough navigation that users want a fast keyboard shortcut to
  jump between pages.
- You want a single search box over both routes and records (users, posts, teams).
- Don't reach for it on a tiny one- or two-page app — a nav bar is enough.

## Dependencies

- Requires: None.
- Recommended: None. Record search uses `Flop` (`Flop.validate_and_run/3`), so
  schemas you want searchable must already be Flop-configured. Routes-only search
  needs nothing extra.

## Install

```bash
mix saaskit.feature.install command_palette
```

No installer decisions. The task wires up the JS hook and `hotkeys.js` vendor file,
generates the `CommandPalette` modules, mounts the LiveView in the root layout, and
injects a search button after the theme toggle in the `app` (and `admin`) layouts.

## What it generates

- `lib/my_app_web/command_palette/command_palette.ex` — `MyAppWeb.CommandPalette`,
  the search entry point. Holds `@possible_contexts`, `routes/1`, and `schemas/1`.
- `lib/my_app_web/command_palette/format.ex` — the `MyAppWeb.CommandPalette.Format`
  protocol plus default `impl`s for `Map` (routes) and `MyApp.Users.User`.
- `lib/my_app_web/command_palette/result.ex` — `Result` struct wrapping each hit
  (`:record`, `:type`, `:first_type`, `:index`).
- `lib/my_app_web/live/command_palette_live.ex` — the palette LiveView.
- `assets/js/hooks/command_palette.js` + `assets/vendor/hotkeys.js` — the JS hook
  and key-binding library; wired into `assets/js/hooks/index.js` and `app.js`.
- Mounts `live_render(..., MyAppWeb.Live.CommandPaletteLive, ...)` in
  `lib/my_app_web/components/layouts/root.html.heex` and adds the `⌘K` button to
  the `app`/`admin` layouts.
- Tests under `test/my_app_web/`.

## Configuration

No config keys. Scopes are code, not config — the `@possible_contexts` list in
`MyAppWeb.CommandPalette` controls which contexts are valid, and the root-layout
mount picks the context per request path:

```elixir
# lib/my_app_web/command_palette/command_palette.ex
@possible_contexts ["app", "admin"]
```

```heex
{live_render(
  @conn,
  MyAppWeb.Live.CommandPaletteLive,
  id: "command-palette-lv",
  session: %{"context" => if(@conn.request_path =~ "/admin", do: "admin", else: "app")}
)}
```

## Tweaking for your app

Make a schema searchable in two steps. First add it to the relevant `schemas/1`
clause (record search runs it through Flop):

```elixir
# lib/my_app_web/command_palette/command_palette.ex
def schemas("app") do
  [
    MyApp.Blog.Post
    ## ADD ADDITIONAL SCHEMAS BELOW ##
  ]
end
```

Then implement the `Format` protocol so results render and link correctly:

```elixir
# lib/my_app_web/command_palette/format.ex
defimpl MyAppWeb.CommandPalette.Format, for: MyApp.Blog.Post do
  use MyAppWeb, :verified_routes
  def header(_), do: "Posts"
  def label(%{title: title}), do: title
  def link(%{id: id}, _context), do: ~p"/posts/#{id}"
end
```

Add a static route to the palette by extending the matching `routes/1` clause:

```elixir
# lib/my_app_web/command_palette/command_palette.ex
def routes("app") do
  [
    %{label: gettext("Dashboard"), path: ~p"/"},
    %{label: gettext("Posts"), path: ~p"/posts"}
    ## ADD ADDITIONAL ROUTES BELOW ##
  ]
end
```

- **New scope:** add a string to `@possible_contexts`, give it `routes/1` and
  `schemas/1` clauses, and mount the LiveView with that `"context"` session value.
- **Filter behavior:** record search uses `%{op: :ilike_or, field: :search_phrase}`
  with `limit: 4` per schema; route matching is prefix-only (`String.starts_with?`).

## After install

- [ ] Confirm `live_render` for `CommandPaletteLive` is mounted in the root layout
      (the installer injects it after `{@inner_content}`).
- [ ] Implement `MyAppWeb.CommandPalette.Format` for each resource you want
      searchable (User, Post, Team, …).
- [ ] Add any extra schemas/routes to `@possible_contexts`, `routes/1`, and
      `schemas/1` in `lib/my_app_web/command_palette/command_palette.ex`.
- [ ] Press `Cmd+K` / `Ctrl+K` in the browser to confirm it opens.
