# Caravel wrapper (not started)

This folder is for eventually packaging `macc8_top` as a
`caravel_user_project`.

It's kept apart from the core on purpose: `rtl/` should harden on its own,
and day-to-day lint, sim, formal and synth work shouldn't depend on the
Caravel harness.

Still to write up: the user-project wrapper, how the ports map onto GPIO,
and any Caravel-specific constraints.
