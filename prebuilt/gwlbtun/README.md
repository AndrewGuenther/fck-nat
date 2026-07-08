# Prebuilt `gwlbtun` artifact

This directory ships the build pipeline for **`gwlbtun`** — the AWS Gateway
Load Balancer Tunnel Handler binary that fck-nat uses for GWLB support. The
binary is built in CI and published as a versioned `.rpm` to GitHub release
assets. The fck-nat AMI's Packer build downloads the prebuilt artifact instead
of compiling it inside the AMI.

## Why this exists

The original GWLB support PR ([#95](https://github.com/AndrewGuenther/fck-nat/pull/95))
compiles `gwlbtun` inline during the Packer AMI build. That approach has two
problems flagged on the PR thread:

1. **Build deps persist in the AMI.** `cmake`, `gcc`, `g++`, `git`, and a
   ~500MB Boost source tree end up in the final image unless explicitly
   cleaned up.
2. **The source is unpinned.** Packer pulls `--branch main` from the upstream
   repo at AMI bake time, so reproducible builds are not guaranteed.

This pipeline addresses both: builds happen in a clean CI environment, the
source is pinned to a specific commit SHA, and only the resulting binary
(plus a small `BUILD_INFO` provenance file) ends up in the AMI.

## What gets built

A single `.rpm` per architecture:

```
fck-nat-gwlbtun-<version>-<arch>.rpm
```

Contents installed under `/opt/aws-gateway-load-balancer-tunnel-handler/`:
- `gwlbtun` — the compiled binary
- `BUILD_INFO` — pinning provenance (source SHA, Boost version, build date)

## How to release a new version

1. Bump `GWLBTUN_REF` and/or `BOOST_VERSION` in `.github/workflows/build-gwlbtun.yml`
   (the `workflow_dispatch` defaults). Pin to a specific commit SHA, not a
   branch.
2. Push a tag matching `gwlbtun-v*` (e.g. `gwlbtun-v0.2.0`).
3. The workflow builds both architectures and publishes a GitHub release with
   the `.rpm` files attached.

Example:

```sh
git tag gwlbtun-v0.1.0
git push origin gwlbtun-v0.1.0
```

## How the AMI consumes the artifact

The Packer flow downloads and installs the `.rpm`:

```hcl
provisioner "shell" {
  inline = [
    "sudo curl -L -o /tmp/gwlbtun.rpm https://github.com/AndrewGuenther/fck-nat/releases/download/${var.gwlbtun_release}/fck-nat-gwlbtun-${var.gwlbtun_release_version}-${var.rpm_arch}.rpm",
    "sudo yum --nogpgcheck -y localinstall /tmp/gwlbtun.rpm",
    "sudo rm /tmp/gwlbtun.rpm",
  ]
}
```

No build tools, no Boost source, no `cmake`/`gcc`/`g++`/`git` in the final
image. Estimated AMI size reduction vs in-AMI build: ~750 MB.

## Running the build locally (for debugging)

The build script is designed to run inside an AL2023 container so glibc
matches the target AMI. From the repo root:

```sh
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  -e GWLBTUN_REF=5e12604c85e99c8511d5b84604ac49647ffdc395 \
  -e BOOST_VERSION=1.83.0 \
  -e ARTIFACT_VERSION=0.0.0-local \
  -e TARGET_ARCH=$(uname -m) \
  amazonlinux:2023 \
  bash prebuilt/gwlbtun/build.sh
```

Output lands in `./build/fck-nat-gwlbtun-0.0.0-local-<arch>.rpm`.

For cross-arch builds (e.g. building aarch64 on an x86_64 host), use Docker's
emulation via `docker run --platform linux/arm64 ...`. CI builds natively on
GitHub-hosted `ubuntu-24.04-arm` runners to avoid emulation cost.

## Pinning policy

The workflow's defaults (in `build-gwlbtun.yml`) pin to specific commits and
versions. Bumping these is a deliberate act:

- **`GWLBTUN_REF`**: only bump after reading the upstream commit log between
  the current pin and the proposed new pin. The patches we apply
  (`NO_RETURN_TRAFFIC`, Boost include path) may break if upstream restructures
  the relevant files.
- **`BOOST_VERSION`**: only bump after confirming the new Boost version still
  has the headers `gwlbtun` consumes. Boost API churn is real.

The `BUILD_INFO` file inside each `.rpm` records what was pinned, so any
running fck-nat instance can be audited via `cat /opt/aws-gateway-load-balancer-tunnel-handler/BUILD_INFO`.
