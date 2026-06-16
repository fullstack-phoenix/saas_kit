---
name: ecto-multi
description: Ecto multi patterns and guidance. Use when designing schemas, queries, or operations involving multi-step transactions.
---

# Ecto Transactions (Repo.transact)

Use `Repo.transact` for atomic multi-step database operations. Valified has moved away from `Ecto.Multi`/`Valified.Sequence` in favor of the cleaner `Repo.transact` API.

## ⚠️ PROJECT CONVENTION: Use Repo.transact

**IMPORTANT**: In Valified, use `Repo.transact` for multi-step transactions instead of `Ecto.Multi` or `Valified.Sequence`.

**Benefits of `Repo.transact`**:
- **Simpler API**: Just a function, no complex builders
- **Standard Elixir**: Works naturally with `with/1`
- **Clearer control flow**: Read top-to-bottom like normal code
- **Automatic rollback**: On exceptions or `{:error, _}` returns

## Why Use Transactions?

Multi-step operations that must all succeed or all fail:
- Creating a user with account and permissions
- Processing a payment with multiple updates
- Complex workflows with multiple database operations
- Operations that need consistency guarantees

**Benefits**:
- **Atomic**: All operations succeed or all rollback
- **Simple**: Just wrap operations in `Repo.transact`
- **Safe**: No partial states in the database
- **Familiar**: Standard Elixir patterns

## Basic Transaction Pattern

```elixir
def create_user_with_account(user_attrs, account_attrs) do
  Repo.transact(fn ->
    with {:ok, user} <- Repo.insert(User.changeset(%User{}, user_attrs)),
         {:ok, account} <- Repo.insert(Account.changeset(%Account{user_id: user.id}, account_attrs)) do
      {:ok, %{user: user, account: account}}
    end
  end)
end
```

**Returns**:
- `{:ok, %{user: user, account: account}}` if all operations succeed
- `{:error, changeset}` if any operation fails
- Transaction automatically rolls back on error

## Transaction Patterns

### 1. Simple Transaction (Arity 0)

Just wrap operations, uses default `Repo`:

```elixir
def create_company_with_admin(company_attrs, admin_attrs) do
  Repo.transact(fn ->
    with {:ok, company} <- Repo.insert(Company.changeset(%Company{}, company_attrs)),
         {:ok, admin} <- Repo.insert(User.changeset(%User{company_id: company.id}, admin_attrs)) do
      {:ok, company}
    end
  end)
end
```

### 2. Transaction with Repo Access (Arity 1)

Receive the repo as an argument (useful for testing with different repos):

```elixir
def create_with_custom_repo(attrs) do
  Repo.transact(fn repo ->
    with {:ok, record} <- repo.insert(changeset),
         {:ok, related} <- repo.insert(related_changeset) do
      {:ok, record}
    end
  end)
end
```

### 3. Transaction with `with/1` (Recommended)

Most common pattern - clear, sequential operations:

```elixir
def invite_user_to_company(company, inviter, invitee_attrs) do
  Repo.transact(fn ->
    with {:ok, user} <- create_user(invitee_attrs),
         {:ok, company_user} <- add_user_to_company(company, user),
         {:ok, invitation} <- create_invitation(company, inviter, user),
         :ok <- send_invitation_email(invitation) do
      {:ok, invitation}
    end
  end)
end
```

### 4. Transaction with Multiple Steps

```elixir
def process_payment(order, payment_attrs) do
  Repo.transact(fn ->
    with {:ok, payment} <- Repo.insert(Payment.changeset(%Payment{}, payment_attrs)),
         {:ok, order} <- Repo.update(Order.changeset(order, %{status: :paid, payment_id: payment.id})),
         {:ok, _receipt} <- Repo.insert(Receipt.changeset(%Receipt{order_id: order.id})),
         :ok <- notify_customer(order) do
      {:ok, order}
    end
  end)
end
```

### 5. Transaction with Queries

```elixir
def archive_old_records(cutoff_date) do
  Repo.transact(fn ->
    # Query within transaction
    old_records = Repo.all(from r in Record, where: r.inserted_at < ^cutoff_date)

    with {count, _} <- Repo.update_all(
           from(r in Record, where: r.inserted_at < ^cutoff_date),
           set: [archived_at: DateTime.utc_now()]
         ),
         :ok <- log_archive(count) do
      {:ok, count}
    end
  end)
end
```

### 6. Transaction with Custom Logic

