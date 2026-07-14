#!/usr/bin/env bash
# open-contribback-code-pr.sh — CODE-lane contribute-back opener. Promotes an
# ALREADY-MERGED customer-authored detector (detectors/<name>/) into the shared
# OSS corpus (core/detect/authored/<name>/) as a REVIEW-ONLY upstream PR under the
# OPERATOR's OWN token. It is the runtime sibling of open-proposal-pr.sh and the
# shell twin of internal/selfext/contribback (LoadCodeArtifact / ossDestFor).
#
# HARD LINES (mirroring the reusable workflow's contribute_back job, R3/R8):
#   - It opens a PR to the shared OSS repo from the operator's OWN fork/identity
#     (secrets.oss_contrib_token) — mallcop-pro holds no OSS write credential.
#   - It NEVER merges: NO `gh pr merge` of any kind. The OSS repo's OWN exam.yml +
#     CODEOWNERS review gate the merge, at every autonomy dial.
#   - The head branch is DETERMINISTIC (contribback/authored-<name>): a re-run
#     force-updates the same branch, so there is at most ONE open PR per detector
#     (idempotent).
#
# Usage: open-contribback-code-pr.sh <detector-name> <oss-repo>
#   <detector-name>  the merged authored detector under detectors/<name>/ in THIS
#                    (the operator's) checkout — the reusable workflow's
#                    contribute_back job already proved it is on the default branch.
#   <oss-repo>       owner/name of the shared OSS repo (e.g. mallcop-app/mallcop).
#
# Requires: GH_TOKEN (the operator's oss_contrib_token), git, gh, run from the
# operator repo checkout (the merged detector lives at detectors/<name>/ here).
set -euo pipefail

DET="${1:?usage: open-contribback-code-pr.sh <detector-name> <oss-repo>}"
OSS_REPO="${2:?usage: open-contribback-code-pr.sh <detector-name> <oss-repo>}"

# The operator's OWN token opens the PR (R8). Absent => fail-safe skip; the caller
# job already guards on this, but never assume a credential we were not given.
if [ -z "${GH_TOKEN:-}" ]; then
  echo "open-contribback: no operator OSS token (GH_TOKEN) — skipping (fail-safe); nothing opened."
  exit 0
fi

# The merged detector source is in THIS checkout (the operator repo). Capture it
# before we cd into the fork working tree.
SRC_ROOT="$PWD"
DET_SRC="$SRC_ROOT/detectors/$DET"
if [ ! -d "$DET_SRC" ]; then
  echo "open-contribback: detectors/$DET is not present in this checkout — the authoring PR has not merged; contributing nothing (fail-safe)."
  exit 0
fi

# ossDestFor (internal/selfext/contribback/artifact_code.go): a customer-repo file
# detectors/<name>/... promotes to core/detect/authored/<name>/... deterministically.
OSS_DEST_ROOT="core/detect/authored"
BRANCH="contribback/authored-${DET}"

# Operator identity + the OSS repo's default branch (the PR base), read via the
# token. Everything below talks ONLY to github.com / api.github.com (the job's
# egress allowlist) — gh for the API, git-over-HTTPS for the fork push.
GH_LOGIN="$(gh api user --jq .login)"
OSS_DEFAULT="$(gh api "repos/${OSS_REPO}" --jq .default_branch)"
OSS_NAME="${OSS_REPO##*/}"
FORK="${GH_LOGIN}/${OSS_NAME}"

# Ensure the operator has a fork to push the head branch to (idempotent — a no-op
# if it already exists). Then wait for the fork to be resolvable before cloning.
echo "open-contribback: ensuring ${GH_LOGIN} has a fork of ${OSS_REPO} ..."
gh repo fork "${OSS_REPO}" --clone=false >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if gh api "repos/${FORK}" --jq .name >/dev/null 2>&1; then break; fi
  sleep 6
done
gh api "repos/${FORK}" --jq .name >/dev/null 2>&1 || {
  echo "open-contribback: fork ${FORK} is not resolvable — cannot open the contribute-back PR (fail-safe)."; exit 0; }

# Work in a scratch clone of the fork; base the deterministic branch on the OSS
# repo's OWN default branch so the PR diff is exactly the promoted detector.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone --quiet "https://x-access-token:${GH_TOKEN}@github.com/${FORK}.git" "$WORK/fork"
cd "$WORK/fork"
git config user.name "mallcop-selfext"
git config user.email "selfext@mallcop.app"
git remote add upstream "https://github.com/${OSS_REPO}.git"
git fetch --quiet upstream "${OSS_DEFAULT}"
git checkout -B "${BRANCH}" "upstream/${OSS_DEFAULT}"

# Mirror detectors/<name>/ -> core/detect/authored/<name>/ (ossDestFor). Replace
# any prior contents so a re-run reflects the current merged detector exactly.
mkdir -p "${OSS_DEST_ROOT}"
rm -rf "${OSS_DEST_ROOT:?}/${DET}"
cp -R "${DET_SRC}" "${OSS_DEST_ROOT}/${DET}"
git add -A

if git diff --cached --quiet; then
  echo "open-contribback: ${OSS_DEST_ROOT}/${DET} already matches upstream — nothing to promote."
else
  git commit -q -F - <<COMMIT
selfext(contribute-back): promote authored detector ${DET} into OSS core

Mirrors the customer-authored detector detectors/${DET}/ (merged into the
operator's own thin-embed repo behind their exam gate + review) into the shared
OSS corpus at ${OSS_DEST_ROOT}/${DET}/. Opened for OSS review under the operator's
own identity. NOT auto-merged — the OSS repo's own exam.yml + CODEOWNERS review
gate the merge, at every autonomy dial.
COMMIT
fi

# Deterministic branch => force-update keeps at most one open PR per detector.
git push --quiet --force-with-lease origin "${BRANCH}"

# Open the REVIEW PR against the OSS repo, unless one is already open for this
# deterministic head (idempotent re-run). NEVER `gh pr merge`.
EXISTING="$(gh pr list --repo "${OSS_REPO}" --state open --head "${BRANCH}" --json number --jq 'length' 2>/dev/null || echo 0)"
if [ "${EXISTING:-0}" != "0" ]; then
  echo "open-contribback: an open OSS PR already exists for ${BRANCH} — updated it in place (never merged)."
  exit 0
fi

BODY_FILE="$(mktemp)"
{
  echo "## Contribute-back — promote authored detector \`${DET}\` into OSS core"
  echo
  echo "Automated contribute-back proposal from a mallcop self-extension run — CODE lane."
  echo
  echo "Promotes the customer-authored detector \`${DET}\` (merged into the operator's own"
  echo "thin-embed repo behind their exam gate + human review) into the shared OSS corpus at"
  echo "\`${OSS_DEST_ROOT}/${DET}/\`."
  echo
  echo "**This PR is NOT auto-merged.** It must pass the OSS project's OWN \`exam.yml\` CI and"
  echo "CODEOWNERS review, at every autonomy dial including the most-autonomous one. Merging a"
  echo "shared-OSS detector is a maintainer decision (design rulings R3/R8)."
} > "$BODY_FILE"

gh pr create \
  --repo "${OSS_REPO}" \
  --base "${OSS_DEFAULT}" \
  --head "${GH_LOGIN}:${BRANCH}" \
  --title "selfext(contribute-back): promote authored detector ${DET} into OSS core" \
  --body-file "$BODY_FILE"

echo "open-contribback: opened OSS review PR for ${DET} on ${GH_LOGIN}:${BRANCH} (never merged)."
