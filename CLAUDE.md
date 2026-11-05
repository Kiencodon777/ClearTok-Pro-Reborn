# ClearTok Pro Reborn

Read `AGENTS.md` before changing this repository. Run project commands from this directory (`app/` in the shared workspace).

## Work tracking

- Use Kanzo project `cleartok-pro`, linked to `Kiencodon777/ClearTok-Pro-Reborn`.
- Check existing tasks before creating a duplicate. Move the relevant task to `doing` when starting authorized work.
- Comment with concrete changes, validation results and unresolved limits. Move to `review` when finished or blocked, explaining any blocker.
- Leave `done` and human tasks to the user. A board item alone is not permission to start unrelated work.

## Implementation

- Make the smallest complete change. Read callers and affected tests before editing; preserve public classes, callbacks, models and services unless the task requires otherwise.
- Keep TikTok API/session capture, WebView lifecycle, Hive data, pagination, batch pause/resume/stop, remote config and diagnostic logs intact during UI work.
- Never commit cookies, tokens, credentials or private account/session data. Keep diagnostic output free of these values.
- Flutter is pinned to `3.41.9` in CI; Dart must satisfy `pubspec.yaml`. Keep `pubspec.lock` consistent with dependency changes.
- Reuse `lib/ui/widgets/liquid_glass.dart` and the installed `liquid_glass_widgets` package. Keep TikTok pink `#FE2C55`, cyan `#25F4EE` and the dark background. Respect safe areas, reduced motion and readable content.
- Do not upgrade the SDK or add dependencies unless necessary for the authorized task.

## Relevant paths

- `lib/ui/`: screens and shared UI components.
- `lib/api/`, `lib/core/`: TikTok transport and remote configuration.
- `lib/services/`, `lib/database/`, `lib/models/`: batch processing, local persistence and data models.
- `test/`: Flutter, Python and Node regression checks.
- `.github/workflows/release.yml`: platform scaffolding, validation, APK/IPA builds and versioned publication.
- `scripts/package_ipa.py`: IPA layout and metadata validation.

## Validation and release

- Format changed Dart files; run analysis and tests appropriate to the change. For SDK/platform changes, verify native builds as well.
- Use the validation commands in `.github/workflows/release.yml` as the CI reference. Report existing legacy analyzer failures separately; do not suppress new errors.
- Documentation-only changes do not need Flutter tests or a new build unless requested.
- Follow every release requirement in `AGENTS.md`. Keep the source repository private; the approved public update feed contains only version, notes and download links.
- Report the actual CI result and verified Release URL. Never claim on-device TikTok, visual appearance or IPA signing was tested unless it was actually checked.
- Communicate concisely in Vietnamese, including what changed, what passed and anything not checked.
