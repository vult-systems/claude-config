---
name: init-project
description: Bring a new or existing repository up to the production standards - project CLAUDE.md, CHANGELOG, version source, .gitignore, CI and issue labels - without disturbing what already exists.
argument-hint: "[what the project is / its stack]"
disable-model-invocation: true
---

# /init-project

Set up the repository in the current directory. Context from the user: $ARGUMENTS

## 1. Inspect before changing anything

- `git status`, `git remote -v`, default branch, existing tags.
- Existing `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `.gitignore`, `.github/workflows/`, issue labels (`gh label list`).
- Stack, build/test/lint commands, and where the version lives (`package.json`, `pyproject.toml`, a constants file, ...).

Report what exists and what's missing, and agree the plan with the user. **Never overwrite an existing file**; propose edits to it instead.

## 2. Repository

- Not a git repo: ask before `git init -b main`.
- No GitHub remote: ask before `gh repo create <owner>/<name> --private --source . --remote origin`. Private by default.
- Everything after the initial commit goes on a branch, `chore/init-project`.

## 3. Create only what's missing, minimal for the stack

- `CLAUDE.md` from [templates/CLAUDE.md](templates/CLAUDE.md). Fill in only commands you ran successfully. Keep it project-specific; the global standards already apply.
- `CHANGELOG.md` from [templates/CHANGELOG.md](templates/CHANGELOG.md).
- One version source, reusing the stack's manifest if it has one. Record where it is in `CLAUDE.md`.
- `.gitignore` for the stack, including `.env`, `.env.*`, build outputs, caches and `.claude/settings.local.json`.
- `.github/workflows/ci.yml`: lint and tests on `push` and `pull_request`, calling the project's own scripts; `permissions: contents: read`. Pin actions to SHAs: `gh api repos/actions/checkout/commits/<tag> --jq .sha`, written as `uses: actions/checkout@<sha> # <tag>`.
- Labels, skipping any that exist: `bug`, `enhancement`, `documentation`, `compatibility`, `release-blocker`, `tech-debt`, `awaiting-acceptance` (`gh label create <name>`).

Don't add frameworks, dependencies, tooling or structure the project doesn't need.

## 4. Verify and deliver

- Run the test and lint commands; fix what you introduced.
- Focused commits (`Add CLAUDE.md with build and test commands`, `Add CI workflow`, ...), push, and open a PR that lists what was created and how it was verified.
- Report anything left for the user, such as branch protection or secrets the CI needs.
