---
name: layouts
description: Use when the app needs distinct layouts for authenticated pages, login/registration, and public marketing pages instead of Phoenix's single default layout. Covers install, the three layout modules, and how to tweak nav, logo, and avatar.
user-invocable: true
---

# Layouts

Replaces Phoenix's single default layout with three purpose-built layouts:
`Layouts.App` (authenticated app pages with sidebar nav, theme toggle, and user
menu), `Layouts.Session` (minimal chrome for login/registration), and
`Layouts.Public` (a top navbar for marketing/landing pages). It refactors the
generated `layouts.ex` to delegate to these modules, strips the menu out of the
root layout, and adds shared `logo/1` and `user_avatar/1` components. This is a
`core` feature most other UI builds on.

## When to use

- The app has more than one kind of page — app screens behind auth, auth forms,
  and public pages — and each needs different chrome.
- You want a sidebar app shell, a clean session layout, and a marketing navbar
  out of the box, all sharing one logo and avatar.
- Don't reach for this on a single-page app where the default Phoenix layout is
  enough. Install it early, before features that render their own pages.

## Dependencies

- Requires: None (`core` feature, `position` 5).
- Recommended: None. Pairs naturally with `authentication` (the session layout
  wraps the login/registration/confirmation LiveViews).

## Install

```bash
mix saaskit.feature.install layouts
```

No decisions to make — the installer generates the three layout modules, swaps
the auth LiveViews onto `Layouts.Session.page`, removes the nav `ul` from the
root layout, rewrites `Layouts.app/1` to call `Layouts.App.page/1`, and runs
`mix format`.

## What it generates

- `lib/my_app_web/components/layouts/app.ex` — `Layouts.App`, a drawer/sidebar
  shell with a sticky header (theme toggle, user avatar dropdown) and an
  `app_nav_items/0` list driving the sidebar links.
- `lib/my_app_web/components/layouts/session.ex` — `Layouts.Session`, a centered
  card with just a theme toggle, for login/registration/confirmation.
- `lib/my_app_web/components/layouts/public.ex` — `Layouts.Public`, a fixed
  top navbar with logo, nav links, and a log-in/avatar action area.
- `lib/my_app_web/controllers/page_html/home.html.heex` — a refreshed home page.
- Edits `lib/my_app_web/components/layouts.ex` — `app/1` now delegates to
  `Layouts.App.page/1`; adds shared `logo/1` and `user_avatar/1` components.
- Edits `lib/my_app_web/components/layouts/root.html.heex` — removes the inline
  menu so each layout owns its own chrome.
- Points the auth LiveViews (`user_live/login`, `registration`, `confirmation`)
  at `Layouts.Session.page`.

## Configuration

No config keys. Pick the layout per LiveView via the `:layout` option or by
wrapping the template in the matching `*.page` component.

## Tweaking for your app

Add sidebar links by editing `app_nav_items/0` in
`lib/my_app_web/components/layouts/app.ex`:

```elixir
# lib/my_app_web/components/layouts/app.ex
defp app_nav_items do
  [
    %{label: gettext("Dashboard"), icon: "hero-home", path: ~p"/"},
    %{label: gettext("Projects"), icon: "hero-folder", path: ~p"/projects"},
    %{label: gettext("Settings"), icon: "hero-cog-6-tooth", path: ~p"/users/settings"}
  ]
end
```

Wrap a LiveView in the right layout:

```elixir
# lib/my_app_web/live/dashboard_live.ex
def render(assigns) do
  ~H"""
  <Layouts.App.page flash={@flash} current_scope={@current_scope}>
    <div class="space-y-6">
      <!-- your content -->
    </div>
  </Layouts.App.page>
  """
end
```

Swap the placeholder brand — edit `logo/1` in
`lib/my_app_web/components/layouts.ex`:

```elixir
# lib/my_app_web/components/layouts.ex
def logo(assigns) do
  ~H"""
  <MyAppWeb.CoreComponents.icon name="hero-bolt" class="mr-3 size-6 sm:size-9 text-primary" />
  <span class="hidden sm:inline self-center text-xl font-semibold whitespace-nowrap text-base-content">
    MyApp
  </span>
  """
end
```

Edit the public navbar links in `lib/my_app_web/components/layouts/public.ex`:

```heex
<:link href="/" current={true}>{gettext("Home")}</:link>
<:link navigate={~p"/features"}>{gettext("Features")}</:link>
<:link navigate={~p"/pricing"}>{gettext("Pricing")}</:link>
```

The `user_avatar/1` component already falls back to a hero icon when
`current_user.image` is blank; set that field to render a real avatar.

### Add a new layout

When the app needs another distinct shell — e.g. an onboarding flow — follow the
**same pattern** as the three generated layouts: one module under
`lib/my_app_web/components/layouts/` exposing a `page/1` function component that
renders shared chrome around `{render_slot(@inner_block)}`.

```elixir
# lib/my_app_web/components/layouts/onboarding.ex
defmodule MyAppWeb.Layouts.Onboarding do
  use MyAppWeb, :html

  attr :flash, :map, default: %{}
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <main class="mx-auto max-w-xl px-4 py-12">
      <MyAppWeb.Layouts.logo />
      <ol class="steps my-8"><!-- progress chrome --></ol>
      {render_slot(@inner_block)}
      <.flash_group flash={@flash} />
    </main>
    """
  end
end
```

Then wrap the relevant LiveViews in it, exactly like `Layouts.App.page/1`:

```elixir
# lib/my_app_web/live/onboarding_live.ex
def render(assigns) do
  ~H"""
  <MyAppWeb.Layouts.Onboarding.page flash={@flash} current_scope={@current_scope}>
    <!-- step content -->
  </MyAppWeb.Layouts.Onboarding.page>
  """
end
```

Keep names consistent (`Layouts.Onboarding`, file `onboarding.ex`), reuse the
shared `logo/1` / `user_avatar/1` from `layouts.ex` rather than duplicating
brand markup, and add any nav via a `*_nav_items/0` helper like `Layouts.App`.

## After install

- [ ] Review the layouts at `lib/my_app_web/components/layouts/` (app, session, public).
- [ ] Update any existing LiveViews to use the appropriate layout.
- [ ] Replace the placeholder logo and brand name with your own.
- [ ] Customize navigation links and footer to match your IA.
- [ ] Verify mobile rendering on the navigation and theme toggle.
