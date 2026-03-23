# E2E Setup Guide

This guide explains how to run Playwright E2E tests automatically against Vercel preview deployments using our tooling.

## Overview

Flow:

1. PR triggers Vercel preview deployment
2. Vercel sends webhook to Relay
3. Relay triggers GitHub workflow + creates check
4. GitHub Actions runs Playwright against preview URL
5. Result appears on PR

---

## Prerequisites

- Vercel project
- GitHub repository
- Playwright tests working locally
- Ability to create GitHub App

---

## 1. Create GitHub App

Permissions:

- Checks: Read & Write
- Actions: Read & Write
- Contents: Read

Save:

- GH_APP_ID
- GH_APP_PRIVATE_KEY

Normalize private key:

```bash
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0}' private-key.pem
```

---

## 2. Deploy Relay

Deploy:

[technance-foundation/vercel-to-github-relay](https://github.com/technance-foundation/vercel-to-github-relay)

Set env:

```env
VERCEL_WEBHOOK_SECRET=your-secret
GH_OWNER=your-org
GH_REPO=your-repo
GH_APP_ID=123
GH_APP_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

---

## 3. Configure Vercel Webhook

Event: deployment.succeeded

Endpoint:

```txt
https://<relay-domain>/api/vercel-to-github-success-deployment
```

Use same webhook secret as Relay.

---

## 4. Add Project Config

Create:

```
.github/e2e-projects.json
```

Example:

```json
{
    "projects": {
        "prj_xxx": {
            "project": "midnight-v2",
            "workingDirectory": "apps/midnight",
            "testCommand": "pnpm run test:e2e",
            "checkName": "Midnight"
        }
    }
}
```

---

## 5. Add GitHub Workflow

Create:

```
.github/workflows/e2e.yaml
```

```yaml
name: E2E Tests

on:
    workflow_dispatch:
        inputs:
            url: { required: true }
            project: { required: true }
            check_run_id: { required: true }
            working_directory: { required: true }
            test_command: { required: true }

permissions:
    contents: read
    checks: write
    actions: read

jobs:
    test-e2e:
        runs-on: ubuntu-latest

        steps:
            - uses: actions/checkout@v4

            - name: Generate GitHub App token
              id: app-token
              uses: tibdex/github-app-token@v2
              with:
                  app_id: ${{ vars.GH_APP_ID }}
                  private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}

            - name: Run E2E
              uses: technance-foundation/github-actions/e2e-test-runner@main
              env:
                  VERCEL_AUTOMATION_BYPASS_SECRET: ${{ secrets.VERCEL_AUTOMATION_BYPASS_SECRET }}
              with:
                  token: ${{ steps.app-token.outputs.token }}
                  check-run-id: ${{ inputs.check_run_id }}
                  project: ${{ inputs.project }}
                  preview-url: ${{ inputs.url }}
                  working-directory: ${{ inputs.working_directory }}
                  test-command: ${{ inputs.test_command }}
```

---

## 6. Playwright Config

Ensure bypass header is set:

```ts
const secret = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;

use: {
  ...(secret
    ? {
        extraHTTPHeaders: {
          "x-vercel-protection-bypass": secret,
        },
      }
    : {}),
}
```

---

## 7. Vercel Protection (if enabled)

In Vercel:

Settings → Deployment Protection → Protection Bypass for Automation

Create bypass.

Then add same value to GitHub secrets:

```
VERCEL_AUTOMATION_BYPASS_SECRET
```

---

## 8. Turbo (if used)

Ensure env is passed:

```json
{
    "globalEnv": ["VERCEL_AUTOMATION_BYPASS_SECRET"]
}
```

---

## 9. Debugging

### Env undefined

- Secret not passed in workflow
- Turbo stripping env

### Page not loading

- Protection enabled without bypass header
- Wrong preview URL

### Relay 401

- Webhook secret mismatch

### Relay 502

- GitHub App misconfigured

---

## 10. Checklist

- GitHub App created + installed
- Relay deployed with env
- Vercel webhook configured
- Workflow added
- Project config added
- Secret added to GitHub
- Playwright config includes header

---

## Result

Every PR automatically:

- runs E2E tests
- reports status in GitHub checks
- attaches Playwright report
