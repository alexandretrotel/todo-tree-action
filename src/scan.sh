#!/bin/bash

scan_todos() {
    local scan_path="$1"
    local tags="$2"
    local include_patterns="$3"
    local exclude_patterns="$4"
    local changed_only="$5"
    local base_ref="$6"
    local head_ref="$7"

    local cmd=(./todo-tree scan --json)

    if [ -n "$tags" ]; then
        cmd+=(--tags "$tags")
    fi

    if [ -n "$include_patterns" ]; then
        cmd+=(--include "$include_patterns")
    fi

    if [ -n "$exclude_patterns" ]; then
        cmd+=(--exclude "$exclude_patterns")
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

        local results=()

        for file in $changed_files; do
            if [ -f "$file" ]; then
                log_info "Scanning: $file"
                local result
                result=$("${cmd[@]}" "$file" 2>/dev/null || echo '{"files":[],"summary":{"total_count":0}}')
                results+=("$result")
            fi
        done

        if [ ${#results[@]} -eq 0 ]; then
            echo '{"files":[],"summary":{"total_count":0,"files_with_todos":0,"files_scanned":0,"tag_counts":{}}}' > todos.json
        else
            printf '%s\n' "${results[@]}" | jq -s '
                {
                    files: (map(.files // []) | add),
                    summary: { total_count: (map(.summary.total_count // 0) | add) }
                }
            ' > todos.json
        fi
    else
        log_info "Scanning path: ${scan_path:-.}"
        "${cmd[@]}" "${scan_path:-.}" > todos.json 2>/dev/null || echo '{"files":[],"summary":{"total_count":0,"files_with_todos":0,"files_scanned":0,"tag_counts":{}}}' > todos.json

        if [ -n "$scan_path" ] && [ "$scan_path" != "." ]; then
            local prefix="${scan_path%/}"
            jq --arg prefix "$prefix" '.files[]?.path |= ($prefix + "/" + .)' todos.json > todos.json.tmp && mv todos.json.tmp todos.json
        fi
    fi

    log_success "Scan complete"
}
