#!/bin/bash

scan_todos() {
    local scan_path="$1"
    local tags="$2"
    local include_patterns="$3"
    local exclude_patterns="$4"
    local changed_only="$5"
    local base_ref="$6"
    local head_ref="$7"

    local cmd="./todo-tree scan --json"

    if [ -n "$tags" ]; then
        cmd="$cmd --tags $tags"
    fi

    if [ -n "$include_patterns" ]; then
        cmd="$cmd --include $include_patterns"
    fi

    if [ -n "$exclude_patterns" ]; then
        cmd="$cmd --exclude $exclude_patterns"
    fi

    if [ "$changed_only" = "true" ] && [ -n "$base_ref" ]; then
        log_info "Scanning only changed files..."

        local changed_files
        changed_files=$(get_changed_files "$base_ref" "$head_ref" "$include_patterns")

        if [ -z "$changed_files" ]; then
            log_info "No changed files to scan"
            echo '{"files":[],"summary":{"total_count":0,"files_with_todos":0,"files_scanned":0,"tag_counts":{}}}' > todos.json
            return 0
        fi

        log_info "Changed files: $changed_files"

        local total_todos=0
        local files_json="[]"

        for file in $changed_files; do
            if [ -f "$file" ]; then
                log_info "Scanning: $file"
                local result
                result=$($cmd "$file" 2>/dev/null || echo '{"files":[],"summary":{"total_count":0}}')

                local file_todos
                file_todos=$(echo "$result" | jq -r '.files // []')
                files_json=$(echo "$files_json" | jq --argjson new "$file_todos" '. + $new')

                local file_total
                file_total=$(echo "$result" | jq -r '.summary.total_count // 0')
                total_todos=$((total_todos + file_total))
            fi
        done

        echo "{\"files\":$files_json,\"summary\":{\"total_count\":$total_todos}}" | jq '.' > todos.json
    else
        log_info "Scanning path: ${scan_path:-.}"
        $cmd "${scan_path:-.}" > todos.json 2>/dev/null || echo '{"files":[],"summary":{"total_count":0,"files_with_todos":0,"files_scanned":0,"tag_counts":{}}}' > todos.json
    fi

    log_success "Scan complete"
}
