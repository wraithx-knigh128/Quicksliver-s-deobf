# Origin-check fixtures

Small files written for this project to exercise the origin check (`src/origin`). They are *constructed examples* of two
habits, not samples of real authors:

* `assistant_*.lua` imitate the way a code assistant typically writes Luau (headers, doc annotations, defensive checks,
  tagged log messages, restating comments).
* `scrappy_*.lua` imitate quick hand-written scripts (short names, commented-out code, debug prints, mixed spacing).
* `patchwork_credited.lua` is two differently-styled halves with a credit line and a UI library, the shape of a script
  assembled from other people's pieces.

They check that every signal fires on what it is meant to and stays quiet otherwise. They say nothing about how accurate
the origin check is on real code: that has not been measured on a labelled data set.
