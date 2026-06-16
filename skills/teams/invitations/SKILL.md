---
name: invitations
description: Use when wiring or customizing the teams invitation flow — emailing a user to join a team, the Swoosh notifier, and accepting an invite on sign-in.
user-invocable: true
---

# Team Invitations

The `teams` feature ships an email invitation flow. An owner creates an
`Invitation` for an email; a Swoosh notifier emails a sign-in link; once the
invitee signs in, you turn the pending invitation into a membership.

## When to use

- A team owner needs to add members who don't yet have an account.
- You want to customize the invite email (sender, copy, branding) or the
  acceptance behavior.
- Read the parent [`../SKILL.md`](../SKILL.md) first for install and scoping.

## How it works

`MyApp.Teams.create_invitation/3` inserts the invitation and pipes the result
through `invite_member/1`, which calls the notifier:

```elixir
# lib/my_app/teams.ex
def create_invitation(team, user, attrs \\ %{}) do
  %Invitation{}
  |> Invitation.changeset(attrs)
  |> Ecto.Changeset.put_assoc(:team, team)
  |> Ecto.Changeset.put_assoc(:invited_by, user)
  |> Repo.insert()
  |> invite_member()
end
```

The notifier sends a plain-text email with a log-in URL:

```elixir
# lib/my_app/teams/invitation_notifier.ex
def invite_user_email(%{email: email, url: url}) do
  new()
  |> to(email)
  |> from({"Phoenix Team", "team@example.com"})
  |> subject("Invited to join")
  |> text_body("...#{url}...")
  |> Mailer.deliver()
end
```

Pending invitations for the current user are found by email:

```elixir
MyApp.Teams.list_invitations_for_user(user) # email match, accepted_at IS NULL
```

## Tweaking for your app

Customize the sender and copy in `lib/my_app/teams/invitation_notifier.ex`:

```elixir
|> from({"Acme", "team@acme.test"})
|> subject("You're invited to join #{team_name} on Acme")
```

Accept an invitation after the invitee signs in — create the membership, then
mark the invitation accepted:

```elixir
{:ok, _membership} = MyApp.Teams.create_membership(invitation.team, user, %{role: :member})

{:ok, _invitation} =
  MyApp.Teams.update_invitation(invitation, %{
    accepted_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
```

- **Token links:** the default email links to `/users/log-in`. To make it
  one-click, pass a signed token in the URL and verify it on the acceptance page.
- **Decline:** the `Invitation` schema has a `declined_at` field — set it via
  `update_invitation/2` instead of creating a membership.

## After install

- [ ] Set a real `from` address in `invitation_notifier.ex`.
- [ ] Add an acceptance page that consumes `list_invitations_for_user/1` after
      sign-in and calls `create_membership/3`.
- [ ] Confirm `MyApp.Mailer` is configured (inherited from the base app).
