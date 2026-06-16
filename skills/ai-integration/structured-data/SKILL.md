---
name: structured-data
description: Build typed AI agents with InstructorLite and Ecto embedded schemas. Use when LLM output must be validated and returned as structured Elixir data.
user-invocable: true
---

# Structured Data

Use this skill when an AI feature should return validated Elixir data instead of freeform text.

## Goal

- Keep provider config in one place.
- Keep agent modules easy to find under `MyApp.Agents.*`.
- Return typed, validated structs through `InstructorLite`.
- Keep tests isolated with Mimic.

## Install

```elixir
def deps do
  [
    {:instructor_lite, "~> 1.2.0"}
  ]
end
```

## Root Agents Module

Create one shared module for API keys and model names:

```elixir
defmodule MyApp.Agents do
  @moduledoc """
  Central configuration for AI agents.
  Import this module in agent implementations to access API keys and models.
  """

  def anthropic_key, do: Application.get_env(:my_app, :anthropic)[:api_key]
  def openai_key, do: Application.get_env(:my_app, :openai)[:api_key]
  def gemini_key, do: Application.get_env(:my_app, :gemini)[:api_key]

  def model(:haiku), do: "claude-haiku-4-5"
  def model(:sonnet), do: "claude-sonnet-4-5"
  def model(:opus), do: "claude-opus-4-5"

  def model(:gpt_5_nano), do: "gpt-5-nano"
  def model(:gpt_5_mini), do: "gpt-5-mini"
  def model(:gpt_5), do: "gpt-5.2"
  def model(:gpt_4_1_mini), do: "gpt-4.1-mini"

  def model(:gemini_flash), do: "gemini-3-flash-preview"
  def model(:gemini_pro), do: "gemini-3-pro-preview"
end
```

## Credential Placement

Do not put provider credentials in shared `config/config.exs`.
Keep local credentials in `config/dev.exs`:

```elixir
config :my_app, :anthropic, api_key: System.get_env("ANTHROPIC_API_KEY")
config :my_app, :openai, api_key: System.get_env("OPENAI_API_KEY")
config :my_app, :gemini, api_key: System.get_env("GEMINI_API_KEY")
```

## Module Naming and Location

- Put agents in `lib/my_app/agents/`.
- Use `MyApp.Agents.TopicSomeAction` style names.
- Prefer names that describe one business task, such as `MyApp.Agents.PostsWritePost`.

Example:

```text
lib/my_app/agents/posts_write_post.ex
```

```elixir
defmodule MyApp.Agents.PostsWritePost do
end
```

## Agent Pattern

Use one task-specific module with a nested `Response` schema:

```elixir
defmodule MyApp.Agents.PostsWritePost do
  @moduledoc """
  Generates a structured draft for a post.
  """
  import MyApp.Agents

  defmodule Response do
    use Ecto.Schema
    use InstructorLite.Instruction

    @notes """
    ## Field Descriptions:
    - title: Final title for the post
    - summary: Short summary of the post
    - tags: List of topic tags
    - sections: Ordered sections in the post
      - heading: Section heading
      - body: Section content
    """

    @primary_key false
    embedded_schema do
      field :title, :string
      field :summary, :string
      field :tags, {:array, :string}

      embeds_many :sections, Section, primary_key: false do
        field :heading, :string
        field :body, :string
      end
    end

    @impl InstructorLite.Instruction
    def validate_changeset(changeset, _opts) do
      changeset
      |> Ecto.Changeset.validate_required([:title, :summary])
      |> Ecto.Changeset.validate_length(:title, min: 5, max: 120)
    end
  end

  @system_prompt """
  You write structured post drafts.
  Return complete, practical content that fits the requested topic and audience.
  """

  def call(topic) do
    InstructorLite.instruct(
      %{
        model: model(:sonnet),
        messages: [
          %{role: "system", content: @system_prompt},
          %{role: "user", content: build_user_prompt(topic)}
        ]
      },
      response_model: Response,
      adapter: InstructorLite.Adapters.Anthropic,
      adapter_context: [api_key: anthropic_key(), http_options: [receive_timeout: 90_000]]
    )
  end

  defp build_user_prompt(topic) do
    "Write a post draft about: #{topic}"
  end
end
```

## Provider Patterns

### Anthropic

```elixir
InstructorLite.instruct(
  %{
    model: model(:sonnet),
    messages: [
      %{role: "system", content: "System prompt"},
      %{role: "user", content: "User prompt"}
    ]
  },
  response_model: Response,
  adapter: InstructorLite.Adapters.Anthropic,
  adapter_context: [api_key: anthropic_key(), http_options: [receive_timeout: 90_000]]
)
```

### OpenAI

```elixir
InstructorLite.instruct(
  %{
    model: model(:gpt_5),
    input: [
      %{role: "system", content: "System prompt"},
      %{role: "user", content: "User prompt"}
    ]
  },
  response_model: Response,
  adapter_context: [api_key: openai_key(), http_options: [receive_timeout: 90_000]]
)
```

## Schema Rules

- Use `embedded_schema` for the response model.
- Add `@notes` with field meanings, allowed values, and nested structure.
- Use `embeds_many` when each list item has multiple fields.
- Use `{:array, :string}` for simple string lists.
- Add `validate_changeset/2` for business rules the model must satisfy.

## When to Use Structured Data

- The caller needs validated fields.
- The response feeds forms, workflows, or database writes.
- You need a predictable return shape from the model.
- You want nested entities, not one large blob of text.

## Testing

Test structured AI integrations with Mimic so tests never hit real providers.
Mock the boundary you call directly:

```elixir
# test/test_helper.exs
Mimic.copy(InstructorLite)
ExUnit.start()
```

```elixir
defmodule MyApp.Agents.PostsWritePostTest do
  use MyApp.DataCase, async: true
  use Mimic

  test "returns a validated response" do
    InstructorLite
    |> expect(:instruct, fn _request, opts ->
      {:ok, struct(opts[:response_model], %{title: "Hello", summary: "World", tags: [], sections: []})}
    end)

    assert {:ok, response} = MyApp.Agents.PostsWritePost.call("Phoenix")
    assert response.title == "Hello"
  end
end
```

## Notes

- Keep `MyApp.Agents` as the single source of truth for model strings and API keys.
- Keep each agent focused on one task, not one whole domain.
- Prefer a task-specific module like `MyApp.Agents.PostsWritePost` over a generic `MyApp.Agents.Posts`.
