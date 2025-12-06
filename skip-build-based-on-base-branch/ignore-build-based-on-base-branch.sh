#!/bin/bash
set -euo pipefail

echo "=== ignore-build-based-on-base-branch start ==="

# Vercel system env vars
ENV="${VERCEL_ENV:-}"
BRANCH="${VERCEL_GIT_COMMIT_REF:-}"
REPO_OWNER="${VERCEL_GIT_REPO_OWNER:-}"
REPO_SLUG="${VERCEL_GIT_REPO_SLUG:-}"
HEAD_SHA="${VERCEL_GIT_COMMIT_SHA:-}"

# Your configuration (must be set via Vercel env var)
# Example value: "my-integration-branch"
BASE_BRANCH="${IGNORE_BASE_BRANCH_NAME:-}"

echo "PWD: $(pwd)"
echo "VERCEL_ENV: $ENV"
echo "VERCEL_GIT_COMMIT_REF: $BRANCH"
echo "VERCEL_GIT_COMMIT_SHA: ${HEAD_SHA:-<empty>}"
echo "VERCEL_GIT_REPO_OWNER: ${REPO_OWNER:-<unset>}"
echo "VERCEL_GIT_REPO_SLUG: ${REPO_SLUG:-<unset>}"
echo "IGNORE_BASE_BRANCH_NAME: ${BASE_BRANCH:-<unset>}"

echo "=== decision phase ==="

# If not configured at all, always build
if [ -z "$BASE_BRANCH" ]; then
  echo "[warn] IGNORE_BASE_BRANCH_NAME is not set -- build"
  echo "=== ignore-build-based-on-base-branch end ==="
  exit 1
fi

# Optional: always build in production
if [ "$ENV" = "production" ]; then
  echo "[decision] ENV=production -- build"
  echo "=== ignore-build-based-on-base-branch end ==="
  exit 1
fi

# 1) If current branch is the base branch itself, skip
if [ "$BRANCH" = "$BASE_BRANCH" ]; then
  echo "[decision] On base branch '$BASE_BRANCH' -- skip build"
  echo "=== ignore-build-based-on-base-branch end ==="
  exit 0
fi

have_github_context() {
  [ -n "${GITHUB_TOKEN:-}" ] && [ -n "$REPO_OWNER" ] && [ -n "$REPO_SLUG" ]
}

# 2) Use GitHub compare API to see if base is an ancestor of HEAD
if have_github_context && [ -n "$HEAD_SHA" ]; then
  # URL encode the base branch so names with slashes work
  BASE_ENC="${BASE_BRANCH//\//%2F}"

  echo "Using GitHub compare API to see if '$BASE_BRANCH' is ancestor of HEAD ($HEAD_SHA)..."
  COMPARE_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_SLUG/compare/$BASE_ENC...$HEAD_SHA"
  echo "Compare URL base: $COMPARE_URL"

  COMPARE_RESPONSE="$(curl -s -w '\n%{http_code}' \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "$COMPARE_URL" || echo "")"

  if [ -z "$COMPARE_RESPONSE" ]; then
    echo "[warn] Empty response from GitHub compare API -- build"
    echo "=== ignore-build-based-on-base-branch end ==="
    exit 1
  fi

  COMPARE_STATUS_CODE="${COMPARE_RESPONSE##*$'\n'}"
  COMPARE_JSON="${COMPARE_RESPONSE%$'\n'$COMPARE_STATUS_CODE}"

  echo "GitHub compare HTTP status: ${COMPARE_STATUS_CODE}"

  if [ "$COMPARE_STATUS_CODE" != "200" ]; then
    echo "[warn] GitHub compare failed with status ${COMPARE_STATUS_CODE}, response:"
    echo "$COMPARE_JSON" | head -c 400 || true
    echo
    echo "-- falling back to build"
    echo "=== ignore-build-based-on-base-branch end ==="
    exit 1
  fi

  COMPARE_LOGICAL_STATUS="$(
    echo "$COMPARE_JSON" | node -e '
      let s = "";
      process.stdin.on("data", c => s += c);
      process.stdin.on("end", () => {
        try {
          const obj = JSON.parse(s);
          console.log(obj.status || "");
        } catch (e) {
          console.log("");
        }
      });
    '
  )"

  echo "GitHub compare status (BASE...HEAD): '${COMPARE_LOGICAL_STATUS}'"

  # For base...head:
  # - "ahead"      -> head is ahead of base (base is ancestor)
  # - "identical"  -> same commit
  # - "behind"     -> head is behind base
  # - "diverged"   -> no direct ancestry
  if [ "$COMPARE_LOGICAL_STATUS" = "ahead" ] || [ "$COMPARE_LOGICAL_STATUS" = "identical" ]; then
    echo "[decision] HEAD is based on '$BASE_BRANCH' (status: $COMPARE_LOGICAL_STATUS) -- skip build"
    echo "=== ignore-build-based-on-base-branch end ==="
    exit 0
  else
    echo "[info] Base branch is not a strict ancestor of HEAD (status: $COMPARE_LOGICAL_STATUS) -- build"
    echo "=== ignore-build-based-on-base-branch end ==="
    exit 1
  fi
fi

# 3) Fallback: no GitHub context -- build
echo "[info] Not on base branch, and no usable GitHub compare context -- build"
echo "=== ignore-build-based-on-base-branch end ==="
exit 1