---
name: error-tracker
description: Use when the app needs database-backed error tracking without an external SaaS. Covers installing ErrorTracker with automatic Phoenix/LiveView/Oban reporting, migrations, pruning, and a dashboard.
user-invocable: true
---

# ErrorTracker

Adds [ErrorTracker](https://hex.pm/packages/error_tracker), an Elixir-native error
tracking solution, to a Phoenix app. It stores exceptions in your existing
database and serves a LiveView dashboard for reviewing, resolving, muting, and
inspecting occurrences — no external service or hosted account required. Phoenix
controllers, LiveViews, and Oban jobs report automatically.

## When to use

- The app needs to capture and review production exceptions but you don't want
  Sentry/AppSignal or another hosted error service.
- You want stack traces, occurrences, breadcrumbs, and context stored alongside
  your own data in your existing repo.
- Don't reach for this if you already pipe errors to a hosted tracker — running
  both duplicates noise. For a no-dashboard setup, plain `Logger` may suffice.

## Dependencies

- Requires: None.
- Recommended: `admin` (mounts the dashboard under `/admin/errors` and links it
  from the developer page), `oban` (adds job metadata to error context).

## Install

```bash
mix saaskit.feature.install error_tracker
```

No install decisions. The mount point is chosen automatically:

- With the `admin` feature installed → dashboard at `/admin/errors`, linked from
  the admin developer page.
- Without `admin` → dashboard mounted beside the development LiveDashboard route.

## What it generates

- Adds `{:error_tracker, "~> 0.9.0"}` to `mix.exs` deps.
- Config block in `config/config.exs` (see Configuration).
- Migration `priv/repo/migrations/*_add_error_tracker.exs` — delegates to
  `ErrorTracker.Migration.up/0` to create the error tracker tables.
- `lib/my_app_web/router.ex` — injects `use ErrorTracker.Web, :router` and the
  `error_tracker_dashboard "/errors"` route at the appropriate mount point.

## Configuration

Injected at the top of `config/config.exs`:

```elixir
# config/config.exs
config :error_tracker,
  otp_app: :my_app,
  repo: MyApp.Repo,
  enabled: Mix.env() != :test,
  plugins: [ErrorTracker.Plugins.Pruner]
```

- `enabled` — on everywhere except `:test`. Reporting is off during tests so
  expected failures don't pollute the dashboard.
- `repo` — uses your existing `MyApp.Repo` for storage; no separate database.
- `plugins: [ErrorTracker.Plugins.Pruner]` — runs with defaults to clean up
  resolved errors over time. Tune retention by passing options to the plugin.

## Tweaking for your app

Report an error manually from a `rescue`/`catch` block with extra context:

```elixir
try do
  perform_risky_operation()
catch
  error ->
    ErrorTracker.report(error, __STACKTRACE__, %{operation: "risky_operation"})
end
```

Configure pruning retention instead of using the defaults:

```elixir
# config/config.exs
config :error_tracker,
  otp_app: :my_app,
  repo: MyApp.Repo,
  enabled: Mix.env() != :test,
  plugins: [
    {ErrorTracker.Plugins.Pruner, max_age: :timer.hours(24 * 30)}
  ]
```

Restrict who can open the dashboard by guarding the route in a pipeline that
checks the current user's role:

```elixir
# lib/my_app_web/router.ex
scope "/admin" do
  pipe_through [:browser, :require_admin]
  error_tracker_dashboard "/errors"
end
```

## After install

- [ ] `mix ecto.migrate` — create the error_tracker tables.
- [ ] Visit `/admin/errors` (or `/dev/errors` if no admin feature) to confirm the dashboard loads.
- [ ] Trigger a fake error in dev to verify reporting works end-to-end.
- [ ] Decide on a notification channel for new errors (Slack webhook, email digest, etc.).
