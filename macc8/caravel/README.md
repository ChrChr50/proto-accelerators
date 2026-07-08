# Caravel integration (optional)

Notes on wrapping `macc8_top` as a `caravel_user_project`.

This directory is isolated from the core so `rtl/` stays independently
hardenable and the repo isn't coupled to the Caravel harness for everyday
lint/sim/formal/synth work.

TODO: document the user-project wrapper, GPIO mapping, and Caravel-specific
constraints when the integration is undertaken.
