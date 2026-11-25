# Global development standards

These apply to every project on this workstation. A project's own `CLAUDE.md` takes precedence: it holds that project's commands, design decisions, release procedure and current state. Don't repeat these standards there.

## Change discipline

- Keep changes small and on-task. Don't refactor unrelated code or build abstractions for hypothetical needs.
- Every new dependency must justify itself. Prefer the standard library and tools the project already uses.
- Existing behaviour and UI stay unless an issue says otherwise.
- Keep docs in sync with the code in the same change: `README.md`, `docs/`, `CHANGELOG.md`, `CLAUDE.md`.
- Confirm with me before outward-facing or hard-to-reverse steps (merging, tagging, publishing a release, closing an issue, deleting a branch, force-pushing) unless I've said to go ahead.
- Report results faithfully: what was run, what passed, what failed, and what is still unverified.

## Issues

- Track bugs, features and tech debt as GitHub Issues. Search existing issues first to avoid duplicates.
- A bug issue has reproduction steps, expected and actual results, the environment, and acceptance criteria.
- When work touches an issue, comment with the root cause (checked against the code), what changed (commit hashes), what was verified and how, and what is still unverified.
- Never close an issue, or call a fix resolved, until it's verified in the environment where it was reported.

## Branches, commits and pull requests

- Work on a branch. Commit straight to the default branch only to initialise a repository.
- Commits are focused (one concern each) and descriptive (what and why), and reference issues with `Refs #N`. Use `Fixes #N` only when the fix is verified. Each commit leaves the project buildable.
- Open a PR that references its issues and says how it was tested. Merge only when every required check is green, using a merge commit so the focused commits land unchanged. Confirm CI is green on the default branch afterwards.
- Never rewrite published history, force-push shared branches, or skip hooks or signing.

## CI/CD

- CI runs lint and tests on every push and PR. Workflows call the project's own build and test scripts instead of copying steps into YAML.
- Pin third-party actions to commit SHAs with the version in a comment. Give workflows least-privilege `permissions:`.
- Release artifacts are built by CI from a tag, never uploaded from a workstation. Release workflows create drafts; publishing is a manual step.

## Testing

- New behaviour gets automated tests. Every bug fix gets a regression test that fails without the fix, where practical.
- Run the project's lint and tests before pushing.
- What CI can't check (real hardware, managed workstations, UX) goes in a manual acceptance checklist, tracked as an issue. CI doesn't substitute for it.

## Versioning, changelog and releases

- Semantic versioning, with one source of truth for the version that the build reads.
- Tags are `vX.Y.Z`; release candidates are `vX.Y.Z-rc.N`. Tag only commits on the default branch. Never move or delete published tags or replace published assets.
- `CHANGELOG.md` is newest first. New work goes under `## Unreleased`, grouped as Added / Changed / Fixed / Removed / Security. Entries are concise: the user-visible effect, the root cause, and issue numbers. The release commit renames the section to the version.
- Ship a release candidate (pre-release) while environment or hardware validation is outstanding. Promote to stable only after the acceptance checklist passes. A stable release is the accepted RC's code with only the version and changelog changed.

## Builds, deployment and diagnostics

- Builds are reproducible: lock the toolchain and dependencies, with hashes where the ecosystem supports them.
- Prefer portable deployment: standard user, no admin rights, no hidden machine state. No hardcoded usernames, absolute paths or machine-specific values.
- Fail loudly: clear error messages, non-zero exit codes, and logs or crash reports a user can send. Provide a self-test or diagnostics command where practical.

## Security

- Never commit or paste credentials, API keys, tokens, `.env` files, conversation history, caches, or machine-specific settings such as `settings.local.json`.
- Don't weaken security settings or permissions, or work around workstation policy, to get something done. Ask instead.

## Workflow skills

`/init-project`, `/production-audit`, `/issue`, `/vult-ship`, `/hotfix`, `/release-candidate`, `/promote-stable`, `/handoff`, `/resume-project`. They follow the project's own `CLAUDE.md` where it defines a different procedure.
