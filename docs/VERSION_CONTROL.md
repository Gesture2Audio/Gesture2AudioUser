# Version-Control Workflow

This project should use Git for every meaningful change.

## Repository Rule

Keep the Git repository rooted at:

```text
C:/Users/USER/Desktop/G2A
```

Use this GitHub repository as the project remote:

```text
https://github.com/Gesture2Audio/Gesture2AudioUser.git
```

## Before Changing Files

1. Check the current state:

```powershell
git status --short
```

2. If there are unexpected changes, inspect them before editing:

```powershell
git diff
```

## During Each Change

Update documentation in the same change when relevant:

- `docs/CHANGELOG.md` for notable changes
- `docs/DECISIONS.md` for decisions that affect design, research framing, model behavior, or architecture
- `docs/PROJECT_BRIEF.md` when the project scope, pipeline, data, or plan changes

## Commit Style

Use small commits with clear messages.

Recommended commit format:

```text
area: short summary
```

Examples:

```text
docs: add initial research brief
data: add dataset audit script
model: add baseline gesture classifier
audio: add layered soundscape engine
watch: add shake trigger capture
```

## Definition of Done

A change is done when:

- files are edited
- relevant docs are updated
- validation is run or the reason it was not run is documented
- `git status --short` is reviewed
- a Git commit is created when the change is complete

## Data Handling

Track source JSON samples if they are part of the research dataset. Avoid committing duplicate archives, temporary files, generated model checkpoints, cache directories, and operating-system metadata.
