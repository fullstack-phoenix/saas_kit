defmodule SaasKit.Task.Helpers do
  @moduledoc """
  Shared helpers for SaaS Kit Mix tasks.

  Centralizes the human/JSON output split. Every read-only task parses
  `--json` via `parse_opts/2`, flips into JSON mode with `enter_json_mode/1`,
  and emits its final payload via `emit/3` or `fail!/4`.

  JSON documents always include a stable `schema_version` and `ok` flag so
  agents can rely on the shape. Stable error codes used across tasks:

    * `not_configured`   — `boilerplate_token` missing from config
    * `api_unreachable`  — API call failed (timeout, 5xx, network)
    * `feature_not_found` — requested feature slug does not exist
  """

  @schema_version 1

  @doc """
  Parses task args with `--json` layered on top of task-specific switches.
  """
  def parse_opts(args, extra_switches \\ []) do
    switches = Keyword.merge([json: :boolean], extra_switches)

    case OptionParser.parse(args, switches: switches) do
      {opts, rest, _} -> {opts, rest}
      _ -> {[], []}
    end
  end

  @doc """
  When `--json` is set, silence `Mix.shell().info/1` so stdout stays pure JSON.
  Returns `opts` unchanged for pipelining.
  """
  def enter_json_mode(opts) do
    if opts[:json], do: Mix.shell(Mix.Shell.Quiet)
    opts
  end

  @doc """
  Prints human-readable text, but only when not in `--json` mode.
  """
  def human(msg, opts) do
    unless opts[:json], do: Mix.shell().info(msg)
  end

  @doc """
  Emits the final result.

  In `--json` mode: merges `schema_version` and `ok: true` into the payload
  and prints it as one JSON line to stdout.

  Otherwise: invokes `human_fn` with the raw payload to pretty-print.
  """
  def emit(payload, opts, human_fn) when is_map(payload) and is_function(human_fn, 1) do
    if opts[:json] do
      payload
      |> Map.merge(%{schema_version: @schema_version, ok: true})
      |> Jason.encode!()
      |> IO.puts()
    else
      human_fn.(payload)
    end
  end

  @doc """
  Emits a structured failure and halts with `exit_code`.

  In `--json` mode: `{"schema_version":1,"ok":false,"error":{"code":...,"message":...}}`
  Otherwise: `Mix.shell().error(message)`.
  """
  def fail!(code, message, opts, exit_code \\ 1) do
    if opts[:json] do
      %{
        schema_version: @schema_version,
        ok: false,
        error: %{code: to_string(code), message: message}
      }
      |> Jason.encode!()
      |> IO.puts()
    else
      Mix.shell().error(message)
    end

    System.halt(exit_code)
  end

  @doc "Current JSON schema version. Exposed for tests and docs."
  def schema_version, do: @schema_version
end
