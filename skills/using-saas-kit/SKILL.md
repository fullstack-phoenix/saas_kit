---
name: using-saas-kit
description: Use when setting up the SaaS Kit in a Phoenix app or installing/listing its features. Covers the install flow and every `mix saaskit.*` task.
user-invocable: true
---

# Using SaaS Kit

SaaS Kit ships production-ready features (auth, teams, payments, oauth, …) into
an existing Phoenix app as a set of `mix saaskit.*` tasks. You generate a normal
Phoenix app, point it at a boilerplate token, then install features one at a
time. Each feature is a catalog entry under the kit; this skill is the entry
point — read it first, then open the matching feature skill.

## Prerequisites

- Elixir/Phoenix installed (`mix phx.new` available).
- A boilerplate token from https://fullstackphoenix.com/ (the boilerplate page).

## 1. Create your Phoenix app

Run this **outside** an existing Phoenix project:

```bash
mix phx.new my_saas
```

## 2. Add SaaSKit to `mix.exs`

```elixir
def deps do
  [
    {:saas_kit, "~> 3.0"}
  ]
end
```

## 3. Configure the boilerplate token

Add to `config/dev.exs`:

```elixir
config :saas_kit, boilerplate_token: "<token>"
```

Without this, `mix saaskit.setup` raises and points you at the boilerplate page.

## 4. Fetch deps and run setup

```bash
mix deps.get
mix saaskit.setup
```

`saaskit.setup` installs the initial SaaS Kit feature and creates local project
state. It also offers to install agent guidance (`--agent-skills` to accept
without prompting, `--no-agent-skills` to skip).

## 5. Install features

Install a whole plan, or features individually:

```bash
mix saaskit.plan.install <token>      # install a saved plan's features
mix saaskit.feature.install authentication
```

## Mix tasks

After setup, these tasks drive everything. All support `--json` where shown, so
an agent can probe state machine-readably.

### `mix saaskit.status`

Reports current state: config status, app name, installed/pending feature
counts, and the suggested next command. Use it as the first probe in any
session.

```bash
mix saaskit.status
mix saaskit.status --json
```

### `mix saaskit.help`

Getting-started info and the full task catalog. Runs fully offline; reports
whether `boilerplate_token` is set.

```bash
mix saaskit.help
mix saaskit.help --json
```

### `mix saaskit.feature.list`

Lists all available features and their installation status.

```bash
mix saaskit.feature.list
mix saaskit.feature.list --filter "auth,billing"
mix saaskit.feature.list --json
```

- `--filter` — comma-separated words matched against name, slug, or description.
- `--json` — machine-readable list (slug, name, packages, dependencies,
  decisions, installed).

### `mix saaskit.feature.show`

Full detail for one feature (description, packages, dependencies, decisions).

```bash
mix saaskit.feature.show authentication
mix saaskit.feature.show authentication --json
```

### `mix saaskit.feature.install`

Installs one feature. Some features ask **decisions** — answer them up front with
`--decision`, or resume an interrupted install with `--step`.

```bash
mix saaskit.feature.install authentication
mix saaskit.feature.install authentication --token <token>
mix saaskit.feature.install payments --decision provider=stripe_subscription
mix saaskit.feature.install authentication --step <uuid>
```

### `mix saaskit.plan.install`

Installs a saved plan (multiple features at once).

```bash
mix saaskit.plan.install <plan_id>
mix saaskit.plan.install <plan_id> <token>
```

## Recommended flow

1. `mix saaskit.status` — confirm configured and see the next command.
2. `mix saaskit.feature.list` — pick features (respect dependencies).
3. Install `core` features first (e.g. `authentication`), then add-ons.
4. After each install, run the feature's `after install` checklist
   (`mix ecto.migrate`, config edits) before moving on.

## Read next

- Per-feature skills live alongside this one, one folder per feature slug
  (`authentication/`, `teams/`, `payments/`, …). Open the one matching the
  feature you're installing for when-to-use guidance, config, and tweaks.
