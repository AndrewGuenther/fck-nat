#!/usr/bin/env bash
# Build the gwlbtun (AWS Gateway Load Balancer Tunnel Handler) binary and
# package it as a .rpm.
#
# Runs inside an Amazon Linux 2023 container so the linked glibc matches the
# target fck-nat AMI. Produces:
#   build/fck-nat-gwlbtun-${ARTIFACT_VERSION}-${TARGET_ARCH}.rpm
#
# Inputs (env vars):
#   GWLBTUN_REF        Commit SHA or ref of aws-samples/aws-gateway-load-balancer-tunnel-handler
#   BOOST_VERSION      Boost release version (e.g. 1.83.0)
#   ARTIFACT_VERSION   Semver string for our build (e.g. 0.1.0)
#   TARGET_ARCH        aarch64 | x86_64 (defaults to uname -m output)
#   WORKSPACE          Repo root mounted into the container (defaults to /workspace)

set -euo pipefail

GWLBTUN_REF="${GWLBTUN_REF:?GWLBTUN_REF is required (pin to a specific commit SHA)}"
BOOST_VERSION="${BOOST_VERSION:-1.83.0}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-0.0.0-dev}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"
WORKSPACE="${WORKSPACE:-/workspace}"

echo "=== gwlbtun build configuration ==="
echo "  GWLBTUN_REF      = ${GWLBTUN_REF}"
echo "  BOOST_VERSION    = ${BOOST_VERSION}"
echo "  ARTIFACT_VERSION = ${ARTIFACT_VERSION}"
echo "  TARGET_ARCH      = ${TARGET_ARCH}"
echo "  WORKSPACE        = ${WORKSPACE}"
echo

#-------------------------------------------------------------------------------
# Install build deps (we're in an AL2023 container)
#-------------------------------------------------------------------------------
echo "=== Installing build dependencies ==="
dnf install -y \
    cmake \
    gcc gcc-c++ \
    git \
    curl \
    tar \
    gzip \
    make \
    ruby ruby-devel \
    rpm-build \
    findutils

# fpm — wraps build outputs into a .rpm without writing an .spec
gem install --no-document fpm

#-------------------------------------------------------------------------------
# Stage Boost
#-------------------------------------------------------------------------------
echo "=== Downloading Boost ${BOOST_VERSION} ==="
mkdir -p /tmp/srcs && cd /tmp/srcs
BOOST_UNDERSCORE="${BOOST_VERSION//./_}"
curl -fsSL -o boost.tar.gz \
    "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_UNDERSCORE}.tar.gz"
tar xzf boost.tar.gz
mv "boost_${BOOST_UNDERSCORE}" boost
rm -f boost.tar.gz

#-------------------------------------------------------------------------------
# Clone and patch gwlbtun
#-------------------------------------------------------------------------------
echo "=== Cloning gwlbtun ${GWLBTUN_REF} ==="
git clone https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler.git gwlbtun
cd gwlbtun
git checkout "${GWLBTUN_REF}"
GWLBTUN_RESOLVED_SHA=$(git rev-parse HEAD)
echo "Resolved SHA: ${GWLBTUN_RESOLVED_SHA}"

# Mirror the patches PR #95 applied during in-AMI builds.
# 1. Enable the NO_RETURN_TRAFFIC define for the performance optimization.
echo "=== Applying patches ==="
sed -i 's%//#define NO_RETURN_TRAFFIC%#define NO_RETURN_TRAFFIC%' utils.h
# 2. Point CMakeLists.txt at our staged Boost rather than the upstream-hardcoded path.
sed -i 's%set(Boost_INCLUDE_DIR /home/ec2-user/boost)%set(Boost_INCLUDE_DIR /tmp/srcs/boost)%' CMakeLists.txt

#-------------------------------------------------------------------------------
# Compile
#-------------------------------------------------------------------------------
echo "=== Compiling gwlbtun ==="
cmake .
make -j"$(nproc)"

if [ ! -x "/tmp/srcs/gwlbtun/gwlbtun" ]; then
    echo "ERROR: build did not produce /tmp/srcs/gwlbtun/gwlbtun" >&2
    exit 1
fi

#-------------------------------------------------------------------------------
# Package as .rpm
#-------------------------------------------------------------------------------
echo "=== Packaging .rpm ==="
STAGE=/tmp/stage
INSTALL_PREFIX=/opt/aws-gateway-load-balancer-tunnel-handler
mkdir -p "${STAGE}${INSTALL_PREFIX}"
install -m 0755 /tmp/srcs/gwlbtun/gwlbtun "${STAGE}${INSTALL_PREFIX}/gwlbtun"

# Embed pinning provenance as a small file in the package so installed AMIs
# can be audited (which source did this binary come from?).
mkdir -p "${STAGE}${INSTALL_PREFIX}"
cat > "${STAGE}${INSTALL_PREFIX}/BUILD_INFO" <<EOF
gwlbtun source: https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler
gwlbtun commit: ${GWLBTUN_RESOLVED_SHA}
boost version:  ${BOOST_VERSION}
build version:  ${ARTIFACT_VERSION}
target arch:    ${TARGET_ARCH}
built:          $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

mkdir -p "${WORKSPACE}/build"
OUTPUT_RPM="${WORKSPACE}/build/fck-nat-gwlbtun-${ARTIFACT_VERSION}-${TARGET_ARCH}.rpm"

fpm -s dir -t rpm \
    --name fck-nat-gwlbtun \
    --version "${ARTIFACT_VERSION}" \
    --architecture "${TARGET_ARCH}" \
    --license apache-2.0 \
    --rpm-os linux \
    --description "AWS Gateway Load Balancer Tunnel Handler, prebuilt for fck-nat.
Pins to aws-samples/aws-gateway-load-balancer-tunnel-handler commit ${GWLBTUN_RESOLVED_SHA}
and Boost ${BOOST_VERSION}." \
    --url "https://github.com/AndrewGuenther/fck-nat" \
    --maintainer "fck-nat contributors" \
    -C "${STAGE}" \
    -p "${OUTPUT_RPM}" \
    "${INSTALL_PREFIX#/}"

echo
echo "=== Done. Built: ${OUTPUT_RPM} ==="
ls -lh "${OUTPUT_RPM}"
rpm -qip "${OUTPUT_RPM}" || true
rpm -qlp "${OUTPUT_RPM}" || true
