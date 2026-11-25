---
name: handoff
description: Hand off in-progress work to another workstation or session - push the branch and post a structured handoff note on its draft PR so /resume-project can continue anywhere.
argument-hint: "[notes for the next session]"
disable-model-invocation: true
---

# /handoff

Extra notes: $ARGUMENTS

GitHub is the shared state between workstations. Use only the project's branch and PR; write nothing outside the repo's normal workflow.

1. **State.** Gather the branch, `git status`, unpushed commits (`git log @{upstream}..HEAD` if there's an upstream), stashes, related issues and PR, and the last test results.
2. **Commit.** Never commit on the default branch; create the work branch if needed. Finished pieces become focused commits. Unfinished work becomes one `WIP: <what and where>` commit with `Refs #N`, which `/ship` reshapes later. Never commit secrets, `.env` files, local settings or large generated files. List anything deliberately left uncommitted in the note.
3. **Push.** `git push -u origin HEAD`.
4. **Draft PR.** If none exists: `gh pr create --draft --title "<title>" --body-file <file>`, referencing the issues.
5. **Handoff note.** Post it with `gh pr comment <n> --body-file <file>`, in this format:

   ```markdown
   <!-- handoff -->
   ## Handoff - <YYYY-MM-DD HH:MM> - <short commit hash>
   **Goal:** <one line>
   **Done:** <bullets, with commits>
   **In progress:** <bullets, with file:line>
   **Next steps:** <numbered, in order>
   **Verification:** <commands run and their results; what's not yet run>
   **Open questions / decisions:** <bullets>
   **Local-only:** <uncommitted files, tools or setup the next machine needs>
   ```

6. **Report** the PR URL, and how to resume on another workstation: `git fetch`, `git switch <branch>`, then `/resume-project`.
