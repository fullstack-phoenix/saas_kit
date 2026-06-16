---
name: two-factor-auth
description: Use when the app needs TOTP two-factor authentication via authenticator apps (Google Authenticator, Authy, 1Password). Covers install, enforcement config, and tweaking the setup/verify flow.
user-invocable: true
---

# Two Factor Authentication

Adds TOTP-based two-factor authentication on top of an existing auth system. Uses
`nimble_totp` for code generation/verification and `eqrcode` for the QR code shown
during enrollment. Extends the `User` schema with a `has_two_factor_auth_setup`
flag, manages authenticator secrets through `UserToken`, and adds a setup/verify
LiveView plus a router gate that can force every user to enroll.

## When to use

- The app handles money or sensitive data and needs a second login factor.
- You want enrollment, QR display, and TOTP verification with ready-made UI.
- You need app-wide enforcement (require every user to enroll) or per-user opt-in.
- Don't reach for this if email confirmation alone is enough — that's
  `require_confirmed_user`.

## Dependencies

- Requires: None — but it injects into the auth schema, `UserToken`, and
  `UserAuth`, so install **authentication** first.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install two_factor_auth
```

Pulls in `{:eqrcode, "~> 0.2.1"}` and `{:nimble_totp, "~> 1.0.0"}`, generates the
2FA controller and LiveView, injects the schema field, the `Users` context
functions, the `UserToken` helpers, the router scope, and the `UserAuth` gate.
No installer decisions — enforcement is a config flag (see Configuration).

## What it generates

- `lib/my_app_web/live/user_two_factor_live.ex` — setup/verify LiveView. Shows a
  QR code on first enrollment, accepts a 6-digit code, sets `has_two_factor_auth_setup`.
- `lib/my_app_web/controllers/user_two_factor_controller.ex` — verifies the signed
  `"2fa_confirmed"` token and writes `:confirmed_2fa_setup` into the session.
- Extends `lib/my_app/users.ex` — `generate_user_authenticator_token/1`,
  `get_authenticator_token_for_user/1`, `delete_user_authenticator_token/1`,
  `generate_timebased_challenge/1`, `generate_authenticator_url/1`,
  `verify_timebased_challenge/2`.
- Extends `lib/my_app/users/user_token.ex` — `build_authenticator_token/1` (a
  `"authenticator"`-context token holding the TOTP secret) and
  `find_authenticator_token_query/1`.
- Extends `lib/my_app/users/user.ex` — adds `field :has_two_factor_auth_setup`
  and includes it in `@additional_attributes`.
- Extends `lib/my_app_web/user_auth.ex` — adds the `ensure_2fa_setup/1` gate into
  `require_authenticated_user/2`.
- Extends `lib/my_app_web/router.ex` — `/users/two_factor` (LiveView) and
  `/users/two_factor/:token` (controller confirm).
- Adds tests in `test/my_app/users_test.exs` and
  `test/my_app_web/controllers/user_two_factor_controller_test.exs`.

## Configuration

Injected into `config/config.exs`:

```elixir
# config/config.exs
config :my_app, require_2fa_setup: true
```

And `config/test.exs` gets `require_2fa_setup: false` so tests don't get gated.

- `require_2fa_setup: true` — every authenticated user is redirected to
  `/users/two_factor` until they enroll. Recommended for sensitive apps.
- `require_2fa_setup: false` — enrollment is optional; the gate is skipped.

The QR/issuer label comes from `config :my_app, :app_name, "MyApp"` (read by
`generate_authenticator_url/1`); set it so authenticator apps show your name.

## Tweaking for your app

Make 2FA optional instead of forced — flip the config and trigger enrollment from
your own UI by linking to the LiveView:

```elixir
# config/config.exs
config :my_app, require_2fa_setup: false
```

```heex
<.link navigate={~p"/users/two_factor"}>Enable two-factor auth</.link>
```

Verify a code yourself (e.g. in a custom flow or an SMS challenge):

```elixir
# generate + send, then verify a submitted code
challenge = MyApp.Users.generate_timebased_challenge(user)
true = MyApp.Users.verify_timebased_challenge(user, challenge)
```

Let a user reset 2FA (clears the secret; they re-enroll on next login):

```elixir
# lib/my_app/users.ex helper, callable from an admin or settings action
:ok = MyApp.Users.delete_user_authenticator_token(user)
{:ok, _user} = MyApp.Users.update_user(user, %{data: %{has_two_factor_auth_setup: false}})
```

Shorten how long the post-verify session stays trusted by tightening the token
`max_age` (seconds) in `user_two_factor_controller.ex`:

```elixir
# lib/my_app_web/controllers/user_two_factor_controller.ex
Phoenix.Token.verify(MyAppWeb.Endpoint, "2fa_confirmed", token, max_age: 120)
```

## After install

- [ ] `mix ecto.migrate` — apply the `user_token` / 2FA changes.
- [ ] Decide enforcement: `config :my_app, require_2fa_setup: true` or `false`.
- [ ] Test enrollment end-to-end with a real authenticator app.
- [ ] Test login with a wrong TOTP code to confirm verification fails.
- [ ] Document the 2FA flow and account-recovery path for end users.
