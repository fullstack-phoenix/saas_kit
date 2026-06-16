---
name: authentication
description: Use when the app needs user accounts, sign-in, and roles. Covers installing phx.gen.auth-based auth with role-based access, profiles, and admin bootstrapping, plus how to tweak it.
user-invocable: true
---

# User Authentication

Generates a complete authentication system on top of Phoenix's `mix phx.gen.auth`,
then extends the `User` schema with role-based access control (`:user`, `:admin`,
`:superuser`), profile fields (name, locale, timezone), an embedded `data` field,
and soft-delete/anonymization. This is the `core` foundation most other features
build on.

## When to use

- The app needs users who can register, log in, and be authorized by role.
- You want admin/superuser bootstrapping out of the box (first signup becomes
  superuser; listed emails become admins).
- Don't reach for this if the app is single-tenant with no login — and install
  it **before** `teams`, `oauth`, `payments`, or anything that references users.

## Dependencies

- Requires: None (this is a `core` feature, `position` 4 — install early).
- Recommended: None. Pair with `require_confirmed_user` via the install decision
  below if you want email confirmation gating.

## Install

```bash
mix saaskit.feature.install authentication
```

The installer runs `mix phx.gen.auth Users User users --live`, then injects the
extra fields, changesets, and config. It asks one decision:

- **Require email confirmation?** (`email_confirmation`) — when yes, installs the
  `require_confirmed_user` feature, which redirects authenticated-but-unconfirmed
  users to `/users/confirm`. OAuth sign-ins are auto-confirmed and skip the gate.

```bash
mix saaskit.feature.install authentication --decision email_confirmation=require_confirmed_user
```

## What it generates

- `mix phx.gen.auth Users User users --live` scaffolding — users table, auth
  logic, and LiveView sign-in/registration components.
- Migration `priv/repo/migrations/*_add_additional_fields_to_users.exs` — adds
  `deleted_at`, `role`, name fields, `locale`, `timezone`, and embedded `data`.
- Extends `lib/my_app/users/user.ex`:
  - `role` enum (`:user`, `:admin`, `:superuser`), profile fields, `embeds_one :data`.
  - `maybe_set_admin_role/1` — auto-assigns roles from config.
  - `update_changeset/2` (profile-only, never email/password), `data_changeset/2`,
    `anonymize_changeset/1`.
- Extends `lib/my_app/users.ex` with `update_user/2`, `change_user/2`,
  `anonymize_user/1`.
- Adds tests in `test/my_app/users_test.exs`.

## Configuration

Injected into `config/config.exs`:

```elixir
config :my_app, :admin,
  first_user_superuser: true,
  admin_emails: []
```

And `config/test.exs` gets `first_user_superuser: false` so tests don't depend on
insertion order.

- `first_user_superuser` — first user to sign up becomes `:superuser`. For
  production after launch, set this to `false`.
- `admin_emails` — any user signing up with a listed email becomes `:admin`.

## Tweaking for your app

Update a profile without touching auth credentials:

```elixir
{:ok, user} =
  MyApp.Users.update_user(user, %{
    name: "John Doe",
    locale: "en",
    timezone: "America/New_York"
  })
```

Gate a controller action by role:

```elixir
defp require_admin(conn, _opts) do
  if conn.assigns.current_user.role in [:admin, :superuser] do
    conn
  else
    conn |> put_flash(:error, "Not authorized") |> redirect(to: "/") |> halt()
  end
end
```

- **Add profile fields:** add the field to the migration and the `embeds_one :data`
  block (or the schema), then to `@additional_attributes` in `update_changeset/2`.
- **Add a role:** extend the `Ecto.Enum` values list on the `role` field and
  adjust `maybe_set_admin_role/1`.
- **Soft delete:** call `Users.anonymize_user(user_id)` — it sets `deleted_at` and
  scrubs PII. Filter anonymized users in `get_user!/1` if you want them hidden.

## After install

- [ ] `mix ecto.migrate` — create the users table.
- [ ] Edit `config/config.exs`, add admin emails to `config :my_app, :admin, admin_emails: []`.
- [ ] Sign up a user — the first one becomes superuser automatically.
- [ ] Review the auth pipeline in `lib/my_app_web/router.ex`.
- [ ] In production, decide whether to keep `first_user_superuser: true`.

## Read next

- For the email-confirmation gate, see the [require-confirmed-user](require-confirmed-user/SKILL.md) sub-skill.
- To add social login on top, see the `oauth` skill.
