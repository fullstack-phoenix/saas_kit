---
name: admin
description: Use when the app needs an admin-only dashboard at `/admin` for managing users, teams, and admins, with charts, impersonation, and the LiveDashboard. Covers install, configuration, and tweaks.
user-invocable: true
---

# Admin Pages

Generates a LiveView admin area mounted at `/admin`, accessible only to users
with role `:admin` or `:superuser`. It ships a dashboard with charts, user and
team management (with Flop-powered filtering and pagination), an admins manager,
user impersonation, and a developer area exposing the LiveDashboard and Oban
dashboard.

## When to use

- The app needs a back-office for staff to manage users and teams.
- You want support tooling out of the box — impersonate a user, browse paginated
  records, monitor background jobs.
- Don't reach for this if a single superuser editing the database directly is
  enough — the admin UI adds Flop and several LiveViews.

## Dependencies

- Requires: `authentication`, `layouts`, `teams`.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install admin
```

No install decisions. The installer adds `flop` and `flop_phoenix` to `mix.exs`,
generates the admin LiveViews and components, wires the `/admin` routes and
pipeline, and runs `mix format`.

## What it generates

- `lib/my_app_web/admin_auth.ex` — `require_admin_user/2` plug and the
  `:require_admin_user` `on_mount` hook; both gate on `role in [:admin, :superuser]`.
- `lib/my_app/admins.ex` — `Admins` context (`paginate_admins/2`, `create_admin/1`,
  `delete_admin/1`) that promotes/demotes users by role.
- `lib/my_app_web/components/{admin,charts,tables}.ex` — admin UI components,
  imported into `html_helpers` in `my_app_web.ex`.
- `lib/my_app_web/components/layouts/admin.ex` — admin layout with the sidebar
  `nav_items/0`.
- `lib/my_app_web/live/admin/` — `DashboardLive`, `UserLive`, `TeamLive`,
  `AdminLive`, `DeveloperLive`, `SettingLive`.
- `lib/my_app_web/controllers/admin/user_impersonation_controller.ex` — sets an
  impersonation session and signs in as the target user.
- `assets/js/hooks/chart.js` plus `LineChart`/`BarChart`/`PieChart` hook wiring.
- Adds Flop `@derive` schemas and `paginate_*` functions to `users.ex`,
  `teams.ex`, and their schemas; admin route block in `router.ex`; admin link in
  the `app` and `public` layouts (shown only to admins).
- Tests under `test/my_app_web/live/admin/` and `test/my_app/admins_test.exs`,
  plus a `register_and_log_in_admin` helper and `admin_fixture/1`.

## Configuration

Injected into `config/config.exs` so Flop knows which repo to query:

```elixir
# config/config.exs
config :flop, repo: MyApp.Repo
```

The admin routes are added to `lib/my_app_web/router.ex` behind the
`:require_admin_user` pipeline:

```elixir
scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :require_authenticated_user, :require_admin_user]

  live_session :admin,
    on_mount: [
      {MyAppWeb.UserAuth, :mount_current_scope},
      {MyAppWeb.AdminAuth, :require_admin_user}
    ] do
    live "/", DashboardLive.Index, :index
    # users, teams, admins, developers, settings ...
  end
end
```

Note: this moves `live_dashboard` from the dev-only block into the admin scope —
it is now admin-gated rather than `Mix.env() == :dev`.

## Tweaking for your app

Add a sidebar item by extending `nav_items/0` in
`lib/my_app_web/components/layouts/admin.ex`:

```elixir
# lib/my_app_web/components/layouts/admin.ex
defp nav_items do
  [
    %{label: gettext("Admin"), icon: "hero-presentation-chart-line", path: ~p"/admin"},
    %{label: gettext("Users"), icon: "hero-user", path: ~p"/admin/users"},
    %{label: gettext("Reports"), icon: "hero-chart-bar", path: ~p"/admin/reports"}
    ## Insert admin nav items below ##
  ]
end
```

Add filterable/sortable columns to an admin table by editing the `Flop.Schema`
`@derive` on the schema. For example, to filter teams by `inserted_at`:

```elixir
# lib/my_app/teams/team.ex
@derive {
  Flop.Schema,
  default_limit: 20,
  filterable: [:search_phrase, :name, :inserted_at],
  sortable: [:name, :inserted_at],
  compound_fields: [search_phrase: [:name]]
}
```

Gate any LiveView behind admin access with the generated hook:

```elixir
defmodule MyAppWeb.Admin.ReportLive.Index do
  use MyAppWeb, :live_view

  on_mount {MyAppWeb.AdminAuth, :require_admin_user}
end
```

- **Change who is an admin:** `require_admin_user/2` and the `on_mount` hook in
  `admin_auth.ex` check `role in [:admin, :superuser]`. Edit that guard to add or
  narrow roles.
- **Impersonation:** `UserImpersonationController.create/2` stores
  `impersonating: true` in the session and swaps the session token. Add an
  "exit impersonation" action by clearing that session key and restoring the
  admin's own token.
- **Disable the developer area:** remove the `DeveloperLive` and
  `live_dashboard` routes from the admin scope in `router.ex`.

## After install

- [ ] `mix ecto.migrate` if any pending migrations exist.
- [ ] Promote a user to `:admin` or `:superuser` (or sign up first — with
      `authentication` installed the first user is auto-promoted).
- [ ] Visit `/admin` to confirm the dashboard loads.
- [ ] Visit `/admin/dev` (the developer area) for LiveDashboard and Oban.
- [ ] Customize the sidebar in `lib/my_app_web/components/layouts/admin.ex`.

## Read next

- For the role system and admin bootstrapping, see the `authentication` skill.
- For the team schema the admin manages, see the `teams` skill.
