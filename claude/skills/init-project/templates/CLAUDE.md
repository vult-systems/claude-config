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

- `.github/workflows/ci.yml`: <what runs, on which OS and runtime versions, and which changes skip the tests>. The required check is `ci`.
- <Release workflow, if any: trigger, what it builds, that it creates a draft.>

## Design decisions to preserve

- **<Decision>.** <Why.>

## Versioning and releases

- The version lives only in `<file>` (`<symbol>`).
- Releases: <direct stable releases, or release candidates with an acceptance checklist, and why>.

## Current state

- **Releases:** <latest release, current RC and acceptance issue if any>.
- **Feature freeze:** <none, or what is frozen until when>.
- **In progress:** <issues or PRs>.
