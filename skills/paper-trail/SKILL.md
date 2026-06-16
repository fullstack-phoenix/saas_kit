---
name: paper-trail
description: Use when the app needs an audit trail or undo — track every insert/update/delete on records, see who changed what, and revert. Covers install, configuration, and tweaks for PaperTrail versioning.
user-invocable: true
---

# Versions with Paper Trail

Adds automatic record versioning via the [`paper_trail`](https://hex.pm/packages/paper_trail)
library. Every insert, update, and delete you route through PaperTrail is written
to a `versions` table, so you can audit how a record changed over time, attribute
each change to a user, and revert a record to an earlier state.

## When to use

- You need an audit log of changes to specific schemas (compliance, debugging).
- You want "undo" — the ability to revert a record to a previous version.
- You need to know which user made a given change.
- Don't reach for this if you only need created/updated timestamps — Ecto's
  `timestamps()` already covers that. Versioning adds a row per change.

## Dependencies

- Requires: None.
- Recommended: `authentication` — the migration references the `users` table for
  the originator, and the admin browser maps `"User" => MyApp.Users.User`.

## Install

```bash
mix saaskit.feature.install paper_trail
```

No installer decisions. The admin-only instructions (a nav item, a `/admin/versions`
route, and the version browser LiveView) are applied only if the `admin` feature
is present.

## What it generates

- Adds `{:paper_trail, "~> 1.1.0"}` to `mix.exs`.
- Migration `priv/repo/migrations/*_add_versions.exs` — creates the `versions`
  table (`event`, `item_type`, `item_id`, `item_changes`, `originator_id`,
  `origin`, `meta`, `inserted_at`).
- `lib/my_app/versions.ex` — `get_versions/1`, `revert_to_version/2`, and the
  change-diffing helpers behind revert.
- Wraps `lib/my_app/repo.ex` with `insert_with_papertrail/2`,
  `update_with_papertrail/2`, `delete_with_papertrail/2`, which return the plain
  model (`{:ok, model}`) instead of PaperTrail's `%{model: ...}` map.
- `test/my_app/versions_test.exs`.
- With `admin`: `lib/my_app_web/live/admin/version_live/show.ex` (the
  `/admin/versions` browser), a route, and a "Versions" nav item.

## Configuration

Injected into `config/config.exs`:

```elixir
config :paper_trail,
  repo: MyApp.Repo,
  timestamps_type: :utc_datetime
```

To attribute each version to a user, add the originator mapping:

```elixir
# config/config.exs
config :paper_trail,
  repo: MyApp.Repo,
  timestamps_type: :utc_datetime,
  originator: [name: :user, model: MyApp.Users.User]
```

## Tweaking for your app

Version a record by routing writes through PaperTrail instead of `Repo`. Use the
generated `Repo` wrappers so the return value stays `{:ok, struct}`:

```elixir
# lib/my_app/blog.ex
def update_post(%Post{} = post, attrs, user) do
  post
  |> Post.changeset(attrs)
  |> then(&MyApp.Repo.update_with_papertrail(&1, originator: [user: user]))
end
```

Read a record's history and revert:

```elixir
versions = MyApp.Versions.get_versions(post)
{:ok, %{model: reverted}} = MyApp.Versions.revert_to_version(post, target_version.id)
```

Expose more schemas in the admin browser by extending `@schemas` in
`lib/my_app_web/live/admin/version_live/show.ex`:

```elixir
# lib/my_app_web/live/admin/version_live/show.ex
@schemas %{
  "User" => MyApp.Users.User,
  "Post" => MyApp.Blog.Post
}
```

- **Originator FK:** the migration references `:users`. If your owning table is
  different, edit the `references(:users)` line before migrating.
- **Retention:** versions accumulate forever; periodically purge old rows from
  the `versions` table per your retention policy.

## After install

- [ ] `mix ecto.migrate` — create the `versions` table.
- [ ] Replace `Repo.insert/update/delete` with `PaperTrail.*` (or the generated
      `MyApp.Repo.*_with_papertrail/2` wrappers) on the schemas you want versioned.
- [ ] Add `originator: [name: :user, model: MyApp.Users.User]` to
      `config/config.exs` to attribute changes, passing `originator: [user: user]`
      on each write.
- [ ] Decide on a retention policy for old versions (purge after N months, etc.).
