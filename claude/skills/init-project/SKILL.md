---
name: init-project
description: Bring a new or existing repository up to the standards - project CLAUDE.md, CHANGELOG, version source, .gitignore, change-aware CI and issue labels - without disturbing what already exists.
argument-hint: "[what the project is / its stack]"
disable-model-invocation: true
---

# /init-project

Set up the repository in the current directory. Context from the user: $ARGUMENTS

## 1. Inspect before changing anything

- `git status`, `git remote -v`, default branch, existing tags.
- Existing `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `.gitignore`, `.github/workflows/`, issue labels (`gh label list`).
- Stack, build/test/lint commands, and where the version lives (`package.json`, `pyproject.toml`, a constants file, ...).

Report what exists and what's missing. **Never overwrite an existing file**; propose edits to it instead.

## 2. Repository

- Not a git repo: ask before `git init -b main`.
- No GitHub remote: ask before `gh repo create <owner>/<name> --private --source . --remote origin`. Private by default.
- Everything after the initial commit goes on a branch, `chore/init-project`.

## 3. Create only what's missing, minimal for the stack

- `CLAUDE.md` from [templates/CLAUDE.md](templates/CLAUDE.md). Fill in only commands you ran successfully. Keep it project-specific; the global standards already apply.
- `CHANGELOG.md` from [templates/CHANGELOG.md](templates/CHANGELOG.md).
- One version source, reusing the stack's manifest if it has one. Record where it is in `CLAUDE.md`.
- `.gitignore` for the stack, including `.env`, `.env.*`, build outputs, caches and `.claude/settings.local.json`.
- `.github/workflows/ci.yml` from [templates/ci.yml](templates/ci.yml): docs-only PRs skip the tests, and the always-running `ci` job is the one required check. Fill in the project's own lint and test commands and dependency caching. Pin actions to SHAs: `gh api repos/actions/checkout/commits/<tag> --jq .sha`, written as `uses: actions/checkout@<sha> # <tag>`. Add an OS or version matrix only if the project has to support several.
- Labels, skipping any that exist: `bug`, `enhancement`, `documentation`, `tech-debt`, `release-blocker` (`gh label create <name>`).

Don't add frameworks, dependencies, tooling or structure the project doesn't need.

## 4. Verify and deliver

- Run the test and lint commands; fix what you introduced.
- Commit, push, and open one PR that lists what was created and how it was verified.
- Report what's left for the user: branch protection (require a PR and the `ci` check; protection needs a public repository or a paid plan) and any secrets CI needs.
