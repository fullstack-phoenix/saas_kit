---
name: rate-limiting
description: Use when the app needs to throttle requests or failed logins by IP or email. Covers installing Hammer + RemoteIp, the MyApp.RateLimit helpers, and how to tweak limits.
user-invocable: true
---

# Rate limiting

Adds IP- and login-based rate limiting to a Phoenix app using Hammer with the ETS
backend. Installs RemoteIp for proxy-aware client IP extraction, stores the
normalized IP in `conn.private`, and provides a `MyApp.RateLimit` module for
IP-based throttling. It also wraps the email/password login action so repeated
failed attempts for the same email are capped at 8 per minute.

## When to use

- The app needs to limit how often an IP can hit a route or endpoint.
- You want to slow down credential-stuffing / brute-force login attempts.
- Don't reach for this if the app already sits behind an upstream rate limiter
  (API gateway, Cloudflare) that covers the same routes.

## Dependencies

- Requires: `authentication` (the login limit wraps the generated
  `UserSessionController`).
- Recommended: None.

## Install

```bash
mix saaskit.feature.install rate_limiting
```

No install decisions. The installer adds `remote_ip` and `hammer` to `mix.exs`,
generates the IP extractor plug and the `MyApp.RateLimit` module, plugs IP
extraction into the endpoint, and rewrites the login action to check the limit.

## What it generates

- `lib/my_app_web/plugs/client_ip_extractor.ex` — `MyAppWeb.Plugs.ClientIPExtractor`,
  resolves the real client IP via RemoteIp and stores it in `conn.private` as
  `:remote_ip_tuple` and `:remote_ip_string`.
- `lib/my_app/rate_limit.ex` — `MyApp.RateLimit` (`use Hammer, backend: :ets`),
  exposes `limit_by_ip/2`, `limit_login/2`, and `client_ip/1`; usable as a plug.
- `lib/my_app_web/endpoint.ex` — plugs `ClientIPExtractor` right after
  `Plug.RequestId`.
- `lib/my_app_web/controllers/user_session_controller.ex` — the email/password
  login helper now calls `RateLimit.limit_login/2` before checking credentials,
  denying after 8 attempts per email per 60 seconds.
- `mix.exs` — adds `{:remote_ip, "~> 1.2"}` and `{:hammer, "~> 7.4"}`.

## Configuration

No config keys. Limits are passed as options at the call site. The defaults baked
into `MyApp.RateLimit` are:

```elixir
# lib/my_app/rate_limit.ex
@default_ip_scale_ms :timer.seconds(1)
@default_ip_limit 10
@default_login_scale_ms :timer.seconds(60)
@default_login_limit 8
```

The ETS backend keeps counters in-memory per node; in a multi-node cluster each
node throttles independently.

## Tweaking for your app

Throttle a router pipeline by IP — 10 requests per second by default, override
per pipeline:

```elixir
# lib/my_app_web/router.ex
pipeline :public_api do
  plug :accepts, ["json"]
  plug MyApp.RateLimit, scale_ms: :timer.seconds(1), limit: 30
end
```

Throttle a single controller action by IP:

```elixir
# lib/my_app_web/controllers/contact_controller.ex
def create(conn, params) do
  conn = MyApp.RateLimit.limit_by_ip(conn, scale_ms: :timer.seconds(60), limit: 5)

  if conn.halted do
    conn
  else
    # ... handle the request
  end
end
```

Reuse the login limiter for another email-keyed action (e.g. password reset):

```elixir
case MyApp.RateLimit.limit_login(email, scale_ms: :timer.seconds(60), limit: 3) do
  {:deny, _limit} -> # too many attempts
  {:allow, _count} -> # proceed
end
```

- **Change the login cap:** edit the `limit_login/2` call in
  `user_session_controller.ex` (defaults `scale_ms: :timer.seconds(60), limit: 8`).
- **Different key:** `limit_by_ip/2` keys on `"ip:<client_ip>"`; for per-user
  limits call `MyApp.RateLimit.hit("user:#{user.id}", scale_ms, limit)` directly.

## After install

- [ ] `mix deps.get` — install RemoteIp and Hammer.
- [ ] Confirm `MyAppWeb.Plugs.ClientIPExtractor` is plugged before the router in `endpoint.ex`.
- [ ] Make 8+ failed login attempts for one email within 60 seconds and confirm the login page is rate limited.
- [ ] For other sensitive endpoints, add `plug MyApp.RateLimit, scale_ms: :timer.seconds(1), limit: 10` to a router pipeline or call `MyApp.RateLimit.limit_by_ip/2` from a controller.
