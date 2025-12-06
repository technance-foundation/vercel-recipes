# Skip Vercel builds for a base branch and its stacked branches

This recipe lets you tell Vercel:

> "Do not build this project when the commit is on branch X or any branch based on X."

Example: you have a long lived integration branch like `my-integration-branch` and you do not want a specific Vercel project (for example a deprecated template or app) to build for that branch or anything stacked on top of it, but you still want normal builds for `main` and other feature branches.

The script:

-   always builds in `production` (configurable),
-   skips builds for the configured base branch itself,
-   uses the GitHub Compare API to detect whether `HEAD` is ahead of or identical to the base branch,
-   skips those builds by exiting with code `0` in the Ignored Build Step.

---

## Requirements

-   A Vercel project connected to GitHub.
-   System env vars available in the Ignored Build Step:
    -   `VERCEL_ENV`
    -   `VERCEL_GIT_COMMIT_REF`
    -   `VERCEL_GIT_COMMIT_SHA`
    -   `VERCEL_GIT_REPO_OWNER`
    -   `VERCEL_GIT_REPO_SLUG`
-   A GitHub Personal Access Token with **read** permissions on the repo.

### GitHub token permissions

Fine grained PAT:

-   Repository access:
    -   Only selected repositories → your repo (for example `technance-foundation/technance-platform-frontend`)
-   Repository permissions:
    -   Contents: `Read`
    -   Pull requests: `Read`

Classic PAT (for private repos):

-   Scope: `repo`

---

## Step 1 -- add the script to your repo

Copy this file into your project, for example:

-   from this repo: `skip-build-based-on-base-branch/ignore-build-based-on-base-branch.sh`
-   into your app repo: `scripts/ignore-build-based-on-base-branch.sh`

Then:

```bash
chmod +x scripts/ignore-build-based-on-base-branch.sh
git add scripts/ignore-build-based-on-base-branch.sh
git commit -m "Add ignore-build-based-on-base-branch script for Vercel"
git push
```

---

## Step 2 -- configure environment variables in Vercel

In your Vercel project:

Go to `Settings -- Environment Variables`.

Add:

### `GITHUB_TOKEN`

-   Value: your GitHub Personal Access Token.
-   Target: at least `Preview`.

### `IGNORE_BASE_BRANCH_NAME`

-   Value: the branch you want to treat as the base, for example:

    ```txt
    my-integration-branch
    ```

-   Target: at least `Preview`.

> This variable is required. If `IGNORE_BASE_BRANCH_NAME` is not set, the script logs a warning and always builds:
>
> `"[warn] IGNORE_BASE_BRANCH_NAME is not set -- build"`

Make sure `Automatically expose System Environment Variables` is enabled so `VERCEL_*` vars are visible to the script.

---

## Step 3 -- wire it into the Ignored Build Step

In the same Vercel project:

1. Go to `Settings -- Git`.
2. In `Ignored Build Step`:

    - choose `Run my Bash script`,
    - set the command relative to your Root Directory.

Examples:

If your Root Directory is the repo root:

```bash
bash scripts/ignore-build-based-on-base-branch.sh
```

If your Root Directory is a sub app e.g. `apps/sub-app`:

```bash
bash ../../scripts/ignore-build-based-on-base-branch.sh
```

Save the settings.

---

## How it behaves

Assuming:

```txt
IGNORE_BASE_BRANCH_NAME=<your-base-branch-name>
```

For example:

```txt
IGNORE_BASE_BRANCH_NAME=my-integration-branch
```

### On the base branch

When `VERCEL_GIT_COMMIT_REF` equals `IGNORE_BASE_BRANCH_NAME`:

-   script exits `0` → Vercel **skips** the build for that deployment.

### On any branch based on that base branch

For example a `testing` branch created from your integration branch.

-   GitHub Compare API for `<base>...HEAD_SHA` returns:

    -   `status: "ahead"` or `status: "identical"`,

-   script exits `0` → Vercel **skips** the build.

### On any branch that is not based on that branch

For example `main` or an unrelated feature branch:

-   Compare status is `"behind"` or `"diverged"`,
-   script exits `1` → Vercel runs the build as usual.

### If the GitHub token is misconfigured or GitHub is unreachable

-   script logs a warning and exits `1` → Vercel runs the build (fail safe).

---

## Notes

-   Works for both branch deployments and PR deployments because it looks at commit ancestry, not PR metadata.
-   Supports branch names with slashes (like `feature/migration-phase-1` or `migration/phase-2`) by URL encoding before calling GitHub.
-   You can reuse the same script across multiple Vercel projects:

    -   share the script file,
    -   configure different `IGNORE_BASE_BRANCH_NAME` values per project.
