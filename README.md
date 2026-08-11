# Todo Tree Action

GitHub Action that scans pull requests for TODO-style comments and posts a summary on the PR.

## Features

- Finds `TODO`, `FIXME`, `BUG`, and 14 other built-in tags, plus custom ones
- Can scan only changed files in the PR
- Can show only TODOs newly introduced in the PR
- Adds GitHub annotations on matching lines
- Can fail the workflow based on rules (`fail-on-todos`, `fail-on-fixme`, `max-todos`)
- Posts a new PR comment on every run
- Supports Linux and macOS (x86_64 and arm64)

## Quick Start

Add this workflow (for example: `.github/workflows/todo-tree.yml`):

```yaml
name: Todo Tree

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  scan-todos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - uses: alexandretrotel/todo-tree-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Common Options

```yaml
- uses: alexandretrotel/todo-tree-action@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    changed-only: true
    new-only: true
    fail-on-fixme: true
    max-todos: 10
```

## Inputs

| Input | Default | Notes |
|-------|---------|-------|
| `github-token` | `${{ github.token }}` | Token for PR comments |
| `path` | `.` | Root path to scan |
| `tags` | _(all built-in tags, see below)_ | Comma-separated tags |
| `include-patterns` | _(empty)_ | Include glob list |
| `exclude-patterns` | _(empty)_ | Exclude glob list |
| `changed-only` | `false` | Scan only changed files |
| `new-only` | `false` | Show only TODOs new in this PR |
| `fail-on-todos` | `false` | Fail when any TODO exists |
| `fail-on-fixme` | `false` | Fail when `FIXME` or `BUG` exists |
| `max-todos` | _(empty)_ | Fail if count exceeds this value |
| `show-annotations` | `true` | Create GitHub annotations |
| `max-annotations` | `50` | GitHub limit is 50 |
| `post-comment` | `true` | Post a PR summary comment |
| `update-comment` | `true` | Update the existing summary comment instead of posting a new one each run |

Default `tags` value (17 built-in tags):
`TODO`, `WIP`, `MAYBE`, `FIXME`, `BUG`, `ERROR`, `HACK`, `WARN`, `WARNING`, `FIX`, `NOTE`, `XXX`, `INFO`, `DOCS`, `PERF`, `TEST`, `IDEA`

## Outputs

- `total`: Total TODO count
- `files_count`: Number of files with TODOs
- `has_todos`: `true` when at least one TODO was found
- `json`: Full JSON output from `todo-tree`

## Comment Format

The PR comment groups items in a single table, sorted by priority, with an alert banner and clickable file links:

```markdown
## Todo Tree Summary

> [!WARNING]
> Found **12** TODO(s) across **5** file(s) — **2 Critical**

### Details

| Priority | Tag | Location | Message |
|---|---|---|---|
| 🔴 Critical | `FIXME` | [`src/auth.rs:42`](https://github.com/owner/repo/blob/sha/src/auth.rs#L42) | Handle token refresh |
| 🟠 High | `HACK` | [`src/db.rs:88`](https://github.com/owner/repo/blob/sha/src/db.rs#L88) | Replace with proper migration |
| 🟡 Medium | `TODO` | [`src/api.rs:15`](https://github.com/owner/repo/blob/sha/src/api.rs#L15) | Implement error handling |

<sub>Last updated Aug 11, 2026, 00:00 UTC · [todo-tree](https://github.com/alexandretrotel/todo-tree)</sub>
```

## Requirements

- Use `actions/checkout` with `fetch-depth: 0` when using `changed-only` or `new-only`
- Grant `pull-requests: write` permission to post PR comments
