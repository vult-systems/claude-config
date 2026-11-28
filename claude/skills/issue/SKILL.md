---
name: issue
description: Create a well-formed GitHub Issue (bug, enhancement, tech debt, acceptance checklist) after checking for duplicates, or add to an existing one. Use when meaningful work needs tracking.
argument-hint: "<short description, or an issue number to update>"
---

# /issue

Request: $ARGUMENTS

1. **Existing issues.** `gh issue list --state all --search "<keywords>" -L 20`. If one covers it, or the work belongs to a larger open issue, propose a comment or a checklist item there instead of a new issue.
2. **Facts.** For a bug, find the relevant code and reproduce it if that's cheap. Keep confirmed facts apart from suspected causes.
3. **Draft.** A specific title with the symptom and where it happens. Keep the body short:
   - **Bug**: Steps to reproduce; Expected; Actual; Environment (version or commit, OS); Evidence (`file:line`, trimmed log lines); Suspected cause (marked unverified).
   - **Enhancement**: Problem; Proposal; Acceptance criteria. Use a checklist for the smaller tasks inside it.
   - **Tech debt**: Current state; Risk; Proposed change.
   - **Acceptance (release)**: the version under test, then a checklist of manual checks, each with configuration and expected result.
   - **Labels**: pick from `gh label list`; don't invent new ones.
4. **Confirm**, then create it: write the body to a temporary file and run `gh issue create --title "..." --body-file <file> --label <l>`, or `gh issue comment <n> --body-file <file>` for an update. Report the URL.

Never put credentials, tokens, personal data or unredacted logs in an issue.
