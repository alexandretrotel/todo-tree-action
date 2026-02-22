#!/bin/bash

generate_annotations() {
    local max_annotations="${1:-50}"

    log_info "Generating GitHub annotations..."

    jq -r --argjson max "$max_annotations" '
        .files[]? |
        .path as $path |
        .items[:$max][] |
        "::warning file=\($path),line=\(.line)::\(.tag): \(.message)"
    ' todos.json 2>/dev/null | head -n "$max_annotations"
}
