# SaaS Kit

A Mix-task CLI that installs Phoenix SaaS boilerplate features (auth, billing,
teams, landing pages, …) from [livesaaskit.com][lsk] into your existing
Phoenix application.

You pick features from the catalog at livesaaskit.com, get a boilerplate
token, and run `mix saaskit.feature.install <slug>` in your project. The task
talks to the API, receives a list of file operations, and applies them
locally. Nothing is installed remotely; everything happens in your repo.

[lsk]: https://livesaaskit.com/

## Requirements

- Elixir `~> 1.16`
- Phoenix `~> 1.8`
- A boilerplate token from [livesaaskit.com][lsk]

## Installation

Add `saas_kit` to your `mix.exs` deps:

```elixir
def deps do
  [
    {:saas_kit, "~> 2.6", only: :dev, runtime: false}
  ]
end
```

Then add your token to `config/config.exs`:

```elixir
config :saas_kit,
  boilerplate_token: "your_token_here"
```

Get the token from your boilerplate page at [livesaaskit.com][lsk].

## Quickstart

```bash
mix phx.new my_app && cd my_app
# add saas_kit to mix.exs + token to config
mix deps.get
mix saaskit.status               # sanity-check config + API
mix saaskit.setup                # run initial project setup
mix saaskit.agent.feature.list   # see what's available
mix saaskit.feature.install auth # install a feature
```

## For AI agents

All read-only tasks accept `--json` and emit a stable, versioned schema:

```bash
mix saaskit.status --json
mix saaskit.agent.feature.list --json
mix saaskit.agent.feature.show auth --json
mix saaskit.help --json
```

Every JSON document starts with:

```json
{ "schema_version": 1, "ok": true, ... }
```

Failures follow the same envelope with stable error codes:

```json
{
  "schema_version": 1,
  "ok": false,
  "error": { "code": "not_configured", "message": "..." }
}
```

Error codes: `not_configured`, `api_unreachable`, `feature_not_found`.

Failing JSON payloads are written to stdout and the task exits non-zero.

## Tasks

| Task | Purpose |
|------|---------|
| `mix saaskit.help` | Show the task catalog and getting-started guide (`--json` for structured catalog). |
| `mix saaskit.status` | Report config, app, installed feature counts, suggested next command (`--json`). |
| `mix saaskit.setup` | Run initial project setup (installs the `initial_setup` feature). |
| `mix saaskit.feature.install <slug>` | Install one feature. `--token` to override, `--step <uuid>` to resume. |
| `mix saaskit.plan.install <plan_id>` | Install every feature in a saved plan, in order. |
| `mix saaskit.agent.feature.list` | List all features with installation status (`--filter`, `--json`). |
| `mix saaskit.agent.feature.show <slug>` | Show full detail for a single feature (`--json`). |

## Troubleshooting

**`not_configured`** — `boilerplate_token` is missing. Add it to `config/config.exs`
as shown above.

**`api_unreachable`** — The task could not reach livesaaskit.com or your token
did not resolve. Check your network, verify the token on your boilerplate
page, and re-run.

**Install failed mid-way** — feature installs emit a step id when they fail.
Resume with:

```bash
mix saaskit.feature.install <slug> --step <uuid>
```

## Configuration reference

| Key | Default | Purpose |
|-----|---------|---------|
| `:boilerplate_token` | (required) | Your boilerplate's API token. |
| `:base_url` | `"https://livesaaskit.com"` | API host. Override for self-hosted / staging. |

## License

MIT. Maintained by [fullstack-phoenix/saas_kit](https://github.com/fullstack-phoenix/saas_kit).
