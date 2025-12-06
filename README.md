# vercel-recipes

A collection of small, practical Vercel deployment recipes.
Each recipe solves a real problem we've faced and may be useful for others.

Recipes live in their own folders and include:

-   a script you can copy into your repo
-   a short guide on how to use it with Vercel
-   required environment variables
-   setup instructions

## Recipes

### 1. Skip builds for a base branch and its stacked branches

**Folder:** [`skip-build-based-on-base-branch`](./skip-build-based-on-base-branch)

Skip Vercel builds when the deployment is on a specific branch (e.g. a migration or integration branch) or on any branch based on it. Useful for monorepos, deprecated apps, or branches that shouldn’t trigger deployments.
