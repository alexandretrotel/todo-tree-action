#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/install.sh"
source "$SCRIPT_DIR/src/inputs.sh"
source "$SCRIPT_DIR/src/git.sh"
source "$SCRIPT_DIR/src/scan.sh"
source "$SCRIPT_DIR/src/annotations.sh"
source "$SCRIPT_DIR/src/output.sh"

main() {
    log_info "Starting Todo Tree Action..."

    load_inputs
    install_todo_tree

    scan_todos \
        "$TODO_TREE_PATH" \
        "$TODO_TREE_TAGS" \
        "$TODO_TREE_INCLUDE_PATTERNS" \
        "$TODO_TREE_EXCLUDE_PATTERNS" \
        "$TODO_TREE_CHANGED_ONLY" \
        "$TODO_TREE_GITHUB_BASE_REF" \
        "$TODO_TREE_GITHUB_HEAD_REF"

    if [ "$TODO_TREE_NEW_ONLY" = "true" ]; then
        find_new_todos "$TODO_TREE_GITHUB_BASE_REF"
    fi

    if [ "$TODO_TREE_SHOW_ANNOTATIONS" = "true" ]; then
        generate_annotations "$TODO_TREE_MAX_ANNOTATIONS"
    fi

    set_outputs

    if ! check_fail_conditions "$TODO_TREE_FAIL_ON_TODOS" "$TODO_TREE_FAIL_ON_FIXME" "$TODO_TREE_MAX_TODOS"; then
        exit 1
    fi

    log_success "Todo Tree Action completed successfully"
}

main "$@"
