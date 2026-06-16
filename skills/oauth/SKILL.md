---
name: oauth
description: Use when the app needs social sign-in (GitHub OAuth) on top of existing authentication. Covers installing Ueberauth, the user-identity linking flow, configuration, and how to add more providers.
user-invocable: true
---

# OAuth Login

Adds GitHub OAuth sign-in on top of the existing `authentication` feature. Built on
Ueberauth, it generates a `UserIdentity` schema that links OAuth accounts to your
users by email, an `OauthCallbackController` that handles the full request/callback
flow, and "Sign in with Github" buttons on the login and registration pages. New
OAuth users are auto-created and confirmed; existing users are matched and linked by
email.

## When to use

- The app already has email/password auth and you want to add "Sign in with GitHub".
- You want OAuth users automatically linked to existing accounts by email, with no
  separate account silo.
- Don't reach for this if you have no users yet — install `authentication` first.
  Don't use it as your only auth: it extends the password flow, not replaces it.

## Dependencies

- Requires: `authentication` (the `User` schema, `Users` context, and login/registration
  LiveViews must already exist).
- Recommended: None.

## Install

```bash
mix saaskit.feature.install oauth
```

No interactive decisions. The installer adds `ueberauth` and `ueberauth_github` to
`mix.exs`, injects Ueberauth config, mounts the `/auth` routes, generates the
user-identity context and controller, and adds the sign-in buttons.

## What it generates

- `lib/my_app/user_identities.ex` — context. `find_or_create_user/1` resolves the four
  identity/user scenarios (register, log in, link, re-link) and returns `{:ok, user}`
  or `{:just_created, user}`. Also CRUD: `list_user_identities/1`, `create_user_identity/2`.
- `lib/my_app/user_identities/user_identity.ex` — schema for the `user_identities`
  table (`provider`, `uid`, `belongs_to :user`).
- `lib/my_app_web/controllers/oauth_callback_controller.ex` — handles
  `GET /auth/:provider` and `GET /auth/:provider/callback`, logs the user in via
  `UserAuth.log_in_user/2`.
- `lib/my_app/ecto_helpers/stringable.ex` — Ecto type for the `provider`/`uid` fields.
- Migration `priv/repo/migrations/*_create_user_identities.exs` — `user_identities`
  table with a unique index on `(uid, provider)`.
- Injects `Users.confirm_user/1` into `lib/my_app/users.ex` (used to auto-confirm
  verified OAuth sign-ins).
- Adds the `/auth` scope to `lib/my_app_web/router.ex` and "Sign in with Github"
  buttons to the login and registration LiveViews.
- Tests + fixtures: `test/my_app/user_identities_test.exs`,
  `test/support/fixtures/user_identities_fixtures.ex`.

## Configuration

Injected into `config/config.exs`:

```elixir
# config/config.exs
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")
```

Set the credentials in your `.env` (and in production env separately):

```bash
# .env — used for Ueberauth OAuth with GitHub
export GITHUB_CLIENT_ID=
export GITHUB_CLIENT_SECRET=
```

`default_scope: "user:email"` requests the user's email — required, because the whole
linking flow keys on email. Don't remove it.

## Tweaking for your app

Add another provider — add the dep in `mix.exs`, add it to the `providers` list, and
configure its OAuth keys. The generated controller and `find_or_create_user/1` already
work for any Ueberauth provider that returns a verified email:

```elixir
# config/config.exs
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]},
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
```

The registration LiveView ships with a disabled "Sign in with Google" placeholder —
wire its `href` to the new provider once configured:

```heex
<.link
  href={~p"/auth/google"}
  class="btn bg-white text-black border-[#e5e5e5] w-full"
>
  {gettext("Sign in with Google")}
</.link>
```

Read a user's linked identities — list them, or find a specific provider:

```elixir
identities = MyApp.UserIdentities.list_user_identities(user)
github = Enum.find(identities, &(&1.provider == "github"))
```

Disallow auto-registration (only let existing users link a provider) — replace the
`{false, false}` branch of `find_or_create_user/1` in
`lib/my_app/user_identities.ex` with an error tuple instead of
`create_user_from_user_identity/1`.

## After install

- [ ] Create a GitHub OAuth app at https://github.com/settings/developers.
- [ ] Set `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` in your `.env`.
- [ ] Set the GitHub callback URL to `https://<your-domain>/auth/github/callback`
      (and `http://localhost:4000/auth/github/callback` for dev).
- [ ] `mix ecto.migrate` — create the `user_identities` table.
- [ ] Sign in via GitHub end-to-end in dev to confirm the flow works.
- [ ] Configure the same secrets in your production environment.
