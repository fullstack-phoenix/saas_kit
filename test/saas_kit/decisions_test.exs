defmodule SaasKit.DecisionsTest do
  use ExUnit.Case, async: true

  alias SaasKit.Decisions

  @feature %{
    "slug" => "payments",
    "decisions" => [
      %{
        "key" => "provider",
        "question" => "Which payment provider?",
        "required" => true,
        "options" => [
          %{"slug" => "stripe_subscription", "name" => "Stripe Subscription"},
          %{"slug" => "paddle_subscription", "name" => "Paddle Subscription"}
        ]
      }
    ]
  }

  test "parses explicit decision arguments" do
    assert Decisions.parse_args!(["provider=stripe_subscription"]) == %{
             "provider" => "stripe_subscription"
           }
  end

  test "rejects malformed decision arguments" do
    assert_raise Mix.Error, ~r/Expected key=option_slug/, fn ->
      Decisions.parse_args!(["stripe_subscription"])
    end
  end

  test "keeps a valid supplied decision without prompting" do
    chooser = fn _decision -> flunk("should not prompt for supplied values") end

    assert Decisions.resolve(@feature, %{"provider" => "stripe_subscription"}, chooser) == %{
             "provider" => "stripe_subscription"
           }
  end

  test "uses the chooser for unresolved decisions" do
    assert Decisions.resolve(@feature, %{}, fn decision ->
             assert decision["key"] == "provider"
             "paddle_subscription"
           end) == %{"provider" => "paddle_subscription"}
  end

  test "rejects decisions or options not declared by the feature" do
    assert_raise Mix.Error, ~r/does not declare decision 'tier'/, fn ->
      Decisions.resolve(@feature, %{"tier" => "pro"}, fn _ -> nil end)
    end

    assert_raise Mix.Error, ~r/Invalid choice 'other'/, fn ->
      Decisions.resolve(@feature, %{"provider" => "other"}, fn _ -> nil end)
    end
  end

  test "encodes decisions and a resume step into an install URL" do
    url =
      Decisions.install_url(
        "https://example.test/api/install/payments",
        "step-1",
        %{"provider" => "stripe_subscription"}
      )

    assert URI.decode_query(URI.parse(url).query) == %{
             "decisions[provider]" => "stripe_subscription",
             "step" => "step-1"
           }
  end
end

defmodule SaasKit.ProjectSetupTest do
  use ExUnit.Case, async: false

  alias SaasKit.AgentSkills
  alias SaasKit.ProjectConfig

  setup do
    cwd = File.cwd!()

    tmp_dir =
      Path.join(System.tmp_dir!(), "saas_kit_project_test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    File.cd!(tmp_dir)

    on_exit(fn ->
      File.cd!(cwd)
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  test "creates initial local configuration without overwriting existing state" do
    assert :created = ProjectConfig.ensure_initial_file()
    assert File.read!(".saaskit.yml") == "initial_install: false\n"

    File.write!(".saaskit.yml", "initial_install: true\n")
    assert :exists = ProjectConfig.ensure_initial_file()
    assert File.read!(".saaskit.yml") == "initial_install: true\n"
  end

  test "installs guidance for common coding assistants" do
    assert :ok = AgentSkills.install()

    assert File.read!(".claude/skills/saaskit/SKILL.md") =~ "mix saaskit.feature.install"
    assert File.read!(".codex/skills/saaskit/SKILL.md") =~ "--decision <key>=<option_slug>"
    assert File.read!(".cursor/rules/saaskit.mdc") =~ "alwaysApply: true"
    assert File.read!(".github/instructions/saaskit.instructions.md") =~ ~s(applyTo: "**")
  end
end
