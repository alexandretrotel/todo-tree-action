#!/bin/bash

set_outputs() {
    local total
    total=$(jq -r '.summary.total_count // 0' todos.json)

    local files_count
    files_count=$(jq -r '.files | length' todos.json 2>/dev/null || echo "0")

    if [ -n "$GITHUB_OUTPUT" ]; then
        {
            echo "total=$total"
            echo "files_count=$files_count"
            echo "has_todos=$([ "$total" -gt 0 ] && echo 'true' || echo 'false')"
        } >> "$GITHUB_OUTPUT"

        {
            echo 'json<<EOF'
            cat todos.json
            echo 'EOF'
        } >> "$GITHUB_OUTPUT"
    fi

    log_info "Found $total TODO(s) in $files_count file(s)"
}

check_fail_conditions() {
    local fail_on_todos="$1"
    local fail_on_fixme="$2"
    local max_todos="$3"

    local total
    total=$(jq -r '.summary.total_count // 0' todos.json)

    local fixme_count
    fixme_count=$(jq -r '[.files[]?.items[]? | select(.tag == "FIXME" or .tag == "BUG")] | length' todos.json 2>/dev/null || echo "0")

    if [ "$fail_on_todos" = "true" ] && [ "$total" -gt 0 ]; then
        log_error "Found $total TODO(s). Failing as requested."
        return 1
    fi

    if [ "$fail_on_fixme" = "true" ] && [ "$fixme_count" -gt 0 ]; then
        log_error "Found $fixme_count FIXME/BUG comment(s). Failing as requested."
        return 1
    fi

    if [ -n "$max_todos" ] && [ "$total" -gt "$max_todos" ]; then
        log_error "Found $total TODOs, exceeding maximum of $max_todos. Failing."
        return 1
    fi

    return 0
}
