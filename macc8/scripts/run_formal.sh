#!/usr/bin/env bash
# Convenience wrapper to run the formal proofs (delegates to verif/formal).
set -euo pipefail
( cd verif/formal && ./run_formal.sh )
