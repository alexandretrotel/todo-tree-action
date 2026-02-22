# Todo Tree Action

GitHub Action that scans pull requests for TODO-style comments and posts a summary on the PR.

## Features

- Finds `TODO`, `FIXME`, `BUG`, and custom tags
- Can scan only changed files in the PR
- Can show only TODOs newly introduced in the PR
- Adds GitHub annotations on matching lines
- Can fail the workflow based on rules (`fail-on-todos`, `fail-on-fixme`, `max-todos`)
- Updates the same PR comment on later runs
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

      - uses: atrtde/todo-tree-action@v1.0.3
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Common Options

```yaml
- uses: atrtde/todo-tree-action@v1.0.3
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
| `tags` | `TODO,FIXME,BUG` | Comma-separated tags |
| `include-patterns` | _(empty)_ | Include glob list |
| `exclude-patterns` | _(empty)_ | Exclude glob list |
| `changed-only` | `false` | Scan only changed files |
| `new-only` | `false` | Show only TODOs new in this PR |
| `fail-on-todos` | `false` | Fail when any TODO exists |
| `fail-on-fixme` | `false` | Fail when `FIXME` or `BUG` exists |
| `max-todos` | _(empty)_ | Fail if count exceeds this value |
| `show-annotations` | `true` | Create GitHub annotations |
| `max-annotations` | `50` | GitHub limit is 50 |
| `post-comment` | `true` | Post/update PR comment |
| `comment-header` | `## TODO Summary` | Header text for PR comment |

## Outputs

- `total`: Total TODO count
- `files_count`: Number of files with TODOs
- `has_todos`: `true` when at least one TODO was found
- `json`: Full JSON output from `todo-tree`

## Comment Format

PR details use text priority labels, for example:

```text
- [High] TODO (L42): Implement error handling
- [Medium] FIXME (L87): Remove temporary workaround
```

## Requirements

- Use `actions/checkout` with `fetch-depth: 0` when using `changed-only` or `new-only`
- Grant `pull-requests: write` permission to post PR comments
