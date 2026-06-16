---
name: stripe-subscription
description: Use when the app needs recurring billing via Stripe-hosted Checkout. Covers installing the `MyApp.Billing` Stripe provider, its config, and how to wire checkout and webhooks.
user-invocable: true
---

# Stripe Subscription

Adds a `MyApp.Billing.StripeSubscription` provider that creates Stripe-hosted
Checkout sessions for recurring subscriptions over `Req`. It only mints checkout
URLs — it does not record subscription state. Treat a redirect to `success_url`
as "checkout started", not "paid": grant access from verified Stripe webhooks.

## When to use

- The app needs recurring (subscription) billing and you want Stripe to host the
  payment page rather than building a card form.
- You want a thin billing facade (`MyApp.Billing`) you can swap providers behind.
- Don't reach for this if you need one-time payments only, or if you already have
  a webhook-backed billing flow — this is a starting point, not a complete system.

## Dependencies

- Requires: `authentication` (sessions are created from a user's email).
- Recommended: None.

## Install

```bash
mix saaskit.feature.install stripe_subscription
```

No installer decisions. It generates the provider module and injects billing
config into `config/runtime.exs`.

## What it generates

- `lib/my_app/billing/stripe_subscription.ex` — the provider. Implements the
  `MyApp.Billing` behaviour with `create_checkout_session/2`, POSTs to Stripe's
  `/v1/checkout/sessions` in `mode=subscription`, and returns `{:ok, url}` or
  `{:error, reason}`.

## Configuration

Injected after `import Config` in `config/runtime.exs`:

```elixir
# config/runtime.exs
config :my_app, :billing,
  provider: MyApp.Billing.StripeSubscription

config :my_app, MyApp.Billing.StripeSubscription,
  secret_key: System.get_env("STRIPE_SECRET_KEY"),
  price_id: System.get_env("STRIPE_SUBSCRIPTION_PRICE_ID")
```

- `STRIPE_SECRET_KEY` — your Stripe API secret. Keep it out of source control.
- `STRIPE_SUBSCRIPTION_PRICE_ID` — the ID of a **recurring** Price created in
  Stripe. The provider errors with `{:missing_configuration, key}` if either is
  blank, so set both before calling checkout.

## Tweaking for your app

Create a session and redirect the user to Stripe:

```elixir
# lib/my_app_web/controllers/checkout_controller.ex
def create(conn, _params) do
  user = conn.assigns.current_user

  case MyApp.Billing.StripeSubscription.create_checkout_session(
         %{email: user.email},
         success_url: url(~p"/billing/success"),
         cancel_url: url(~p"/billing/cancel")
       ) do
    {:ok, checkout_url} -> redirect(conn, external: checkout_url)
    {:error, _reason} -> conn |> put_flash(:error, "Could not start checkout") |> redirect(to: ~p"/")
  end
end
```

- **Add line items / metadata:** destructure the user id in the function head
  and extend the `form:` list in `create_checkout_session/2`, so the webhook can
  resolve the user later via `client_reference_id`:

  ```elixir
  # lib/my_app/billing/stripe_subscription.ex
  def create_checkout_session(%{email: email, user_id: user_id}, opts) when is_list(opts) do
    # ...
    form: [
      {"mode", "subscription"},
      {"success_url", success_url},
      {"cancel_url", cancel_url},
      {"customer_email", email},
      {"client_reference_id", to_string(user_id)},
      {"line_items[0][price]", price_id},
      {"line_items[0][quantity]", "1"}
    ]
  end
  ```

  Then pass it from the controller: `%{email: user.email, user_id: user.id}`.

- **Swap the provider:** point `config :my_app, :billing, provider:` at another
  module implementing the same behaviour; calling code stays the same.
- **Record access on payment:** this module does NOT grant access. Add a verified
  webhook endpoint that listens for `checkout.session.completed` /
  `customer.subscription.*` and updates your user/subscription state there.

## After install

- [ ] Create a recurring Price in Stripe and set `STRIPE_SUBSCRIPTION_PRICE_ID`.
- [ ] Set `STRIPE_SECRET_KEY` outside source control.
- [ ] Add and verify Stripe webhooks before recording active subscriptions.
