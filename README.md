# Todo Tree Action

A GitHub Action that scans your pull requests for TODO comments and posts a summary as a PR comment.

## Features

- Scans code for TODO, FIXME, BUG, and custom tags
- Posts a formatted summary comment on PRs
- Updates existing comments on subsequent runs
- Configurable file patterns and paths

## Usage

Add this to your workflow file (e.g., `.github/workflows/todo-tree.yml`):

```yaml
name: Todo Tree

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  scan-todos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Scan for TODOs
        uses: alexandretrotel/todo-tree-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github-token` | GitHub token for posting comments | Yes | `${{ github.token }}` |
| `path` | Path to scan | No | `.` |
| `tags` | Comma-separated tags to search for | No | `TODO,FIXME,BUG` |
| `include-patterns` | File patterns to include | No | - |
| `fail-on-todos` | Fail the action if TODOs are found | No | `false` |

## Example Output

The action posts a comment like this on your PR:

```
## TODO Summary

Found **3** TODOs in this PR:

### `src/main.rs`
- **TODO** (line 42): Implement error handling
- **FIXME** (line 87): This is a workaround

### `src/lib.rs`
- **BUG** (line 15): Race condition here
```

## License

MIT
