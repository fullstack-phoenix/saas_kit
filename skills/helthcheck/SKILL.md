---
name: helthcheck
description: Use when the app needs a health check endpoint for a load balancer or uptime monitor. Covers installing plug_checkup at /health, configuring checks, and adding custom checkups.
user-invocable: true
---

# Health Check Endpoint

Adds a `/health` endpoint via `plug_checkup`. It returns HTTP 200 when the app
and its dependencies (DB, Redis, downstream services) are healthy, and a non-200
when they are not — so a load balancer or uptime monitor can route around an
unhealthy instance.

## When to use

- The app is deployed behind a load balancer or platform (Fly, Render, AWS, Kubernetes) that needs a health probe URL.
- You want an uptime monitor (BetterStack, Pingdom, UptimeRobot) to confirm the app and its dependencies are reachable.
- Don't reach for this if you only need a bare liveness ping with no dependency checks — a one-line `Plug` returning 200 is simpler.

## Dependencies

- Requires: None.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install helthcheck
```

Adds the `plug_checkup` package and wires the `/health` route. No install
decisions to answer.

## What it generates

- Adds `plug_checkup` to `mix.exs` deps.
- A health check plug/route mounted at `/health` in `lib/my_app_web/router.ex`.
- A checkup definition module that lists the checks run on each request (DB connectivity by default).

## Configuration

`plug_checkup` is configured through the checks list passed to the plug rather
than `config/*.exs`. The default check verifies the repo is reachable.

## Tweaking for your app

Add a custom checkup for a downstream dependency. Define a check module:

```elixir
# lib/my_app/health/redis_check.ex
defmodule MyApp.Health.RedisCheck do
  def call do
    case MyApp.Redis.ping() do
      :ok -> :ok
      error -> {:error, error}
    end
  end
end
```

Register it alongside the default DB check where the health plug is mounted:

```elixir
# lib/my_app_web/router.ex
forward "/health", PlugCheckup,
  PlugCheckup.Options.new(
    json_encoder: Jason,
    checks: [
      %PlugCheckup.Check{name: "DB", module: MyApp.Health.DBCheck, function: :call},
      %PlugCheckup.Check{name: "Redis", module: MyApp.Health.RedisCheck, function: :call}
    ]
  )
```

- **Move the path:** change `"/health"` in the `forward/2` call to e.g. `"/healthz"` for Kubernetes conventions.
- **Cache results:** set `time_to_cache` in `PlugCheckup.Options.new/1` to avoid hammering dependencies on every probe.
- **Tighten checks:** any function returning `:ok` or `{:error, reason}` is a valid check — add one per external service you depend on.

## After install

- [ ] `mix deps.get` — fetch `plug_checkup`.
- [ ] Hit `/health` in the browser and confirm it returns HTTP 200.
- [ ] Point your load balancer / uptime monitor (Fly, Render, AWS, BetterStack) at `/health`.
- [ ] Add custom checkup modules for any downstream services you depend on.
