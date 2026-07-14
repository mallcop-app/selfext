#!/usr/bin/env bash
# open-proposal-pr.sh — turn a GREEN self-extension authoring artifact into a
# review PR under the OPERATOR's identity (the native GITHUB_TOKEN). It opens NO
# PR on RED (there is no artifact), NEVER calls `gh pr merge`, and NEVER pushes to
# a default branch — it pushes a `selfext/proposal-*` branch in the operator's own
# fork and opens a PR against that fork's default branch (W4, rd mallcoppro-98e).
#
# Usage: open-proposal-pr.sh <artifact-dir> <consent>
#   <artifact-dir>  the engine's --artifact-dir; the GREEN artifact is the single
#                   proposal-*/ subdir holding proposal.patch + gate.json +
#                   provenance.json + transcript.txt.
#   <consent>       "true" | "false" — recorded in the PR body only. Contribute-back
#                   to the upstream OSS repo is a SEPARATE, human-initiated step;
#                   this script never opens an upstream PR (invariant #6).
#
# Requires: GH_TOKEN (the job's github.token), git, gh, in the checked-out repo.
set -euo pipefail

ART_DIR="${1:?usage: open-proposal-pr.sh <artifact-dir> <consent>}"
CONSENT="${2:-false}"

# Locate the single GREEN proposal dir. Absent = RED/refused/skipped → no PR.
PROP_DIR="$(find "$ART_DIR" -maxdepth 1 -type d -name 'proposal-*' 2>/dev/null | sort | tail -1)"
if [ -z "$PROP_DIR" ] || [ ! -f "$PROP_DIR/proposal.patch" ]; then
  echo "open-proposal-pr: no GREEN artifact under $ART_DIR — nothing to open (RED/refused/skipped)."
  exit 0
fi

PATCH="$PROP_DIR/proposal.patch"
DETECTOR="$(python3 -c "import json,sys;print(json.load(open('$PROP_DIR/provenance.json')).get('detector_id','authored'))" 2>/dev/null || echo authored)"
FP="$(python3 -c "import json,sys;print(json.load(open('$PROP_DIR/provenance.json')).get('fingerprint','')[:12])" 2>/dev/null || echo unknown)"
BRANCH="selfext/proposal-${DETECTOR}-${FP}"

# Apply the patch on a fresh proposal branch off the current HEAD.
git config user.name "mallcop-selfext" 2>/dev/null || true
git config user.email "selfext@mallcop.app" 2>/dev/null || true
git checkout -b "$BRANCH"
git apply --index "$PATCH"
git commit -F - <<COMMIT
selfext: propose authored detector ${DETECTOR}

Machine-authored by the self-extension code lane and GREEN through the
in-runner gate (guard + four-layer + exam-detect). Opened for human review
under the operator's identity. NOT auto-merged. Fingerprint ${FP}.
consent-to-contribute-upstream: ${CONSENT}
COMMIT

git push -u origin "$BRANCH"

# Build the PR body from the gate + provenance (redacted transcript is attached
# in the artifact, not inlined). The label drives the exam.yml authored-change
# guard job.
BODY_FILE="$(mktemp)"
{
  echo "## Machine-authored detector — human review required"
  echo
  echo "The self-extension **code lane** authored this detector and it passed the"
  echo "in-runner gate (guard → four-layer → exam-detect monotonic-widen). It is"
  echo "**not** auto-merged; the required \`selfext authored-change guard\` check and a"
  echo "code-owner review gate it (rd mallcoppro-71c)."
  echo
  echo "- Detector: \`${DETECTOR}\`"
  echo "- Fingerprint: \`${FP}\`"
  echo "- Contribute-back consent (this build): \`${CONSENT}\`"
  echo
  echo "### Gate result"
  echo '```json'
  cat "$PROP_DIR/gate.json" 2>/dev/null || echo '{}'
  echo '```'
  echo
  echo "### Provenance"
  echo '```json'
  cat "$PROP_DIR/provenance.json" 2>/dev/null || echo '{}'
  echo '```'
  echo
  echo "_The redacted authoring transcript is in the run artifact._"
} > "$BODY_FILE"

PR_URL="$(gh pr create \
  --title "selfext: authored detector ${DETECTOR} (machine-authored, human-gated)" \
  --body-file "$BODY_FILE" \
  --label "selfext/proposal" \
  --head "$BRANCH")"

# Publish the opened PR number so the reusable workflow's dial-gated auto-merge
# step can target THIS PR (it reads steps.openpr.outputs.pr_number). The number is
# the trailing path segment of the PR URL gh prints. FAIL-SAFE: if no number is
# parseable — or this runs outside Actions ($GITHUB_OUTPUT unset) — we emit
# nothing, and the auto-merge step withholds (it treats an empty PR_NUMBER as a
# reason to leave the PR for a human). We NEVER merge here.
PR_NUMBER="$(printf '%s\n' "$PR_URL" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -n1 || true)"
if [ -n "${GITHUB_OUTPUT:-}" ] && [ -n "${PR_NUMBER}" ]; then
  printf 'pr_number=%s\n' "${PR_NUMBER}" >> "$GITHUB_OUTPUT"
fi

echo "open-proposal-pr: opened review PR #${PR_NUMBER:-?} for ${DETECTOR} on ${BRANCH} (never merged)."
