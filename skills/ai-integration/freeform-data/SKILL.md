---
name: freeform-data
description: Build raw LLM helpers for text, code, markdown, and opportunistic JSON using Req. Use when output does not need a strict response schema.
user-invocable: true
---

# Freeform Data

Use this skill when an AI feature should return text, code, markdown, or loose JSON instead of a validated schema.

## Goal

- Reuse the shared `MyApp.Agents` configuration.
- Keep a low-level `MyApp.Agents.LLM` module for provider-specific requests.
- Let task-specific modules build on top of that helper.
- Keep tests isolated with Mimic.

## Root Agents Module

Use one shared root module for API keys and model names:

```elixir
defmodule MyApp.Agents do
  @moduledoc """
  Central configuration for AI agents.
  """

  def anthropic_key, do: Application.get_env(:my_app, :anthropic)[:api_key]
  def openai_key, do: Application.get_env(:my_app, :openai)[:api_key]

  def model(:haiku), do: "claude-haiku-4-5"
  def model(:sonnet), do: "claude-sonnet-4-5"
  def model(:gpt_5_mini), do: "gpt-5-mini"
  def model(:gpt_5), do: "gpt-5.2"
  def model(:gpt_4_1_mini), do: "gpt-4.1-mini"
end
```

## Credential Placement

Do not put provider credentials in shared `config/config.exs`.
Keep local credentials in `config/dev.exs`:

```elixir
config :my_app, :anthropic, api_key: System.get_env("ANTHROPIC_API_KEY")
config :my_app, :openai, api_key: System.get_env("OPENAI_API_KEY")
```

## Low-level LLM Module

Keep one shared helper module for raw LLM calls:

```elixir
defmodule MyApp.Agents.LLM do
  import MyApp.Agents

  @claude_url "https://api.anthropic.com/v1/messages"
  @openai_url "https://api.openai.com/v1/chat/completions"

  def claude(content, opts \\ [])

  def claude("" <> content, opts) do
    [%{role: "user", content: content}]
    |> claude(opts)
  end

  def claude(messages, opts) when is_list(messages) do
    model_name = Keyword.get(opts, :model, model(:haiku))
    max_tokens = Keyword.get(opts, :max_tokens, 4_096)
    extract_code = Keyword.get(opts, :extract_code, false)
    extract_json = Keyword.get(opts, :extract_json, false)

    Req.post(@claude_url,
      headers: [
        {"Content-Type", "application/json"},
        {"x-api-key", anthropic_key()},
        {"anthropic-version", "2023-06-01"}
      ],
      receive_timeout: 90_000,
      json: %{
        max_tokens: max_tokens,
        model: model_name,
        messages: messages
      }
    )
    |> parse()
    |> maybe_extract_code(extract_code)
    |> maybe_extract_json(extract_json)
  end

  def openai(content, opts \\ [])

  def openai("" <> content, opts) do
    [%{role: "user", content: content}]
    |> openai(opts)
  end

  def openai(messages, opts) when is_list(messages) do
    model_name = Keyword.get(opts, :model, model(:gpt_5_mini))
    reasoning_effort = Keyword.get(opts, :reasoning_effort, "medium")
    max_tokens = Keyword.get(opts, :max_tokens, 4_096)
    extract_code = Keyword.get(opts, :extract_code, false)
    extract_json = Keyword.get(opts, :extract_json, false)
    prediction = Keyword.get(opts, :prediction)

    Req.post(@openai_url,
      headers: [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{openai_key()}"}
      ],
      receive_timeout: 90_000,
      json:
        %{
          model: model_name,
          max_completion_tokens: max_tokens,
          messages: messages
        }
        |> maybe_add_reasoning_effort(reasoning_effort, model_name)
        |> maybe_add_prediction(prediction)
    )
    |> parse()
    |> maybe_extract_code(extract_code)
    |> maybe_extract_json(extract_json)
  end

  defp maybe_add_prediction(json, "" <> content) do
    json
    |> Map.delete(:max_completion_tokens)
    |> Map.put(:prediction, %{content: content, type: "content"})
    |> Map.put(:model, model(:gpt_4_1_mini))
  end

  defp maybe_add_prediction(json, _), do: json

  defp maybe_add_reasoning_effort(json, "" <> reasoning_effort, model_name)
       when model_name in [model(:gpt_5), "o4-mini", "o3", "o3-mini"] do
    Map.put(json, :reasoning_effort, reasoning_effort)
  end

  defp maybe_add_reasoning_effort(json, _, _), do: json

  defp parse({:ok, %{body: %{"content" => [content | _]}}}) do
    case content do
      %{"text" => text, "type" => type} -> {:ok, %{content: text, type: type}}
      _ -> {:error, %{content: "No result"}}
    end
  end

  defp parse({:ok, %{body: %{"choices" => [choice | _]}}}) do
    case choice do
      %{"message" => %{"content" => content}} -> {:ok, %{content: content}}
      _ -> {:error, %{content: "No result"}}
    end
  end

  defp parse(_), do: {:error, %{content: "No result"}}

  defp maybe_extract_code({:ok, %{content: content}}, true) do
    {:ok, %{content: extract_code(content)}}
  end

  defp maybe_extract_code(result, _), do: result

  defp maybe_extract_json({:ok, %{content: content}}, true) do
    {:ok, %{content: extract_json(content)}}
  end

  defp maybe_extract_json(result, _), do: result

  defp extract_code(content) do
    content
    |> String.replace("```elixir", "```")
    |> String.replace("```javascript", "```")
    |> String.replace("```json", "```")
    |> String.trim()
    |> String.split("```")
    |> case do
      [_, code | _] -> code
      [text] -> text
    end
  end

  def extract_json(text_or_json) do
    text_or_json
    |> String.replace("```json", "```")
    |> String.trim()
    |> String.split("```")
    |> case do
      [_, json | _] -> json
      [json] -> json
    end
    |> Jason.decode!()
  rescue
    _ -> %{}
  end
