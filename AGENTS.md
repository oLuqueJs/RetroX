# RetroX - Engineering Guidelines

## Project

RetroX is a native macOS application written in Swift.

The project uses Swift Package Manager and separates
application UI from reusable core functionality.

## Architecture

- Sources/RetroXApp: application, SwiftUI, UI state and views.
- Sources/RetroXCore: domain logic, library, emulator adapters,
  plugins, launching and infrastructure.
- Tests/RetroXCoreTests: core tests and regression coverage.
- docs/adr: accepted architectural decisions.
- docs/PRD.md: product requirements.
- docs/TESTING.md: testing guidance.

## Engineering Rules

1. Read relevant ADRs before changing architecture.
2. Prefer the smallest correct change.
3. Do not introduce unnecessary dependencies.
4. Keep domain logic out of SwiftUI views.
5. Follow existing protocols and module boundaries.
6. Do not modify unrelated files.
7. Do not remove tests to make a build pass.
8. Do not claim tests passed without executing them.
9. Never commit credentials, tokens or private user data.
10. Never commit generated files from .build/.

## Git Workflow

Two long-lived, protected branches:

- `beta`: where changes land first. Every merge publishes a pre-release
  (`1.2.0-beta.1`, `1.2.0-beta.2`, ...).
- `main`: stable. Only receives promotions from `beta` and urgent hotfixes.
  Every merge may publish a stable release.

Rules:

1. Never commit or push directly to `main` or `beta`.
2. Branch from an up-to-date `beta`. Name branches `<type>/<short-description>`
   with the same types as commits: `feat/`, `fix/`, `chore/`, `docs/`,
   `refactor/`, `test/`, `ci/`.
3. Keep branches short-lived and focused on one change.
4. Open a pull request to `beta`. Required: CI (workflow "Testes") green.
   Contributions from forks follow the same rule.
5. PRs into `beta` are merged with **squash merge**. The PR title becomes the
   commit on `beta`, so it must be a valid Conventional Commit, in Portuguese:
   `feat(biblioteca): detecta capas do Azahar`.
6. Delete the branch after merge.
7. Never merge without human approval, never force-push `main` or `beta`,
   never skip hooks or CI.

### Promoting to stable

A stable release happens when a PR `beta` -> `main` is merged, after the
pre-release was tested. That PR uses a **merge commit**, not squash, so release
notes keep their detail. Never open it without being asked.

### Exceptions to go straight to `main`

- Urgent hotfixes (`fix/`), branched from `main`.
- Changes that do not publish a version and do not touch app behavior
  (`docs`, `ci`).

After any change merged straight into `main`, merge `main` back into `beta`
to keep the branches in sync.

### Commits and versions

semantic-release publishes a release on every merge to `beta` (pre-release)
and `main` (stable), using the rules in `.releaserc.json`:

| Commit type | Release |
| --- | --- |
| `BREAKING CHANGE:` in the body (any type) | major |
| `feat` | minor |
| `fix`, `chore` | patch |
| `docs`, `ci`, `refactor`, `test`, `perf`, `style`, `build` | none |

- `feat!:` is not recognized; use `BREAKING CHANGE:` in the body.
- Pick the type by the real effect on the shipped app. Do not use `feat`,
  `fix` or `chore` for changes that should not publish a version; use `docs`,
  `ci`, `refactor` or `test` instead.
- Group related changes in one PR, since each merge may publish a release.
- Never create tags or releases by hand; semantic-release owns them.

## Brand

The Rayo character, the logo, the icon and the names RetroX and Rayo are
not covered by the GPL-3.0 (see BRAND.md). Do not modify, regenerate or
redistribute those assets unless the task explicitly asks for it.

## Validation

Default checks:

- swift build
- swift test
- git diff --check

Consult docs/TESTING.md and relevant scripts for
additional verification.

## Task Management

Hermes Kanban is the task source of truth.
Implementation tasks require acceptance criteria.
Workers must report evidence before review.

Before implementation:
- Identify the task ID.
- Read the acceptance criteria. If a task has none, stop and ask for them.
- Review dependencies and relevant ADRs.
- Define a minimal implementation plan.

After implementation:
- Report modified files.
- Report tests actually executed, with their results (evidence).
- Identify risks and unresolved issues.
- Do not move the task to review without that evidence.
- Do not mark the task Done without review.

## Completion

A task is complete only after its acceptance criteria
are satisfied, required quality gates pass, and the
change is approved.
