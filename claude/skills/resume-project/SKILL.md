---
name: resume-project
description: Resume work on the current repository on any workstation - sync the branch, read the project CLAUDE.md, the latest /handoff note, CI and issue status, then summarise where things stand and the next steps. Use at the start of a session or after switching machines.
argument-hint: "[branch or PR number]"
---

# /resume-project

Target: $ARGUMENTS (default: the current branch)

Stay read-only until the user agrees the plan. Fetching and fast-forwarding are fine.

1. **Sync.** Run `git fetch --prune`, then check the current branch, `git status` and ahead/behind.
   - Given a PR or branch with a clean worktree: `gh pr checkout <n>` or `git switch <branch>`.
   - Fast-forward only (`git pull --ff-only`). Never discard or stash local changes yourself. If the branch has diverged, stop and report.
2. **Project context.** Read the project's `CLAUDE.md` (commands, freezes, current state) and the `## Unreleased` section of `CHANGELOG.md`.
3. **Latest handoff.** `gh pr view --json number,title,state,isDraft,body,comments`. Use the newest comment that contains `<!-- handoff -->`; if there isn't one, look at the linked issue's comments.
4. **Status.** Check `gh pr checks`, `gh run list --branch <branch> -L 3`, the linked issues, and open `release-blocker` issues.
5. **Health.** Run the project's fast test command if it's cheap, and report the result.
6. **Summary**, briefly:
   - where things stand;
   - commits since the handoff note;
   - next steps from the note, checked against the current code;
   - blockers, risks and open questions.

   Then ask which step to start with.
