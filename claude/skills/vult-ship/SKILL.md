---
name: vult-ship
description: Take the current work to a merged pull request - scope check, lint and tests, focused commits, push, PR referencing its issues, green CI, merge commit, post-merge check on the default branch.
argument-hint: "[issue number]"
disable-model-invocation: true
---

# /vult-ship

Related issue(s): $ARGUMENTS

1. **Context.** Run `git status`, `git diff`, and `git log <default>..HEAD --oneline`, and find the related issues. If you're on the default branch, create `<feat|fix|docs|chore>/<issue>-<slug>` first.
2. **Experimental work.** Work built in `/vult-fast` meets the full standards here, whatever the current mode. Work through the deferred list: add the tests, docs and `CHANGELOG.md` entry, and create the issue with `/issue` if there isn't one. If the project's `CLAUDE.md` declares a feature freeze, ship only changes it allows; anything else stays on its branch. Tell the user what's being added before continuing.
3. **Scope.** Every change must belong to this task. Leave unrelated edits unstaged and tell the user about them. Remove debug code; check for secrets, personal paths and generated files.
4. **Verify.** Run the project's lint and tests (commands are in its `CLAUDE.md`). On a failure, fix it or stop and report; don't ship red. Make sure `CHANGELOG.md` (`## Unreleased`) and the docs cover user-visible changes.
5. **Review.** For non-trivial changes, have the `production-reviewer` agent review the diff and fix any blockers.
6. **Commits.** Make focused commits, one concern each, staging by path. Subject in the imperative, 72 characters or fewer; body says what and why; reference issues with `Refs #N`. WIP commits from `/handoff` or `/vult-fast` may be reshaped here; update the remote with `git push --force-with-lease` on your own unmerged branch only.
7. **PR.** Run `git push -u origin HEAD`, then `gh pr create --body-file <file>` with Summary, Changes, Testing (commands and results), Not verified, and `Refs #N` (`Fixes #N` only if verified). If a draft PR already exists, update it and mark it ready with `gh pr ready`.
8. **CI.** Run `gh pr checks --watch`. On a failure, read `gh run view <id> --log-failed`, fix it in a new commit, and repeat.
9. **Merge** only when every check is green and the user confirms: `gh pr merge --merge --delete-branch`. Then `gh run list --branch <default> -L 3` to confirm the default branch is green, and `git switch <default> && git pull --ff-only`.
10. **Close the loop.** Comment on each issue with the commits, what was verified, and what wasn't. Report the PR URL.
