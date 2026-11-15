# SaaS Platform Docs

The golden-path documentation for the SaaS internal developer platform (this Backstage
portal, the GitOps control plane, and the application microservices).

## Sections

- **[AI guardrails golden path](ai-platform-guardrails.md)** — how the platform governs its AI
  agent service: the memory harness, the tool-authorization gate, the input/output guardrails,
  and per-tenant budgets, and how to configure them self-service from the portal.

## The golden path

A developer scaffolds a service (or configures it) with a single merge — Backstage only writes
Git, and ArgoCD does every apply. See the repository README for the full picture and the
`/create` templates for the self-service entry points.
