#!/usr/bin/env bash
# Installs the exact toolchain versions pinned in env/tool-versions.md, onto
# any fresh Ubuntu box (this is what CI uses, but it's also how to reproduce
# the CI environment locally on a non-WSL2 Linux machine).
#
#   scripts/ci_install_toolchain.sh            # installs both
#   scripts/ci_install_toolchain.sh oss-cad-suite
#   scripts/ci_install_toolchain.sh verible
#
# Pinned to exact tags/assets, not "latest" -- OSS-CAD-Suite cuts new builds
# very frequently, and CI reproducibility matters more than always chasing
# the newest nightly. Bump these deliberately (and re-verify `make lint`/
# `make sim`/`make formal`/`make synth-check` locally) when upgrading.
set -euo pipefail

OSS_CAD_SUITE_TAG="2026-07-11"
OSS_CAD_SUITE_ASSET="oss-cad-suite-linux-x64-20260711.tgz"
VERIBLE_TAG="v0.0-4080-ga0a8d8eb"
VERIBLE_ASSET="verible-v0.0-4080-ga0a8d8eb-linux-static-x86_64.tar.gz"

TOOLS_ROOT="${MACC8_TOOLS_ROOT:-$HOME/tools}"
mkdir -p "$TOOLS_ROOT"

want="${1:-all}"

if [ "$want" = "all" ] || [ "$want" = "oss-cad-suite" ]; then
  if [ ! -d "$TOOLS_ROOT/oss-cad-suite" ]; then
    echo "Installing OSS-CAD-Suite $OSS_CAD_SUITE_TAG..."
    curl -sL -o /tmp/oss-cad-suite.tgz \
      "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_TAG}/${OSS_CAD_SUITE_ASSET}"
    tar -xzf /tmp/oss-cad-suite.tgz -C "$TOOLS_ROOT"
    rm /tmp/oss-cad-suite.tgz
  else
    echo "OSS-CAD-Suite already present at $TOOLS_ROOT/oss-cad-suite, skipping."
  fi
fi

if [ "$want" = "all" ] || [ "$want" = "verible" ]; then
  if [ ! -d "$TOOLS_ROOT/verible" ]; then
    echo "Installing Verible $VERIBLE_TAG..."
    curl -sL -o /tmp/verible.tar.gz \
      "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_TAG}/${VERIBLE_ASSET}"
    mkdir -p "$TOOLS_ROOT/verible"
    tar -xzf /tmp/verible.tar.gz -C "$TOOLS_ROOT/verible" --strip-components=1
    rm /tmp/verible.tar.gz
  else
    echo "Verible already present at $TOOLS_ROOT/verible, skipping."
  fi
fi

echo "Toolchain ready at $TOOLS_ROOT"
