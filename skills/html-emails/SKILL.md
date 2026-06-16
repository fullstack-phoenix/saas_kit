---
name: html-emails
description: Use when emails need to render reliably across clients. Covers installing Premailex-based HTML email layouts with inline CSS and plain-text fallbacks, plus how to wire and tweak notifiers.
user-invocable: true
---

# HTML Emails

Adds a Swoosh-based HTML email pipeline backed by Premailex. Emails are written
as HEEx templates wrapped in a shared layout, then `premail/1` inlines the CSS
and generates a plain-text alternative. This improves deliverability and
consistent rendering in Gmail, Outlook, and Apple Mail. When `authentication`
or `teams` are present, it also swaps their notifiers over to the HTML pipeline.

## When to use

- The app sends transactional email (confirmations, magic links, invites) and
  you want client-safe HTML with inline styles.
- You need a plain-text fallback generated automatically for every email.
- Don't reach for this if the app only sends raw text emails and rendering /
  deliverability isn't a concern — plain Swoosh is enough then.

## Dependencies

- Requires: None.
- Recommended: None. Pairs naturally with `authentication` (user notifier) and
  `teams` (invitation notifier) — if either is installed, this feature upgrades
  their email templates automatically.

## Install

```bash
mix saaskit.feature.install html_emails
```

No install decisions. The installer adds the `premailex` dep, the mailer
helpers, the `EmailHTML` view, and the HTML/text layouts. Conditional
templates are generated only when their feature is present: user notifier +
auth email templates when `authentication` is installed, invitation notifier +
invite template when `teams` is installed.

## What it generates

- `mix.exs` — injects `{:premailex, "~> 0.3.20"}` into `deps`.
- `lib/my_app/mailer.ex` — Swoosh mailer with `base_email/0`, `render_body/3`
  (renders a HEEx template inside the layout), `apply_layout/1`, and `premail/1`
  (inline CSS + plain-text body).
- `lib/my_app_web/emails.ex` — `MyAppWeb.EmailHTML`, embeds all templates under
  `emails/*.html` and `emails/*.text`.
- `lib/my_app_web/emails/layout.html.heex` + `layout.text.heex` — shared HTML
  and text layouts (reset CSS, preheader, footer).
- When `authentication` is installed: `lib/my_app/users/user_notifier.ex` plus
  `user_confirmation_instructions`, `user_magic_link_instructions`, and
  `user_update_email_instructions` HEEx templates.
- When `teams` is installed: `lib/my_app/teams/invitation_notifier.ex` plus
  `emails/invite_user.html.heex`.

## Configuration

The sender address is read from app config, with a fallback baked into the
mailer:

```elixir
# config/config.exs
config :my_app, from_email: {"MyApp", "contact@example.com"}
```

Set this to your real product name and verified sending address before sending
in production.

## Tweaking for your app

Write a new email by adding a HEEx template under `lib/my_app_web/emails/` and
delivering it from a notifier. The notifier pattern is `base_email` →
`render_body` → `premail` → deliver:

```elixir
# lib/my_app/users/user_notifier.ex
def deliver_welcome(user) do
  base_email()
  |> to(user.email)
  |> subject(gettext("Welcome to MyApp"))
  |> render_body("welcome.html", user: user)
  |> premail()
  |> do_deliver()
end
```

The template uses the shared layout automatically — just write the body:

```heex
<!-- lib/my_app_web/emails/welcome.html.heex -->
<h2>{gettext("Hi %{email}", email: @user.email)}</h2>

<p>{gettext("Thanks for signing up.")}</p>

<p>
  <.link href={~p"/dashboard"}>{gettext("Go to your dashboard")}</.link>
</p>
```

- **Brand the layout:** edit `lib/my_app_web/emails/layout.html.heex` — the
  `<style>` block, the footer link, and the copyright line all live there.
- **Set a preheader:** pass `preheader:` through to `render_body` assigns; the
  layout renders it hidden as inbox preview text.
- **Skip the layout but still premail:** build `html_body` yourself, then call
  `apply_layout/1` and `premail/1`.

## After install

- [ ] `mix deps.get` — fetch `premailex`.
- [ ] Convert existing mailer templates to the new HTML layout.
- [ ] Send a test email to Gmail, Outlook, and Apple Mail — confirm rendering.
- [ ] Confirm the plain-text alternative is present (check raw email source).
- [ ] Verify spam score with mail-tester.com or similar.