```elixir
def create_company_with_setup(attrs) do
  Repo.transact(fn ->
    # Create company
    {:ok, company} = Repo.insert(Company.changeset(%Company{}, attrs))

    # Create financial years (custom logic)
    current_year = Date.utc_today().year

    for year <- [current_year, current_year + 1] do
      Repo.insert!(FinancialYear.changeset(%FinancialYear{
        company_id: company.id,
        year: year,
        start_date: Date.new!(year, 1, 1),
        end_date: Date.new!(year, 12, 31)
      }))
    end

    # Record audit event
    Auditing.record_event("company_created", subject: company)

    {:ok, company}
  end)
end
```

## Error Handling

### Automatic Rollback on {:error, _}

```elixir
Repo.transact(fn ->
  with {:ok, record} <- Repo.insert(changeset),
       {:ok, related} <- Repo.insert(related_changeset) do
    {:ok, record}
  end
  # If any step returns {:error, _}, transaction rolls back
end)
# Returns {:error, changeset} that failed
```

### Automatic Rollback on Exceptions

```elixir
Repo.transact(fn ->
  record = Repo.insert!(changeset)  # Raises on error
  related = Repo.insert!(related_changeset)
  {:ok, record}
end)
# If insert! raises, transaction rolls back and exception bubbles up
```

### Explicit Rollback

```elixir
Repo.transact(fn ->
  {:ok, record} = Repo.insert(changeset)

  if invalid_condition?(record) do
    Repo.rollback(:invalid_record)  # Explicitly rollback
  end

  {:ok, record}
end)
# Returns {:error, :invalid_record}
```

### Pattern Matching Errors

```elixir
def create_user_with_validation(attrs) do
  Repo.transact(fn ->
    with {:ok, user} <- Repo.insert(User.changeset(%User{}, attrs)),
         :ok <- validate_user_rules(user),
         {:ok, profile} <- create_profile(user) do
      {:ok, user}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, :validation_failed} ->
        {:error, :user_validation_failed}
    end
  end)
end
```

## Post-Transaction Operations

Since `Repo.transact` doesn't have a built-in defer mechanism like the old `Sequence.defer`, handle post-transaction operations manually:

```elixir
def create_invitation_with_email(attrs) do
  case Repo.transact(fn ->
    with {:ok, invitation} <- Repo.insert(Invitation.changeset(%Invitation{}, attrs)),
         {:ok, _notification} <- Repo.insert(notification_for(invitation)) do
      {:ok, invitation}
    end
  end) do
    {:ok, invitation} = result ->
      # Send email AFTER transaction commits
      Mailer.send_invitation_email(invitation)
      result

    error ->
      error
  end
end
```

Or use a helper:

```elixir
defp with_post_transaction(result, fun) do
  case result do
    {:ok, value} = success ->
      fun.(value)
      success
    error ->
      error
  end
end

def create_with_email(attrs) do
  Repo.transact(fn ->
    # ... transaction operations
    {:ok, invitation}
  end)
  |> with_post_transaction(fn invitation ->
    Mailer.send_invitation_email(invitation)
  end)
end
```

## Testing Transactions

```elixir
defmodule Valified.CompaniesTest do
  use Valified.DataCase
  alias Valified.Companies

  describe "create_company_with_admin/2" do
    test "creates both company and admin" do
      company_attrs = %{name: "Acme Inc", vat_number: "SE123"}
      admin_attrs = %{email: "admin@acme.com", name: "Admin"}

      assert {:ok, company} = Companies.create_company_with_admin(
        company_attrs,
        admin_attrs
      )

      # Verify both records created
      assert company.name == "Acme Inc"
      admin = Repo.get_by(User, company_id: company.id)
      assert admin.email == "admin@acme.com"
    end

    test "rolls back everything on failure" do
      company_attrs = %{name: "Acme Inc", vat_number: "SE123"}
      # Invalid admin attrs
      admin_attrs = %{email: "invalid"}

      assert {:error, _changeset} = Companies.create_company_with_admin(
        company_attrs,
        admin_attrs
      )

      # Verify nothing was created
      refute Repo.get_by(Company, name: "Acme Inc")
      refute Repo.get_by(User, email: "invalid")
    end
  end
end
```

## Common Patterns

### Audit Logging

```elixir
def update_with_audit(record, attrs, actor: actor) do
  Repo.transact(fn ->
    with {:ok, updated} <- Repo.update(Record.changeset(record, attrs)),
         {:ok, _event} <- Auditing.record_update(
           actor: actor,
           subject: updated,
           action: "record_updated"
         ) do
      {:ok, updated}
    end
  end)
end
```

