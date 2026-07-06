# mallcop / selfext

Central, versioned home of the **mallcop self-extension CODE-lane reusable workflow**.

A mallcop operator's fork of [`mallcop-app/mallcop`](https://github.com/mallcop-app/mallcop)
carries a thin caller (`.github/workflows/mallcop-selfext-code.yml`, emitted by
`mallcop-ops selfext --scaffold-gha`) that forwards a `workflow_dispatch` to
`selfext-code-reusable.yml@<sha>` here. All orchestration lives in one place, so an
upgrade is a one-line SHA bump.

The workflow runs the same `mallcop-ops selfext --run` binary the operator runs
locally, inside the pinned, digest-verified runner image
(`ghcr.io/3dl-dev/selfext-runner`), authors ONE add-only detector, runs the in-runner
gate, and on GREEN opens a review PR under the operator's identity. It NEVER pushes to
main and NEVER merges.

See the [self-improvement docs](https://mallcop.app/docs/self-improvement.html).
