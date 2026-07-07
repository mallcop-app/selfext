# Dockerfile — mallcop self-extension CODE-lane runner image.
#
# Bakes the authoring toolchain at PINNED versions, entirely from PUBLIC,
# sha256-verified downloads (no private build context): mallcop-ops (this repo's
# release), the mallcop gate binary (mallcop-app/mallcop release), a pinned
# opencode, the Go toolchain (the in-runner gate runs `go build` on the target),
# the bundled pricing/models/lanes config, and the operator-identity PR opener.
#
# Because every input is a public download, this image is built and pushed under
# mallcop-app with the repo's own GITHUB_TOKEN — no cross-org credential.
# Published as ghcr.io/mallcop-app/selfext-runner and pinned BY DIGEST in the
# reusable workflow. Rebuild + re-pin on any version bump.
ARG GO_VERSION=1.25
ARG OPENCODE_VERSION=1.17.11
ARG MALLCOP_OPS_VERSION=ops-v0.1.0
ARG MALLCOP_VERSION=v0.9.3

FROM golang:${GO_VERSION}
ARG OPENCODE_VERSION
ARG MALLCOP_OPS_VERSION
ARG MALLCOP_VERSION
ENV OPENCODE_DISABLE_AUTOUPDATE=1 \
    OPENCODE_TELEMETRY_DISABLED=1 \
    DO_NOT_TRACK=1 \
    PATH=/usr/local/bin:$PATH

# node 24 + gh, then opencode pinned. --ignore-scripts blocks every dependency's
# install scripts; we then run ONLY opencode's own vetted postinstall.mjs, which
# fetches the pinned platform binary (opencode is non-functional without it).
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && npm install -g --ignore-scripts opencode-ai@${OPENCODE_VERSION} \
    && node "$(npm root -g)/opencode-ai/postinstall.mjs" \
    && npm cache clean --force \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# mallcop-ops (this repo's public release) — binary + bundled config, sha256-verified.
RUN curl -fsSLO "https://github.com/mallcop-app/selfext/releases/download/${MALLCOP_OPS_VERSION}/mallcop-ops-linux-amd64.tar.gz" \
    && curl -fsSLO "https://github.com/mallcop-app/selfext/releases/download/${MALLCOP_OPS_VERSION}/mallcop-ops-linux-amd64.tar.gz.sha256" \
    && sha256sum -c mallcop-ops-linux-amd64.tar.gz.sha256 \
    && tar -xzf mallcop-ops-linux-amd64.tar.gz \
    && install -m0755 mallcop-ops-linux-amd64/bin/mallcop-ops /usr/local/bin/mallcop-ops \
    && mkdir -p /opt/mallcop/config && cp -r mallcop-ops-linux-amd64/config/. /opt/mallcop/config/ \
    && rm -rf mallcop-ops-linux-amd64*

# mallcop gate binary (public OSS release), sha256-verified.
RUN curl -fsSLO "https://github.com/mallcop-app/mallcop/releases/download/${MALLCOP_VERSION}/mallcop-linux-amd64.tar.gz" \
    && curl -fsSLO "https://github.com/mallcop-app/mallcop/releases/download/${MALLCOP_VERSION}/mallcop-linux-amd64.tar.gz.sha256" \
    && sha256sum -c mallcop-linux-amd64.tar.gz.sha256 \
    && tar -xzf mallcop-linux-amd64.tar.gz \
    && install -m0755 bin/mallcop /usr/local/bin/mallcop \
    && rm -rf mallcop-linux-amd64* bin

COPY infra/open-proposal-pr.sh /opt/mallcop/open-proposal-pr.sh
RUN chmod +x /opt/mallcop/open-proposal-pr.sh \
    && mallcop-ops selfext -h >/dev/null 2>&1 || true \
    && opencode --version