### Conditional Operations

```elixir
def create_with_optional_notification(attrs, notify: notify?) do
  result = Repo.transact(fn ->
    with {:ok, record} <- Repo.insert(Record.changeset(%Record{}, attrs)),
         {:ok, _meta} <- insert_metadata(record) do
      {:ok, record}
    end
  end)

  if notify? do
    with_post_transaction(result, &Notifier.send_notification/1)
  else
    result
  end
end
```

### Batch Operations

```elixir
def create_multiple(items_attrs) do
  Repo.transact(fn ->
    results =
      Enum.map(items_attrs, fn attrs ->
        {:ok, item} = Repo.insert(Item.changeset(%Item{}, attrs))
        item
      end)

    {:ok, results}
  end)
end
```

### Complex Workflows

```elixir
def process_workflow(workflow) do
  Repo.transact(fn ->
    with {:ok, workflow} <- Repo.update(Workflow.changeset(workflow, %{status: :processing})),
         {:ok, results} <- execute_workflow_actions(workflow),
         {:ok, workflow} <- Repo.update(Workflow.changeset(workflow, %{
           status: :completed,
           completed_at: DateTime.utc_now(),
           results: results
         })) do
      {:ok, workflow}
    else
      {:error, reason} ->
        # Update workflow as failed before rolling back
        Repo.update!(Workflow.changeset(workflow, %{
          status: :failed,
          error: inspect(reason)
        }))
        {:error, reason}
    end
  end)
end
```

## Transaction vs Direct Operations

**Use Transaction when**:
- Multiple database operations must be atomic
- Operations depend on previous step results
- Need to guarantee rollback on any failure
- Performing complex workflows

**Don't use Transaction when**:
- Single database operation
- Operations are independent
- Don't need atomicity
- Simple CRUD operation

```elixir
# Good: Single operation (no transaction needed)
def update_user(user, attrs) do
  user
  |> User.changeset(attrs)
  |> Repo.update()
end

# Good: Multiple related operations (use transaction)
def create_company_with_setup(attrs) do
  Repo.transact(fn ->
    # Multiple interdependent operations
  end)
end
```

## Nested Transactions

`Repo.transact` automatically handles nesting:

```elixir
def outer_operation do
  Repo.transact(fn ->
    # This starts a transaction
    with {:ok, record} <- inner_operation(),  # This reuses the transaction
         {:ok, other} <- Repo.insert(...) do
      {:ok, record}
    end
  end)
end

def inner_operation do
  Repo.transact(fn ->
    # This reuses the outer transaction (doesn't create nested transaction)
    Repo.insert(changeset)
  end)
end
```

## Migration from Valified.Sequence

If you see old code using `Valified.Sequence`, migrate to `Repo.transact`:

### Before (Sequence)
```elixir
def create_user_with_account(user_attrs, account_attrs) do
  case create_sequence(user_attrs, account_attrs) |> Repo.execute() do
    {:ok, %{user: user}} -> {:ok, user}
    {:error, _step, changeset, _changes} -> {:error, changeset}
  end
end

defp create_sequence(user_attrs, account_attrs) do
  Sequence.new()
  |> Sequence.insert(:user, User.changeset(%User{}, user_attrs))
  |> Sequence.insert(:account, fn %{user: user} ->
    Account.changeset(%Account{user_id: user.id}, account_attrs)
  end)
end
```

### After (Repo.transact)
```elixir
def create_user_with_account(user_attrs, account_attrs) do
  Repo.transact(fn ->
    with {:ok, user} <- Repo.insert(User.changeset(%User{}, user_attrs)),
         {:ok, account} <- Repo.insert(
           Account.changeset(%Account{user_id: user.id}, account_attrs)
         ) do
      {:ok, user}
    end
  end)
end
```

## Implementation Checklist

When using `Repo.transact`:
- [ ] Wrap multi-step operations in `Repo.transact(fn -> ... end)`
- [ ] Use `with/1` for sequential operations
- [ ] Return `{:ok, result}` on success
- [ ] Return `{:error, reason}` on failure
- [ ] Handle post-transaction operations (emails, etc.) after transaction
- [ ] Test both success and failure scenarios
- [ ] Verify rollback behavior in tests
- [ ] Consider if atomicity is actually needed

## Related Skills
- `phx-contexts` - Using transactions in context functions
- `ecto-transactions` - Lower-level transaction patterns
- `auditing` - Integrating audit logging in transactions
- `oban-job` - Enqueuing jobs after transactions
