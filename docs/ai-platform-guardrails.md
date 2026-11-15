# AI guardrails golden path

The platform's AI capability is the **agent-service** (a Spring Boot, hexagonal AI service:
LangChain4j, pgvector RAG, event-sourced conversations). Running an LLM agent for multiple
tenants is a governance problem as much as a modelling one — what the agent *remembers*, what it
is allowed to *do*, what may cross the *model boundary*, and what it may *spend*. The agent
service handles each with the **harness + policy** pattern, and this portal is where you
configure and observe it.

## The four governed boundaries

| Boundary | Harness | Decision point | On violation |
| --- | --- | --- | --- |
| **Memory** | `AgentMemoryHarness` | `agent/memory` (OPA) | drop a recalled passage / skip a persist |
| **Tools** | `AgentToolHarness` | `agent/tools` (OPA) | reject the tool (enable) / block the call (invoke) |
| **Model I/O** | `AgentGuardrailHarness` | `agent/io` (OPA) | fail the turn (input 400 / output 422) |
| **Spend** | `AgentBudgetGuard` | in-process ceilings | refuse the turn (429) |

Each boundary is **off by default** and backed in production by an Open Policy Agent (OPA)
sidecar evaluating a Rego bundle — the same policy-as-code engine the platform already runs in
CI to lint Dockerfiles. Turning a boundary on is a configuration change delivered through
GitOps, never a redeploy of new rules.

```
  user ─▶ guardInput ─▶ memory recall (gated) ─▶ LLM ─▶ tool calls (gated) ─▶ guardOutput ─▶ answer
            │                   │                            │                     │
          agent/io         agent/memory                  agent/tools           agent/io
         (injection)       (recall policy)            (authorization)       (leakage, grounding)
                                                                                  │
                                                            budget check ◀────────┘ (spend ceiling)
```

## What each boundary does

- **Memory** — a recalled passage that a tenant may not see, or an assistant message that looks
  like a credential or is under a no-retention contract, never enters long-term memory.
- **Tools** — tools are the agent's highest-risk surface. A tool must be both *supported* by the
  build and *authorized* by policy: per-tenant allow/deny-lists, a `code_interpreter`
  entitlement, and an SSRF guard that refuses a `web_search` aimed at an internal or
  cloud-metadata host.
- **Model I/O** — the user's message is screened for prompt-injection / jailbreak before it
  reaches the model; the answer is screened for leakage and a minimum-grounding floor before it
  is returned and remembered.
- **Spend** — each turn's tokens and cost accumulate per conversation (per tenant once identity
  is threaded end-to-end); a conversation over its ceiling is refused before any LLM spend.

## Configure it from the portal

Use the **Configure AI Agent Guardrails** template under `/create`:

1. Pick the agent service and the governance you want — tool allow-list, token/cost budget, and
   whether input/output screening runs fail-open or fail-closed.
2. The template generates the agent-service governance values overlay and an OPA tenant data
   document, and opens a PR to `SAAS-Continious-Delivery`.
3. On merge, ArgoCD reconciles the overlay; the new ceilings and allow-lists take effect with no
   redeploy of code.

To stand up a **new** AI agent with guardrails wired from day one, use **New AI Agent (golden
path)** under `/create`.

## Observe it

The harnesses emit through the platform's OTLP pipeline:

- `agent.memory.policy.decisions`, `agent.tools.policy.decisions`, `agent.guardrail.decisions`
  — tagged by outcome (allow/deny); a rising deny rate means a boundary is actively protecting.
- `*.unavailable` counters — increment when a policy engine is unreachable and the harness falls
  back to its configured posture; alert on any sustained rate.

Circuit-breaker state for each OPA call (`memoryPolicy`, `toolPolicy`, `guardrailPolicy`) is on
the service's `/actuator/health`, so an open governance circuit is visible to ops and to ArgoCD.

## Reference

Full design notes live in the agent-service repository: `docs/agent-memory-harness.md` and
`docs/agent-guardrails.md`.
