---
name: oban
description: Use when the app needs background jobs, scheduled/cron tasks, or async work off the request path. Covers installing Oban + Oban Web, queue config, the migration, test mode, and writing workers.
user-invocable: true
---

# Oban background jobs

Integrates Oban, the database-backed job processing library, into the Phoenix app.
Adds the `oban` + `oban_web` deps, four queues (`default`, `mailers`, `high`,
`low`), the Pruner and Cron plugins, the `oban_jobs` migration, the Oban Web
dashboard, and test helpers wired into `:manual` mode. This is a `core` feature.

## When to use

- The app needs to run work outside the request cycle: sending email, calling
  third-party APIs, generating reports, processing uploads.
- You need scheduled/recurring jobs (cron) or reliable retries with persistence.
- You want a dashboard to inspect, retry, and cancel jobs.
- Don't reach for this if a fire-and-forget `Task` is enough and you don't need
  persistence, retries, or scheduling.

## Dependencies

- Requires: None.
- Recommended: None. If `authentication`/admin is installed, the installer mounts
  the dashboard at `/admin/oban`; otherwise it mounts under `/dashboard`.

## Install

```bash
mix saaskit.feature.install oban
```

No interactive decisions. The installer:

- Adds `{:oban, "~> 2.20.0"}` and `{:oban_web, "~> 2.11.0"}` to `mix.exs`.
- Picks the Oban engine from the boilerplate's DB choice: `Oban.Engines.Lite`
  for sqlite3, `Oban.Engines.Basic` otherwise.
- Mounts the Oban Web dashboard at `/admin/oban` (admin present) or `/dashboard`.

## What it generates

- `config/config.exs` — `config :my_app, Oban` block (engine, repo, queues, plugins).
- `config/test.exs` — `config :my_app, Oban, testing: :manual`.
- `lib/my_app/application.ex` — `{Oban, Application.fetch_env!(:my_app, Oban)}` in
  the supervision tree, after the Endpoint.
- `lib/my_app_web/router.ex` — `import Oban.Web.Router` and an `oban_dashboard`
  route.
- migration `priv/repo/migrations/*_add_oban_jobs_table.exs` — `Oban.Migration.up(version: 12)`,
  creates the `oban_jobs` table.
- `test/support/conn_case.ex` and `test/support/data_case.ex` — `use Oban.Testing, repo: MyApp.Repo`.

## Configuration

Injected into `config/config.exs`:

```elixir
# config/config.exs
config :my_app, Oban,
  engine: Oban.Engines.Basic,
  repo: MyApp.Repo,
  queues: [default: 10, mailers: 20, high: 50, low: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600 * 24},
    {Oban.Plugins.Cron,
     crontab: [
       # {"0 2 * * *", MyApp.ExampleWorker},
     ]}
  ]
```

- `queues` — the number is per-queue concurrency. Tune to your DB connection pool.
- `Pruner` `max_age` — completed jobs are deleted after 24h. Raise for longer audit.
- `Cron` `crontab` — empty by default; add `{cron_expr, Worker}` tuples for schedules.

Tests run Oban in `:manual` mode so jobs never execute unless you drain them:

```elixir
# config/test.exs
config :my_app, Oban, testing: :manual
```

## Tweaking for your app

Write a worker in `lib/my_app/workers/` and pick a queue:

```elixir
# lib/my_app/workers/email_worker.ex
defmodule MyApp.Workers.EmailWorker do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = MyApp.Users.get_user!(user_id)
    MyApp.Mailer.send_welcome_email(user)
    :ok
  end
end
```

Enqueue it:

```elixir
%{user_id: 123}
|> MyApp.Workers.EmailWorker.new()
|> Oban.insert()
```

Schedule it nightly by adding to the `Cron` crontab in `config/config.exs`:

```elixir
# config/config.exs
{Oban.Plugins.Cron,
 crontab: [
   {"0 2 * * *", MyApp.Workers.EmailWorker, args: %{user_id: 123}}
 ]}
```

- **Add a queue:** add `report: 5` to the `queues` keyword list and set
  `queue: :report` on the worker.
- **Delay a job:** `MyApp.Workers.EmailWorker.new(args, schedule_in: 60)`.
- **Test a worker:** in a test, assert it was enqueued and run it:

```elixir
# test/my_app/workers/email_worker_test.exs
use MyApp.DataCase

test "enqueues and runs the welcome email" do
  assert {:ok, _} = Oban.insert(MyApp.Workers.EmailWorker.new(%{user_id: 1}))
  assert_enqueued worker: MyApp.Workers.EmailWorker, args: %{user_id: 1}
  assert %{success: 1} = Oban.drain_queue(queue: :mailers)
end
```

## After install

- [ ] `mix ecto.migrate` — create the `oban_jobs` table.
- [ ] Visit `/admin/oban` (as admin) for the Oban Web dashboard.
- [ ] Add workers under `lib/my_app/workers/` using `use Oban.Worker, queue: :default`.
- [ ] Add cron entries under `config :my_app, Oban` for scheduled jobs.
- [ ] In tests, use `Oban.Testing.assert_enqueued/1` and `Oban.drain_queue/1`.
