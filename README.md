# vercel-recipes

A collection of small, practical Vercel deployment recipes.
Each recipe solves a real problem we've faced and may be useful for others.

Recipes are self-contained and include:

- scripts or configs you can copy into your repo
- step-by-step setup guides
- required environment variables
- real-world usage patterns

---

## Recipes

### 1. E2E testing against Vercel preview deployments

**Folder:** [`e2e-setup`](./e2e-setup)

Run Playwright E2E tests automatically for every PR against Vercel preview deployments.

This setup includes:

- Vercel → GitHub relay (webhook bridge)
- GitHub App for check runs
- reusable GitHub Action (`e2e-test-runner`)
- Playwright integration with Vercel protection bypass

**What it gives you:**

- automatic E2E tests on every PR
- results reported as GitHub Checks
- Playwright HTML report uploaded as artifact
- support for protected Vercel deployments

---

### 2. Skip builds for a base branch and its stacked branches

**Folder:** [`skip-build-based-on-base-branch`](./skip-build-based-on-base-branch)

Skip Vercel builds when the deployment is on a specific branch (e.g. a migration or integration branch) or on any branch based on it.

Useful for:

- monorepos with deprecated apps
- long-lived integration branches
- reducing unnecessary Vercel usage

---

## Philosophy

These recipes are:

- **minimal** -- no unnecessary abstraction
- **copy-paste friendly** -- easy to adopt
- **battle-tested** -- used in real production setups
- **composable** -- can be combined across projects
