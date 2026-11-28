# Global development standards

These apply to every project on this workstation. A project's own `CLAUDE.md` takes precedence and holds its commands, design decisions, release procedure, feature freezes and current state.

Process scales with risk, scope and impact. Stop when the requested outcome is done and verified; don't invent follow-up work.

## Modes

Sessions start in dev mode. `/vult-fast`, `/vult-dev` and `/vult-prod` switch mode for the rest of the session. Every skill, `/vult-ship` included, works at the current mode and never escalates it.

| | Fast | Dev (default) | Prod |
|---|---|---|---|
| Planning | None | Only for consequential or ambiguous work | Plan consequential changes and wait for approval |
| Validation | Smoke test | Tests relevant to the change | Full regression, compatibility, security and deployment checks |
| Issues | Optional | One per meaningful body of work | Every change tracked |
| Docs, changelog | Optional | When behaviour or usage changes | Always kept in sync |
| Review | None | When the risk justifies it | Independent review of non-trivial diffs |
| Budget | 2-5 min | 5-10 min | 15-30 min |

Budgets are soft targets for validation and administration, not implementation. Say why when more is needed.

In every mode:

- Ask before consequential, destructive, security-sensitive or out-of-scope actions.
- The project's `CLAUDE.md` wins, including feature freezes.
- Never commit to the default branch or a protected branch, except to initialise a repository. Work reaches it through a PR.
- Never discard, reset or overwrite work you didn't make.
- Never bypass a failed required check. Report what ran, passed, failed and is unverified; never claim validation you didn't do.
- Keep changes on task. Ask before adding dependencies or changing build config or CI.

## Validation

| Change | Validation |
|---|---|
| Docs only | Links, accuracy, formatting, docs checks |
| Minor bug fix | Targeted regression test |
| Small feature | Relevant tests and a smoke test |
| Major feature | Full regression and relevant integration tests |
| Dependencies, build | Affected build and compatibility checks |
| Security, critical infrastructure | Comprehensive validation |

- Test the final change, not every intermediate commit. Don't repeat a passing check unless its inputs changed. Leave compatibility matrices to CI.
- New behaviour gets tests where they add value. A bug fix gets a regression test where practical.
- Checks CI can't run (hardware, managed workstations, UX) go on an issue checklist when they matter.

## Issues

- Use issues for meaningful features, bugs, tech debt and milestones. Search first. Put related work in one issue with a checklist. Trivial fixes need none. Bugs get reproduction steps, expected and actual results, and the environment.
- When work on an issue lands, comment once: what changed, how it was verified, what is unverified. Close it when its objective is verified; keep important unverified items open.

## Branches, commits and pull requests

- Commits are descriptive and reference issues with `Refs #N` (`Fixes #N` once verified). Keep working history. Squash only when it helps, never for cosmetics.
- One PR for related implementation, tests, docs and release metadata. Merge with a merge commit once required checks pass, then delete the merged branch locally and remotely.
- Asking to ship approves the normal scoped steps: push, PR, merge after checks, branch cleanup. Tags, releases and anything outside the scope still need confirmation unless authorized.
- Never rewrite published history, force-push shared branches, or skip hooks or signing.

## CI

- Change-aware: docs-only changes skip the tests; other changes run the tests they affect, through the project's own scripts.
- The required check is one always-running gate job that passes when the jobs it needs succeeded or were skipped. Workflow-level path filters leave required checks pending.
- Run on pull requests and pushes to the default branch, not every branch push. Cancel superseded runs, cache dependencies, parallelise independent jobs.
- Pin third-party actions to commit SHAs with the version in a comment. Give workflows least-privilege `permissions:`.

## Releases

- Semantic versioning, one version source, `vX.Y.Z` tags on the default branch. `CHANGELOG.md` is newest first, new work under `## Unreleased` (Added / Changed / Fixed / Removed / Security), each entry the user-visible effect and issue numbers.
- Routine releases go straight to stable after proportionate validation, with the version bump in the work's own PR if convenient. Use release candidates (`vX.Y.Z-rc.N`) and an acceptance checklist when real-environment validation is outstanding.
- CI builds artifacts from the tag; publish the validated artifact rather than rebuilding. Never move or delete published tags or replace published assets. Keep the previous release for rollback.

## Builds and deployment

- Lock the toolchain and dependencies, with hashes where supported. Fail loudly: clear errors, non-zero exit codes, logs a user can send.
- Deploy as a standard user without admin rights or hidden machine state. No hardcoded usernames, absolute paths or machine-specific values.

## Security

- Never commit or paste credentials, API keys, tokens, `.env` files, conversation history, caches, or machine-specific settings such as `settings.local.json`.
- Don't weaken security settings or permissions, or work around workstation policy, to get something done. Ask instead.

## Workflow skills

`/vult-fast`, `/vult-dev`, `/vult-prod`, `/init-project`, `/production-audit`, `/issue`, `/vult-ship`, `/hotfix`, `/release-candidate`, `/promote-stable`, `/handoff`, `/resume-project`. They follow the project's `CLAUDE.md` where it defines a different procedure.
