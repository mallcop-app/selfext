# mallcop / selfext

Central, versioned home of the **mallcop self-extension CODE-lane reusable workflow**.

A mallcop operator's fork of [`mallcop-app/mallcop`](https://github.com/mallcop-app/mallcop)
carries a thin caller (`.github/workflows/mallcop-selfext-code.yml`, emitted by
`mallcop selfext --scaffold-gha`) that forwards a `workflow_dispatch` to
`selfext-code-reusable.yml@<sha>` here. All orchestration lives in one place, so an
upgrade is a one-line SHA bump.

This is a pure **BYOK (Bring-Your-Own-Key)** lane. The workflow downloads the public
OSS `mallcop` release binary and runs the same `mallcop selfext --run` the operator
runs locally, on the operator's OWN inference endpoint + key — no donut/commercial
rail, no `mallcop-ops` download. The runner reproduces the pinned, checksum-verified
toolchain PRE-JAIL on the bare host (the container runner image is retired), applies a
self-enforced egress jail, authors ONE add-only detector, runs the in-runner gate, and
on GREEN opens a review PR under the operator's identity. It NEVER pushes to main and
NEVER merges.

See the [self-improvement docs](https://mallcop.app/docs/self-improvement.html).
