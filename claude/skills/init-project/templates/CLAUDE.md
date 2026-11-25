# CLAUDE.md

<One paragraph: what this project is, who uses it, what it runs on, and how it ships.> The global standards apply; this file holds what's specific to this repo and wins where they differ.

## Commands

```
<install / restore dependencies>
<lint>
<unit tests>
<build>
<run, or self-test: exit 0 = pass>
```

- <Notes: what needs a desktop session, real hardware, network, secrets, ...>

## CI

- `.github/workflows/ci.yml`: <what runs, on which OS and runtime versions>.
- <Release workflow, if any: trigger, what it builds, that it creates a draft.>

## Design decisions to preserve

Don't change these without an issue that discusses the trade-off:

- **<Decision>.** <Why.>

## Versioning and releases

- The version lives only in `<file>` (`<symbol>`).
- Release procedure: <link to docs, or the steps that differ from the global default>.
- Manual acceptance checklist: <where it lives>.

## Current state

- **Releases:** <latest stable, current RC, open acceptance issue>.
- **In progress:** <issues or PRs>.
