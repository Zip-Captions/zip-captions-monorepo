# NFR Requirements Clarification Questions — Unit 8.1

No contradiction in the twelve answers. One FD handoff question is not covered by them, and one
consequence of Q2 needs recording rather than deciding. Both are below.

---

## Carried question 1: proving `zip_captions`'s main-entry routing (BR-U8.1-06)

The FD handoff asked how `zip_captions`'s new `main(List<String> args)` routing is proven without
initialising Supabase. `zip_captions` has **no** `main`-shaped test today; `zip_broadcast`'s
`app_test.dart` only pumps `ZipBroadcastApp` inside a `ProviderScope` and never calls `main`.

### Clarification Question 1
How should the routing be made testable?

A) **Extract a seam**: `zip_captions`'s `main` keeps its body but delegates to
   `Future<void> runZipCaptions(List<String> args, {Future<void> Function(Widget)? runApp, bool
   isWeb = kIsWeb})` in `lib/src/bootstrap.dart`. Tests call `runZipCaptions(['multi_window','1',p])
   with a recording `runApp` and assert (i) the overlay window is built, (ii) `Supabase.initialize`
   was never reached and (iii) `SharedPreferences.getInstance` was never called. Doing the same for
   `zip_broadcast` is optional but cheap, and would let both apps' routing share one test shape.
B) **Test only the predicate**: assert `isOverlayWindowLaunch` and trust the three-line ordering in
   `main` by review. Cheapest, and the ordering is what could regress.
C) **No test**: `main` is not unit-testable by convention in this project, and the ordering is
   checked once by running the app.

D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Recorded consequence of Q2 (no action needed, for the record)

Q2 A removes `screen_retriever` from `zip_broadcast` once its last import moves. Two effects follow,
and both are intended:

- `zip_broadcast/macos/Podfile.lock` loses `screen_retriever_macos` and gains `window_manager_macos`.
  `zip_captions/macos/Podfile.lock` gains `desktop_multi_window` and `window_manager_macos`. The
  lockfile fence in `tech-stack-decisions.md` names exactly these four movements and nothing else.
- `zip_broadcast`'s `windows/flutter/generated_plugins.cmake` and
  `linux/flutter/generated_plugins.cmake` lose `screen_retriever_windows`/`screen_retriever_linux`
  and gain `window_manager_windows`/`window_manager_linux`; `zip_captions`' equivalents gain both.
  These files are generated and are not committed, so this is build evidence, not a diff to review.

If the answer to Q1 is A, the bootstrap file also becomes the only place where `main`'s ordering
lives, which makes FD **BR-U8.1-06**'s verification clause ("a unit test on the launch predicate
plus a `main`-shaped test") literally true instead of aspirational. That is why A is recommended.