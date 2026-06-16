---
name: require-confirmed-user
description: Use when authenticated routes must be gated behind email confirmation, redirecting users whose `confirmed_at` is nil to a confirmation page. Covers install, configuration, and tweaks for the confirmation gate.
user-invocable: true
---

# Require Confirmed User

Adds an email-confirmation gate: any authenticated user whose `confirmed_at` is
nil is redirected to `/users/confirm` until they confirm their email. Ships a
confirmation-pending LiveView with a resend button that sends the magic-link
login (which confirms the account on click). OAuth sign-ins are auto-confirmed
and skip the gate, so in practice this guards edge cases (admin impersonation,
manually created users) and adds defense-in-depth.

## When to use

- The app needs to block unconfirmed users from authenticated pages until they
  verify their email.
- You want a ready-made "confirm your email" page with a resend button.
- Don't reach for this if every sign-in path already confirms the user (e.g.
  OAuth-only apps) — the gate would never fire.

## Dependencies

- Requires: None. But it patches `lib/my_app_web/user_auth.ex` and assumes
  `authentication` is installed (it edits the `require_authenticated_user`
  pipeline). Install `authentication` first.
- Recommended: None. Usually installed via the `authentication` installer's
  `email_confirmation` decision.

## Install

```bash
mix saaskit.feature.install require_confirmed_user
```

No decisions are asked. The installer injects the gate into the auth pipeline,
adds the `ensure_confirmed_user/1` helper, generates the confirmation-pending
LiveView, and registers the `/users/confirm` route.

## What it generates

- `lib/my_app_web/live/user_live/confirmation_pending.ex` — the
  `ConfirmationPending` LiveView. Redirects already-confirmed users to the
  signed-in path; otherwise shows a resend button.
- Patches `lib/my_app_web/user_auth.ex`:
  - Pipes `require_authenticated_user/2` through `ensure_confirmed_user/1`.
  - Adds the private `ensure_confirmed_user/1` that redirects to `~p"/users/confirm"`
    with a flash when `user.confirmed_at` is nil.
- Patches `lib/my_app_web/router.ex` — adds a `:require_confirmation`
  `live_session` (on_mount `:ensure_authenticated`) routing `/users/confirm` to
  `UserLive.ConfirmationPending`.

## Configuration

None. No config keys are added.

## Tweaking for your app

The resend button delivers the magic-link login. Swap the redirect URL or wording
in `lib/my_app_web/live/user_live/confirmation_pending.ex`:

```elixir
# lib/my_app_web/live/user_live/confirmation_pending.ex
def handle_event("resend", _params, socket) do
  user = socket.assigns.current_scope.user

  Users.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

  socket
  |> put_flash(:info, gettext("Confirmation email sent. Check your inbox."))
  |> assign(:sent?, true)
  |> then(&{:noreply, &1})
end
```

Change where unconfirmed users land, or skip the gate for some users, by editing
the helper in `lib/my_app_web/user_auth.ex`:

```elixir
# lib/my_app_web/user_auth.ex
defp ensure_confirmed_user(conn) do
  user = conn.assigns.current_scope && conn.assigns.current_scope.user

  if user && is_nil(user.confirmed_at) do
    conn
    |> put_flash(:error, "You must confirm your email to access this page.")
    |> redirect(to: ~p"/users/confirm")
    |> halt()
  else
    conn
  end
end
```

- **Exempt admins:** add `&& user.role == :user` (or similar) to the condition so
  privileged accounts skip the gate.
- **Customize the page:** the heading, copy, and styling live in the LiveView's
  `render/1` (`gettext("Confirm your email")`, etc.).
- **Disable in production:** remove the `|> ensure_confirmed_user()` line from
  `require_authenticated_user/2` to turn the gate off entirely.

## After install

- [ ] Sign in as an unconfirmed user; confirm you are redirected to `/users/confirm`.
- [ ] Click "Resend confirmation email" and follow the magic link to confirm the account.
- [ ] Decide whether to keep the confirmation gate enabled in production.
