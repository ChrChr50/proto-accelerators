#!/usr/bin/env bash
# Installs the toolchain versions listed in env/tool-versions.md on a clean
# Ubuntu machine. CI uses it, and it's also the easiest way to get the same
# setup on a Linux box that isn't WSL2.
#
#   scripts/ci_install_toolchain.sh                 # both
#   scripts/ci_install_toolchain.sh oss-cad-suite   # just OSS-CAD-Suite
#   scripts/ci_install_toolchain.sh verible         # just Verible
#
# The versions are pinned. OSS-CAD-Suite publishes a new build almost every
# day, and I'd rather CI be reproducible than always on the newest one. When
# bumping them, rerun lint, sim, formal and synth-check locally first.
set -euo pipefail

OSS_CAD_SUITE_TAG="2026-07-11"
OSS_CAD_SUITE_ASSET="oss-cad-suite-linux-x64-20260711.tgz"
VERIBLE_TAG="v0.0-4080-ga0a8d8eb"
VERIBLE_ASSET="verible-v0.0-4080-ga0a8d8eb-linux-static-x86_64.tar.gz"

TOOLS_ROOT="${MACC8_TOOLS_ROOT:-$HOME/tools}"
mkdir -p "$TOOLS_ROOT"

pick="${1:-all}"

if [ "$pick" = "all" ] || [ "$pick" = "oss-cad-suite" ]; then
  if [ ! -d "$TOOLS_ROOT/oss-cad-suite" ]; then
    echo "Fetching OSS-CAD-Suite $OSS_CAD_SUITE_TAG"
    curl -sL -o /tmp/oss-cad-suite.tgz \
      "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_TAG}/${OSS_CAD_SUITE_ASSET}"
    tar -xzf /tmp/oss-cad-suite.tgz -C "$TOOLS_ROOT"
    rm /tmp/oss-cad-suite.tgz
  else
    echo "OSS-CAD-Suite is already in $TOOLS_ROOT/oss-cad-suite"
  fi
fi

if [ "$pick" = "all" ] || [ "$pick" = "verible" ]; then
  if [ ! -d "$TOOLS_ROOT/verible" ]; then
    echo "Fetching Verible $VERIBLE_TAG"
    curl -sL -o /tmp/verible.tar.gz \
      "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_TAG}/${VERIBLE_ASSET}"
    mkdir -p "$TOOLS_ROOT/verible"
    tar -xzf /tmp/verible.tar.gz -C "$TOOLS_ROOT/verible" --strip-components=1
    rm /tmp/verible.tar.gz
  else
    echo "Verible is already in $TOOLS_ROOT/verible"
  fi
fi

echo "Tools are in $TOOLS_ROOT"
