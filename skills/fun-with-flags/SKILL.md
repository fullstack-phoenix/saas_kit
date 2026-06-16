---
name: fun-with-flags
description: Use when the app needs runtime feature toggles, gradual rollouts, or an emergency kill switch without redeploying. Covers installing FunWithFlags with Ecto + PubSub, the app-owned wrapper APIs, and per-user/per-team gating.
user-invocable: true
---

# Feature flags with FunWithFlags

Wires FunWithFlags into the app with the Ecto persistence adapter and Phoenix
PubSub cache notifications, so flags toggle at runtime without a deploy. Adds two
app-owned wrapper modules — `MyApp.Feature` for application code and
`MyAppWeb.FeatureFlags` for conns/sockets/assigns — plus a web admin UI for
managing flags. When `authentication` or `teams` are installed, it generates the
`FunWithFlags.Actor` implementations needed to gate flags per user and per team.

## When to use

- The app needs to turn features on/off at runtime without a deploy or restart.
- You want gradual rollouts (enable a flag for specific users or teams first).
- You need an emergency kill switch for a misbehaving feature.
- Don't reach for this for static, compile-time config — use `config/*.exs`
  instead. Flags add a DB table and runtime lookups.

## Dependencies

- Requires: None.
- Recommended: None. Install `authentication` first if you want per-user gating,
  and `teams` for per-team gating — the actor implementations are generated only
  when those features are present.

## Install

```bash
mix saaskit.feature.install fun_with_flags
```

No install decisions. Behavior adapts to what's already installed:

- With `admin`: mounts the flag UI at `/admin/feature-flags` behind
  `:require_authenticated_user` + `:require_admin_user`, and adds a link on the
  admin developer page. Without `admin`: mounts an unguarded UI at
  `/feature-flags`.
- With `authentication`: generates `lib/my_app/feature_actor/user.ex`.
- With `teams`: generates `lib/my_app/feature_actor/team.ex`.

## What it generates

- `lib/my_app/feature.ex` — `MyApp.Feature.enabled?/2`, the domain-level API.
  Resolves a `%{team:, user:}` scope and OR's the team and user gates.
- `lib/my_app_web/feature_flags.ex` — `MyAppWeb.FeatureFlags.enabled?/2`, accepts
  a conn, LiveView socket, or assigns map and forwards `:current_scope`.
- `lib/my_app/feature_actor/user.ex` — `FunWithFlags.Actor` impl for `User`
  (only with `authentication`).
- `lib/my_app/feature_actor/team.ex` — `FunWithFlags.Actor` impl for `Team`
  (only with `teams`).
- Migration `priv/repo/migrations/*_create_feature_flags_table.exs` — creates the
  `fun_with_flags_toggles` table with the configured primary-key type.
- Router scope mounting `FunWithFlags.UI.Router`.
- Adds `:fun_with_flags` and `:fun_with_flags_ui` to `mix.exs`.

## Configuration

Injected into `config/config.exs`:

```elixir
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: MyApp.Repo,
  ecto_primary_key_type: :id

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: MyApp.PubSub
```

- `ecto_primary_key_type` — `:binary_id` if the boilerplate uses UUID keys,
  otherwise `:id`. Must match the migration's primary key.
- `cache_bust_notifications` — keep `enabled: true` for multi-node deploys so a
  toggle on one node invalidates the cache on all of them.

## Tweaking for your app

Use the domain API in application code with a scope. A flag enabled for either the
team or the user counts as enabled:

```elixir
# lib/my_app/feature.ex is the source of truth for scope handling
if MyApp.Feature.enabled?(:beta_billing, current_scope) do
  run_new_billing()
end
```

Use the web wrapper in a controller or LiveView — pass the conn or socket and it
pulls `:current_scope` from assigns:

```elixir
# in a LiveView render/event handler
if MyAppWeb.FeatureFlags.enabled?(:new_dashboard, socket) do
  show_new_dashboard()
end
```

Gate markup in a template:

```heex
<%= if MyAppWeb.FeatureFlags.enabled?(:new_dashboard, @conn) do %>
  <.new_dashboard />
<% end %>
```

- **Gate a flag for a single actor:** flags accept any struct implementing
  `FunWithFlags.Actor`. Enable just one user from IEx:

  ```elixir
  FunWithFlags.enable(:beta_billing, for_actor: user)
  ```

- **Add a new actor type:** define a `FunWithFlags.Actor` impl returning a stable
  unique id, mirroring the generated user/team impls:

  ```elixir
  # lib/my_app/feature_actor/organization.ex
  defimpl FunWithFlags.Actor, for: MyApp.Teams.Team do
    def id(%{id: id}), do: "team:#{id}"
  end
  ```

- **Check without a scope:** call `MyApp.Feature.enabled?(:flag_name)` for a
  global boolean gate.

## After install

- [ ] `mix ecto.migrate` — create the `fun_with_flags_toggles` table.
- [ ] Visit `/admin/feature-flags` (with admin) or `/feature-flags` (without) to
  manage flags.
- [ ] Define your first flag in the UI and wrap conditional code with
  `MyApp.Feature.enabled?(:flag_name, current_scope)`.
- [ ] In a multi-node deploy, confirm PubSub cache invalidation works after
  toggling a flag.
