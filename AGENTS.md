# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter/Dart application for an Android tablet quota monitor, with a
Windows desktop runner retained for development. Keep application code in
`lib/`: `app/` contains theme, settings, and Riverpod controller wiring;
`features/` contains screen-specific widgets; `services/` owns platform/API
integrations; `database/` contains Drift persistence; and `core/` holds shared
models and security primitives. Native Android integration is in
`android/app/src/main/kotlin/`; Windows runner code is in `windows/`.

Tests live in `test/`, with golden baselines in `test/goldens/`. Development
deployment helpers belong in `tools/`. Do not hand-edit generated Flutter,
Drift, or platform registration files.

## Build, Test, and Development Commands

Run these from the repository root:

```powershell
flutter pub get                              # resolve dependencies
dart run build_runner build --delete-conflicting-outputs  # regenerate Drift code
flutter analyze                              # run configured Dart lints
flutter test                                 # run unit and widget tests
flutter test --update-goldens                # intentionally refresh golden PNGs
flutter run                                  # launch a debug build
flutter build apk --release                  # create the production APK
```

For a personally controlled debug device, `tools/deploy_debug_with_auth.ps1
-Serial <serial>` builds, installs, and performs the one-time credential
staging flow described in `README.md`. Never use it for release deployment.

## Coding Style & Naming Conventions

Follow `flutter_lints` through `analysis_options.yaml` and run `dart format .`
before submitting. Use standard Dart formatting (two-space indentation),
`lower_snake_case.dart` filenames, `PascalCase` types, and `camelCase` members.
Keep widgets feature-local where possible; depend on services and Riverpod
providers rather than embedding network, database, or credential logic in UI.

## Testing Guidelines

Use `flutter_test`; name files `<subject>_test.dart` and describe behavior in
test names (for example, `history keeps the current chart visible`). Prefer
in-memory Drift databases for persistence tests. Update golden files only for
reviewed visual changes, and run the affected golden test at all supported
canvas sizes before committing.

## Security, Commits, and Pull Requests

`auth.json`, OAuth tokens, account identifiers, and Authorization headers are
sensitive: never commit, log, paste into fixtures, or include in screenshots.
This checkout has no Git history, so no repository-specific commit convention
can be inferred. Use concise imperative subjects such as `feat: add retry
status` or `fix: avoid token logging`. Pull requests should explain the user
impact, tests run, any migration or permission change, link the issue when
available, and include before/after screenshots for dashboard UI changes.
