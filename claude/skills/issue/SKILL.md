---
name: issue
description: Create a well-formed GitHub Issue (bug, enhancement, tech debt, acceptance checklist) after checking for duplicates, or add findings to an existing one. Use when a problem or piece of work needs tracking.
argument-hint: "<short description, or an issue number to update>"
---

# /issue

Request: $ARGUMENTS

1. **Duplicates.** `gh issue list --state all --search "<keywords>" -L 20`. If an issue already covers it, show it and propose a comment on it instead of a new issue.
2. **Facts.** For a bug, find the relevant code and reproduce it if that's cheap. Keep confirmed facts apart from suspected causes.
3. **Draft.** Title: specific, with the symptom and where it happens. Body by type:
   - **Bug**: Summary; Steps to reproduce; Expected; Actual; Environment (version or commit, OS, hardware, managed or not); Evidence (`file:line`, trimmed log lines); Suspected cause (marked unverified); Acceptance criteria.
   - **Enhancement**: Problem; Proposal; Out of scope; Acceptance criteria.
   - **Tech debt**: Current state; Risk; Proposed change; why it can wait.
   - **Acceptance (release)**: the version under test, then a checklist of manual checks, each with configuration and expected result.
   - **Labels**: pick from `gh label list`; don't invent new ones.
4. **Confirm**, then create it: write the body to a temporary file and run `gh issue create --title "..." --body-file <file> --label <l>`. For an update, use `gh issue comment <n> --body-file <file>`. Report the URL.

Never put credentials, tokens, personal data or unredacted logs in an issue.
