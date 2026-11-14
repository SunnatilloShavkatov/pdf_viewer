# CLAUDE.md

@AGENTS.md

## Claude-specific notes

- Answer the user in Uzbek; technical terms stay in English.
- Code, comments, docs, commits, and PRs are written in English.
- Error and log text is quoted verbatim.
- Read `AGENTS.md` first; it holds the project layout, commands and change rules.
- Ask before changing the public API exported from `lib/pdf_viewer.dart`.
- Use `flutter test` and `dart analyze` to verify Dart changes. You cannot run the iOS or Android native builds from a headless session unless the user has the toolchains set up; say so when that is the case.
- `lib/src/bindings/*.g.dart` and the generated Objective-C wrapper are output of `tool/`. Do not edit them by hand.
- Keep answers and summaries short. Report test and analysis output if anything fails.
