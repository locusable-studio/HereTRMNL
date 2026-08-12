# CLAUDE.md

## Git

### Commit: bump build number

Before every code commit, increment `CURRENT_PROJECT_VERSION` (build number) by 1.

- Location: `HereTRMNL.xcodeproj/project.pbxproj`
- Bump both Debug and Release values in sync
- Include the build number change in the same commit as the functional changes

## Release notes

GitHub Release title and body follow this convention. Write for users, not for commit history.

### Scope

- Each release covers changes **since the previous `v*` tag** (for example, `v2026.8.12` → next tag).
- Do not restate changes from older releases.

### Title

```text
HereTRMNL <MARKETING_VERSION>
```

Optional theme suffix when useful: `HereTRMNL 2026.8.12 — …`

### Body

```markdown
## Highlights
- Up to 3 user-facing points for this release

## Changes
- Concrete changes, ordered by importance (not by commit type)
- Prefer product language over conventional-commit subjects

## Notes
- Optional: upgrade caveats, permissions, system requirements, feed URL
```

### Rules

- CI creates the Release with **title only** (empty body); fill in Highlights / Changes / Notes manually after the tag ships
- Keep it short; one screen is enough
- No download-link sections (GitHub Assets already list DMGs)
- Sparkle feed (stable): `https://raw.githubusercontent.com/locusable-studio/HereTRMNL/main/Updates/appcast.xml`
