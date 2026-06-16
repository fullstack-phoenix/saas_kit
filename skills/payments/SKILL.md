---
name: payments
description: Use when the app needs to charge users — subscriptions or one-time purchases. Covers installing the billing facade, choosing a provider (Stripe subscriptions to start), configuring keys, and wiring a checkout flow.
user-invocable: true
---

# Payments

Installs a small billing facade behind a `@callback` so the app charges users
through one swappable provider implementation. The first available provider is
Stripe Subscription checkout: it creates hosted Stripe Checkout sessions over
`Req`, with no extra HTTP client dependency. You call
`MyApp.Billing.checkout_url/2` from your own checkout route.

## When to use

- The app needs paid plans — subscriptions or one-time purchases — and you want
  a provider-agnostic seam rather than Stripe calls scattered through controllers.
- You want hosted Checkout (Stripe redirects, collects card details) instead of
  building a payment form yourself.
- Don't reach for this if billing is free, or if you only need a static
  "contact sales" page with no charge flow.

## Dependencies

- Requires: `authentication` — billing is keyed to a `user`.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install payments
```

The installer asks one decision:

- **Which payment provider?** (`provider`) — required. The only current option is
  `stripe_subscription`, which installs the Stripe hosted-Checkout subscription
  implementation behind the facade.

```bash
mix saaskit.feature.install payments --decision provider=stripe_subscription
```

## What it generates

- `lib/my_app/billing.ex` — the billing facade. Defines the
  `create_checkout_session/2` `@callback`, the public `checkout_url/2` entry
  point, and a private `provider/0` that resolves the configured implementation.

## Configuration

The facade resolves its provider from application config:

```elixir
# config/config.exs
config :my_app, :billing,
  provider: MyApp.Billing.StripeSubscription
```

Secrets come from the environment, not config files:

- `STRIPE_SECRET_KEY` — your Stripe API secret.
- `STRIPE_SUBSCRIPTION_PRICE_ID` — the price the subscription Checkout charges.

For production, set both in the deployed environment and switch to your live
Stripe keys.

## Tweaking for your app

Call the facade from an authenticated checkout action and redirect to the hosted
session:

```elixir
# lib/my_app_web/controllers/checkout_controller.ex
def create(conn, _params) do
  user = conn.assigns.current_user

  {:ok, url} =
    MyApp.Billing.checkout_url(user,
      success_url: url(~p"/billing/success"),
      cancel_url: url(~p"/billing/cancel")
    )

  redirect(conn, external: url)
end
```

`checkout_url/2` requires `:success_url` and `:cancel_url`. Both are mandatory —
omitting them surfaces as an `{:error, term()}` from the provider.

Swap providers by implementing the behaviour and pointing config at it:

```elixir
# lib/my_app/billing/paddle.ex
defmodule MyApp.Billing.Paddle do
  @behaviour MyApp.Billing

  @impl true
  def create_checkout_session(_user, _opts) do
    # build the hosted session, return {:ok, url} | {:error, term()}
  end
end
```

```elixir
# config/config.exs
config :my_app, :billing, provider: MyApp.Billing.Paddle
```

Switch to one-time purchases by using a one-off price in
`STRIPE_SUBSCRIPTION_PRICE_ID` (or add a sibling provider that builds a
`mode: payment` session instead of a subscription).

## After install

- [ ] Set `STRIPE_SECRET_KEY` and `STRIPE_SUBSCRIPTION_PRICE_ID` in the environment.
- [ ] Add an authenticated checkout action that calls `MyApp.Billing.checkout_url/2`.
- [ ] Configure Stripe success and cancel URLs for your flow.
- [ ] Add signed webhook handling before trusting subscription state for authorization.

## Read next

- For the Stripe hosted-Checkout subscription provider (the only current
  `provider` option), see the [stripe-subscription](stripe-subscription/SKILL.md) sub-skill.
