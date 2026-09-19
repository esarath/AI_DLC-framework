# 08 — Jira Integration

**Board:** https://adminebooks.atlassian.net/jira/software/projects/KAN/boards/1

## Workflow mapping

| Jira status | Repo/pipeline event |
|-------------|---------------------|
| To Do → In Progress | Dev opens branch/PR titled `KAN-n: ...` |
| In Progress → In Review | PR opened; AI triage + CI checks run |
| In Review → In Staging | `cd-promote` to stage succeeds (auto-transition) |
| In Staging → Done | `cd-promote` to prod succeeds (auto-transition) |

## Issue-key discipline

- Every branch/PR/commit references `KAN-<n>`; `ai-pr-triage.yml` flags PRs missing a key.
- `cd-promote.yml` requires the `jira_issue` input and embeds it in the GitOps commit message —
  every deployment is traceable: Jira issue ↔ git commit ↔ image digest ↔ ArgoCD revision.

## Secrets required

```
JIRA_BASE_URL    = https://adminebooks.atlassian.net
JIRA_USER_EMAIL  = <service-account email>
JIRA_API_TOKEN   = <token from id.atlassian.com/manage-profile/security/api-tokens>
```

## How transitions are executed

`atlassian/gajira-login` authenticates once per job; `atlassian/gajira-transition` moves the issue.
Prod promotion additionally validates the issue exists (`gajira-find-issue-key`) before any infra
is touched — extend this to a JQL status check (e.g. `status = "Approved for Release"`) for a hard
approval gate.

## Automation ideas (Jira → repo direction)

- Jira Automation rule: when issue moves to "Approved for Release" → trigger GitHub
  `workflow_dispatch` via webhook (repository dispatch) for hands-free promotion.
- Deployment comments: add `gajira-comment` steps posting image tag + ArgoCD revision onto the
  issue after each deploy (comment stub included in `cd-promote.yml` flow).
- Smart commits: `KAN-12 #comment deployed sha-abc1234 to stage` in commit messages auto-comment
  on the Jira issue.
