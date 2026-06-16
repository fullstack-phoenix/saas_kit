---
name: ai-integration
description: Use when adding LLM features to Phoenix and Elixir apps. Covers shared agent configuration, module naming, structured outputs, and freeform text/code generation.
---

# AI Integration

Use this folder when adding LLM-backed features to an application.

## Rules

1. Centralize provider keys and model names in `MyApp.Agents`.
2. Keep task-specific modules under `MyApp.Agents.*` so they are easy to scan in code search and editor symbol lists.
3. Use a topic-and-action naming style such as `MyApp.Agents.PostsWritePost`.
4. Use structured outputs when downstream code expects validated fields.
5. Use freeform outputs when downstream code expects prose, code, markdown, or loose JSON.
6. Test provider calls and boundary modules with Mimic instead of hitting real services.
7. Do not store provider credentials in shared `config/config.exs`; keep them in `config/dev.exs`.

## Read Next

- For validated, typed outputs with `InstructorLite`, read [`structured-data/SKILL.md`](/Users/andreaseriksson/Sites/SKILLS/ai-integration/structured-data/SKILL.md).
- For raw text, code, and JSON extraction helpers, read [`freeform-data/SKILL.md`](/Users/andreaseriksson/Sites/SKILLS/ai-integration/freeform-data/SKILL.md).
