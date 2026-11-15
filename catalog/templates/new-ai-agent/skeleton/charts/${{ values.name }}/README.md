# ${{ values.name }} — AI agent (golden path)

${{ values.description }}

Scaffolded by the **New AI Agent** Backstage template with the guardrail harness pre-wired.

## Files

| File | Purpose |
| --- | --- |
| `catalog-info.yaml` | `Component` of type `ai-service` in the `ai-platform` system |
| `ai-guardrails.values.yaml` | OPA sidecar + harness env (memory / tools / I/O / budget all on) |
| `policy/tenant-governance.json` | starter OPA tenant data document (tool allow-list, budget, grounding) |

## Wiring

1. **Base chart** — this is a governance overlay, not a full chart. Run the **New Microservice**
   template for `${{ values.name }}` to generate the standard chart (Argo Rollout, KEDA, Istio,
   probes), or merge both PRs together.
2. **Values** — add `ai-guardrails.values.yaml` to the service's Argo CD Application
   `valueFiles`, after the base `values.yaml`.
3. **Policy bundle** — the OPA sidecar mounts the shared `agent/memory`, `agent/tools`,
   `agent/io` Rego bundle (from the agent-service repo) plus `policy/tenant-governance.json` as
   ConfigMaps. Provide `${{ values.name }}-agent-policy` and `${{ values.name }}-opa-config`.

Guardrails ship **on** here (unlike the agent-service defaults, which are off) because a new
agent should be governed from its first request. Tune ceilings and allow-lists later with the
**Configure AI Agent Guardrails** template.

See TechDocs: **AI guardrails golden path**.
