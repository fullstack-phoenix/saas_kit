---
name: locale-picker
description: Use when the app needs to let users switch UI language at runtime. Covers installing the Gettext-backed locale picker dropdown, its router/LiveView wiring, and how to add locales.
user-invocable: true
---

# Locale Picker

Adds a runtime language switcher. Generates a `MyAppWeb.Locale` plug + LiveView
`on_mount` hook that resolves the active locale (query param → cookie/session →
current user → default), a `LocalePickerLive` dropdown rendered through a portal,
and a JS hook to redirect on selection. Locale choice persists in a cookie and
flows into Gettext for every request and LiveView.

## When to use

- The app ships UI in more than one language and users should pick their own.
- You already use (or are willing to use) Gettext for translations.
- Don't reach for this for a single-language app, or when locale is fixed per
  tenant and never user-selectable — a static `Gettext.put_locale/2` is enough.

## Dependencies

- Requires: None.
- Recommended: None. The `layouts` boilerplate option lets the installer drop the
  picker into the generated `app`, `public`, and `session` layouts automatically.

## Install

```bash
mix saaskit.feature.install locale_picker
```

No interactive decisions. Layout injection (instructions `g`–`i`) only runs when
the boilerplate was generated with the `layouts` option; otherwise mount the
picker target yourself (see Tweaking). The install also runs `mix gettext.extract`.

## What it generates

- `lib/my_app_web/locale.ex` — the `MyAppWeb.Locale` module: `set_locale/2` plug,
  `on_mount(:set_locale, ...)`, plus `known_locales/0` and `current_locale/0`.
- `lib/my_app_web/live/locale_picker_live.ex` — `LocalePickerLive`, the dropdown
  rendered via `<.portal target="#locale-target">`.
- `assets/js/hooks/locale_picker.js` — `LocalePicker` hook (registered in
  `assets/js/hooks/index.js`) that reports the current URL and handles redirects.
- `test/my_app_web/live/locale_picker_live_test.exs` — LiveView tests.
- Router wiring: imports `set_locale/2`, adds `plug :set_locale` to the browser
  pipeline, and prepends `{MyAppWeb.Locale, :set_locale}` to the LiveView
  `on_mount` list.
- Mounts `live_render(@conn, MyAppWeb.LocalePickerLive, ...)` at the end of
  `root.html.heex` and adds `<div id="locale-target">` to the layouts.

## Configuration

Injected into `config/config.exs`:

```elixir
# config/config.exs
config :my_app, MyAppWeb.Gettext,
  locales: ~w(en),
  default_locale: "en"
```

- `locales` — every locale the app accepts. The picker only offers, and
  `set_locale` only honors, locales in this list (`known_locales/0`). Add each
  language code you translate.
- `default_locale` — fallback when no valid locale is resolved.

## Tweaking for your app

The generated dropdown ships with a hardcoded label map. Edit `possible_locales/0`
in `lib/my_app_web/live/locale_picker_live.ex` to match your `Gettext` `locales`:

```elixir
# lib/my_app_web/live/locale_picker_live.ex
defp possible_locales do
  %{"en" => "English (US)", "sv" => "Svenska", "es" => "Español"}
end
```

If the boilerplate had no `layouts` (the picker target wasn't injected), add the
target where you want the dropdown and mount the LiveView once in the root layout:

```heex
<!-- lib/my_app_web/components/layouts/app.ex (header) -->
<div id="locale-target"></div>
```

```heex
<!-- lib/my_app_web/components/layouts/root.html.heex (before </body>) -->
{live_render(@conn, MyAppWeb.LocalePickerLive,
  id: "locale-picker",
  session: %{"locale" => MyAppWeb.Locale.current_locale()}
)}
```

Persist the choice on the user instead of just a cookie: `set_locale/2` already
reads `current_scope.user.locale` (see `scope_locale/1`), so write the chosen
locale to the `User.locale` field on selection and it becomes the logged-in
default across devices.

## After install

- [ ] Add available locales in `config/config.exs`: `config :my_app, MyAppWeb.Gettext, locales: ~w(en sv ...)`.
- [ ] Extract and merge strings: `mix gettext.extract && mix gettext.merge priv/gettext`.
- [ ] Add the locale picker component to your layout (header dropdown is the conventional spot).
- [ ] Persist the user's choice (on the `User` schema or in a cookie/session).