end
```

## Task-specific Modules

Keep task logic in a separate `MyApp.Agents.*` module instead of embedding prompts directly into controllers or contexts.

```elixir
defmodule MyApp.Agents.PostsWritePost do
  alias MyApp.Agents.LLM

  @system_prompt """
  You write concise, practical blog posts for developers.
  """

  def call(topic) do
    [
      %{role: "system", content: @system_prompt},
      %{role: "user", content: "Write a draft about #{topic}"}
    ]
    |> LLM.claude(extract_code: false)
  end
end
```

## When to Use Freeform Data

- The output is prose, markdown, or code.
- You only need light post-processing like extracting fenced code or JSON.
- The result is meant for human review before further use.
- A strict `embedded_schema` would add unnecessary friction.

## Testing

Test `MyApp.Agents.LLM` and task-specific callers with Mimic so tests do not hit external APIs.
If the module calls `Req` directly, mock `Req`:

```elixir
# test/test_helper.exs
Mimic.copy(Req)
ExUnit.start()
```

```elixir
defmodule MyApp.Agents.LLMTest do
  use MyApp.DataCase, async: true
  use Mimic

  test "returns parsed content from Claude" do
    Req
    |> expect(:post, fn _url, opts ->
      send(self(), {:req_called, opts[:json][:model]})
      {:ok, %{body: %{"content" => [%{"type" => "text", "text" => "Hello"}]}}}
    end)

    assert {:ok, %{content: "Hello"}} = MyApp.Agents.LLM.claude("Say hello")
    assert_received {:req_called, _}
  end
end
```

## Notes

- Use `MyApp.Agents.LLM` for raw provider access and common parsing helpers.
- Use `MyApp.Agents.TopicSomeAction` modules for business-facing prompts.
- Pull model defaults from `MyApp.Agents.model/1`, not hardcoded strings inside the LLM module.
- If a workflow becomes schema-heavy or validation-heavy, move it to the structured-data pattern.
