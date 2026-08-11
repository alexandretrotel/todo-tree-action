#!/bin/bash

get_changed_files() {
    local base_ref="$1"
    local head_ref="$2"
    local file_patterns="$3"

    log_info "Fetching changed files between $base_ref and $head_ref..."

    git fetch origin "$base_ref" --depth=1 2>/dev/null || true

    local changed_files
    changed_files=$(git diff --name-only --diff-filter=ACMRT "origin/$base_ref"..."$head_ref" 2>/dev/null || \
                    git diff --name-only --diff-filter=ACMRT "origin/$base_ref" 2>/dev/null || \
                    echo "")

    if [ -n "$file_patterns" ]; then
        local filtered_files=""
        IFS=',' read -ra PATTERNS <<< "$file_patterns"
        for file in $changed_files; do
            for pattern in "${PATTERNS[@]}"; do
                pattern=$(echo "${pattern}" | xargs)
                if [[ "$file" == $pattern ]]; then
                    filtered_files="$filtered_files $file"
                    break
                fi
            done
        done
        changed_files="$filtered_files"
    fi

    echo "$changed_files" | xargs
}

find_new_todos() {
    local base_ref="$1"

    log_info "Comparing TODOs with base branch ($base_ref) to find new ones..."

    cp todos.json todos_current.json

    git stash push -m "todo-tree-action" 2>/dev/null || true
    if ! git checkout "origin/$base_ref" --quiet 2>/dev/null; then
        log_warning "Could not checkout base branch, showing all TODOs"
        mv todos_current.json todos.json
        return 0
    fi

    ./todo-tree scan --json . > todos_base.json 2>/dev/null || echo '{"files":[],"summary":{"total_count":0}}' > todos_base.json

    git checkout - --quiet 2>/dev/null || true
    git stash pop --quiet 2>/dev/null || true
    mv todos_current.json todos.json

    jq -s '
        (.[1].files // []) as $base_files |
        (.[1].files // [] | [.[] | .items[] | {key: "\(.path):\(.line)", value: .}] | from_entries) as $base_lookup |
        .[0] | .files = [
            .files[] |
            .items = [.items[] | select($base_lookup["\(.path // empty):\(.line)"] == null)] |
            select(.items | length > 0)
        ] |
        .summary.total_count = ([.files[].items | length] | add // 0) |
        .summary.new_only = true
    ' todos.json todos_base.json > todos_new.json 2>/dev/null || cp todos.json todos_new.json

    mv todos_new.json todos.json
    log_success "Filtered to new TODOs only"
}
