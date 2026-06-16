---
name: teams
description: Use when the app needs multi-tenancy — multiple users sharing data under teams, with personal teams, memberships, roles, and team switching. Covers install, scope-based tenant isolation, and tweaks.
user-invocable: true
---

# Teams

Adds multi-tenancy on top of authentication. Every user automatically gets a
personal team on registration, can belong to additional shared teams via
memberships, and can switch the active team. The `Scope` struct in
`lib/my_app/users/scope.ex` carries both `current_user` and `current_team`, so
queries can be isolated per tenant. Ships team-management and member LiveViews
plus a team switcher component.

## When to use

- The app needs multi-user accounts where data is owned by a team, not a single
  user (shared workspaces, organizations, projects).
- You want role-based membership (`:owner` / `:member`) and an invite flow out
  of the box.
- Don't reach for this if the app is single-user — `authentication` alone is
  enough. Teams adds a scoping discipline you must follow everywhere.

## Dependencies

- Requires: `authentication` (this is a `core` feature, `position` 6 — install
  it after auth).
- Recommended: None.

## Install

```bash
mix saaskit.feature.install teams
```

No interactive decisions. The installer generates the `Teams` context, schemas,
and LiveViews; wires `current_team` into `UserAuth`/`Scope`; adds the `:team`
scope to config; and (when the `layouts` feature is present) injects a `Teams`
nav link and the team switcher into the app and public layouts.

## What it generates

- `lib/my_app/teams.ex` — context: `create_team/2`, `update_team/2`,
  `create_membership/3`, `list_memberships/1`, `create_invitation/3`,
  `can_be_accessed_by_a_user?/2`.
- `lib/my_app/teams/team.ex` — `teams` schema (`name`, `personal`, `created_by`).
- `lib/my_app/teams/membership.ex` — `team_memberships` join (`role` enum).
- `lib/my_app/teams/member.ex` — read view onto the `users` table for membership.
- `lib/my_app/teams/invitation.ex` + `invitation_notifier.ex` — email invites.
- `lib/my_app_web/live/team_live/` and `member_live/` — management LiveViews.
- `lib/my_app_web/live/team_switch_component.ex` — header team switcher.
- Extends `lib/my_app/users/user.ex` with `current_team_id`, `personal_team`,
  `memberships`, `teams`, and `lib/my_app/users.ex` with `switch_team/2`,
  `current_team/1`, `with_memberships/1`, auto personal-team creation on register.
- Migration `priv/repo/migrations/*_create_teams_migrations.exs` — `teams`,
  `team_memberships`, `invitations` tables.

## Configuration

The installer rewrites the `:scopes` config so `:team` is the default scope:

```elixir
# config/config.exs
config :my_app, :scopes,
  user: [
    default: false,
    # ...
  ],
  team: [
    default: true,
    module: MyApp.Users.Scope,
    assign_key: :current_scope,
    access_path: [:team, :id],
    route_prefix: "/teams/:team",
    schema_key: :team_id,
    schema_type: :id,
    schema_table: :teams
  ]
```

With `:team` as the default scope, generators and `current_scope` assigns resolve
against the active team. Keep `default: true` on `:team` so tenant-owned data is
scoped by team rather than user.

## Tweaking for your app

Scope tenant-owned queries by the current team. The active team is on the scope:

```elixir
# in a LiveView or controller, current_scope is assigned
team = socket.assigns.current_scope.team

posts =
  MyApp.Repo.all(
    from p in MyApp.Blog.Post, where: p.team_id == ^team.id
  )
```

Switch the active team (only teams the user is a member of are allowed):

```elixir
{:ok, user} = MyApp.Users.switch_team(user, team_id)
```

Create a team with the creator as owner:

```elixir
{:ok, team} = MyApp.Teams.create_team(user, %{name: "Acme", personal: false})
{:ok, _} = MyApp.Teams.create_membership(team, user, %{role: :owner})
```

- **Add roles:** extend the `Ecto.Enum` values on `role` in
  `lib/my_app/teams/membership.ex` (default is `[:owner, :member]`), then gate
  actions on `membership.role`.
- **Add team fields:** add the column to the create-teams migration and the
  field + `cast/3` list in `lib/my_app/teams/team.ex`.
- **Personal team naming:** the `register_user/1` hook in `lib/my_app/users.ex`
  creates a `"Personal Team"` — change that string to use the user's name.

## After install

- [ ] `mix ecto.migrate` — create `teams`, `team_memberships`, `invitations`.
- [ ] Audit existing schemas and queries — scope by `current_scope.team`
      wherever tenant-owned data lives, or you'll leak data between tenants.
- [ ] Wire the team switcher into your app layout header (auto-done if `layouts`
      is installed).
- [ ] Test the full invite flow: create team → send invite → accept → switch.
- [ ] Decide whether new sign-ups auto-create a personal team or land on a
      "create team" page.

## Read next

- For the invitation + email-acceptance flow, read [`invitations/SKILL.md`](invitations/SKILL.md).
