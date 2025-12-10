#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

install_todo_tree() {
    log_info "Installing todo-tree..."

    # Detect architecture
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$ARCH" in
        x86_64)
            if [ "$OS" = "linux" ]; then
                BINARY="todo-tree-x86_64-unknown-linux-gnu.tar.gz"
            elif [ "$OS" = "darwin" ]; then
                BINARY="todo-tree-x86_64-apple-darwin.tar.gz"
            else
                log_error "Unsupported OS: $OS"
                exit 1
            fi
            ;;
        aarch64|arm64)
            if [ "$OS" = "linux" ]; then
                BINARY="todo-tree-aarch64-unknown-linux-gnu.tar.gz"
            elif [ "$OS" = "darwin" ]; then
                BINARY="todo-tree-aarch64-apple-darwin.tar.gz"
            else
                log_error "Unsupported OS: $OS"
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/alexandretrotel/todo-tree/releases/latest/download/${BINARY}"
    TMP_DIR=$(mktemp -d)
    log_info "Downloading todo-tree to temporary directory $TMP_DIR..."

    # Download and extract
    if ! curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"; then
        log_error "Failed to download or extract todo-tree from $DOWNLOAD_URL"
        exit 1
    fi

    # Find the binary
    TODO_BINARY=$(find "$TMP_DIR" -type f -name "todo-tree" | head -n 1)
    if [ -z "$TODO_BINARY" ]; then
        log_error "todo-tree binary not found in the archive"
        exit 1
    fi

    chmod +x "$TODO_BINARY"

    # Copy to current working directory
    cp "$TODO_BINARY" ./todo-tree
    log_success "todo-tree installed successfully"
}

get_changed_files() {
    local base_ref="$1"
    local head_ref="$2"
    local file_patterns="$3"

    log_info "Fetching changed files between $base_ref and $head_ref..."

    # Fetch the base branch to compare
    git fetch origin "$base_ref" --depth=1 2>/dev/null || true

    # Get list of changed files
    local changed_files
    changed_files=$(git diff --name-only --diff-filter=ACMRT "origin/$base_ref"..."$head_ref" 2>/dev/null || \
                    git diff --name-only --diff-filter=ACMRT "origin/$base_ref" 2>/dev/null || \
                    echo "")

    # Filter by patterns if specified
    if [ -n "$file_patterns" ]; then
        local filtered_files=""
        IFS=',' read -ra PATTERNS <<< "$file_patterns"
        for file in $changed_files; do
            for pattern in "${PATTERNS[@]}"; do
                pattern=$(echo "$pattern" | xargs) # trim whitespace
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

scan_todos() {
    local scan_path="$1"
    local tags="$2"
    local include_patterns="$3"
    local exclude_patterns="$4"
    local changed_only="$5"
    local base_ref="$6"
    local head_ref="$7"

    # Build the command
    local cmd="./todo-tree scan --json"

    # Add tags if specified
    if [ -n "$tags" ]; then
        cmd="$cmd --tags $tags"
    fi

    # Add include patterns if specified
    if [ -n "$include_patterns" ]; then
        cmd="$cmd --include $include_patterns"
    fi

    # Add exclude patterns if specified
    if [ -n "$exclude_patterns" ]; then
        cmd="$cmd --exclude $exclude_patterns"
    fi

    # Handle changed-files-only mode
    if [ "$changed_only" = "true" ] && [ -n "$base_ref" ]; then
        log_info "Scanning only changed files..."

        local changed_files
        changed_files=$(get_changed_files "$base_ref" "$head_ref" "$include_patterns")

        if [ -z "$changed_files" ]; then
            log_info "No changed files to scan"
            echo '{"files":[],"summary":{"total":0,"by_tag":{},"by_priority":{}}}' > todos.json
            return 0
        fi

        log_info "Changed files: $changed_files"

        # Scan each changed file individually and merge results
        local all_results='{"files":[],"summary":{"total":0,"by_tag":{},"by_priority":{}}}'
        local total_todos=0
        local files_json="[]"

        for file in $changed_files; do
            if [ -f "$file" ]; then
                log_info "Scanning: $file"
                local result
                result=$($cmd "$file" 2>/dev/null || echo '{"files":[],"summary":{"total":0}}')

                # Extract files array and merge
                local file_todos
                file_todos=$(echo "$result" | jq -r '.files // []')
                files_json=$(echo "$files_json" | jq --argjson new "$file_todos" '. + $new')

                # Count totals
                local file_total
                file_total=$(echo "$result" | jq -r '.summary.total // 0')
                total_todos=$((total_todos + file_total))
            fi
        done

        # Build final result
        echo "{\"files\":$files_json,\"summary\":{\"total\":$total_todos}}" | jq '.' > todos.json
    else
        # Scan entire path
        log_info "Scanning path: ${scan_path:-.}"
        $cmd "${scan_path:-.}" > todos.json 2>/dev/null || echo '{"files":[],"summary":{"total":0}}' > todos.json
    fi

    log_success "Scan complete"
}

find_new_todos() {
    local base_ref="$1"

    log_info "Comparing TODOs with base branch ($base_ref) to find new ones..."

    # Stash current todos
    cp todos.json todos_current.json

    # Checkout base branch and scan
    git stash push -m "todo-tree-action" 2>/dev/null || true
    git checkout "origin/$base_ref" --quiet 2>/dev/null || {
        log_warning "Could not checkout base branch, showing all TODOs"
        mv todos_current.json todos.json
        return 0
    }

    ./todo-tree scan --json . > todos_base.json 2>/dev/null || echo '{"files":[],"summary":{"total":0}}' > todos_base.json

    # Return to head
    git checkout - --quiet 2>/dev/null || true
    git stash pop --quiet 2>/dev/null || true
    mv todos_current.json todos.json

    # Compare and find new TODOs using jq
    # A TODO is "new" if it doesn't exist in the base branch at the same file:line
    jq -s '
        (.[1].files // []) as $base_files |
        (.[1].files // [] | [.[] | .todos[] | {key: "\(.path):\(.line)", value: .}] | from_entries) as $base_lookup |
        .[0] | .files = [
            .files[] |
            .todos = [.todos[] | select($base_lookup["\(.path // empty):\(.line)"] == null)] |
            select(.todos | length > 0)
        ] |
        .summary.total = ([.files[].todos | length] | add // 0) |
        .summary.new_only = true
    ' todos.json todos_base.json > todos_new.json 2>/dev/null || cp todos.json todos_new.json

    mv todos_new.json todos.json
    log_success "Filtered to new TODOs only"
}

generate_annotations() {
    local max_annotations="${1:-50}"

    log_info "Generating GitHub annotations..."

    # Read todos and generate annotation commands
    jq -r --argjson max "$max_annotations" '
        .files[]? |
        .path as $path |
        .todos[:$max][] |
        "::warning file=\($path),line=\(.line)::\(.tag): \(.text)"
    ' todos.json 2>/dev/null | head -n "$max_annotations"
}

check_fail_conditions() {
    local fail_on_todos="$1"
    local fail_on_fixme="$2"
    local max_todos="$3"

    local total
    total=$(jq -r '.summary.total // 0' todos.json)

    local fixme_count
    fixme_count=$(jq -r '[.files[]?.todos[]? | select(.tag == "FIXME" or .tag == "BUG")] | length' todos.json 2>/dev/null || echo "0")

    # Check fail conditions
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

set_outputs() {
    local total
    total=$(jq -r '.summary.total // 0' todos.json)

    local files_count
    files_count=$(jq -r '.files | length' todos.json 2>/dev/null || echo "0")

    # Set outputs for GitHub Actions
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "total=$total" >> "$GITHUB_OUTPUT"
        echo "files_count=$files_count" >> "$GITHUB_OUTPUT"
        echo "has_todos=$([ "$total" -gt 0 ] && echo 'true' || echo 'false')" >> "$GITHUB_OUTPUT"

        # Set JSON output (escaped for multiline)
        {
            echo 'json<<EOF'
            cat todos.json
            echo 'EOF'
        } >> "$GITHUB_OUTPUT"
    fi

    log_info "Found $total TODO(s) in $files_count file(s)"
}

main() {
    log_info "Starting Todo Tree Action..."

    # Read inputs from environment (set by GitHub Actions)
    local path="${INPUT_PATH:-.}"
    local tags="${INPUT_TAGS:-}"
    local include_patterns="${INPUT_INCLUDE_PATTERNS:-}"
    local exclude_patterns="${INPUT_EXCLUDE_PATTERNS:-}"
    local changed_only="${INPUT_CHANGED_ONLY:-false}"
    local new_only="${INPUT_NEW_ONLY:-false}"
    local fail_on_todos="${INPUT_FAIL_ON_TODOS:-false}"
    local fail_on_fixme="${INPUT_FAIL_ON_FIXME:-false}"
    local max_todos="${INPUT_MAX_TODOS:-}"
    local show_annotations="${INPUT_SHOW_ANNOTATIONS:-true}"
    local max_annotations="${INPUT_MAX_ANNOTATIONS:-50}"

    # GitHub context
    local base_ref="${GITHUB_BASE_REF:-main}"
    local head_ref="${GITHUB_HEAD_REF:-HEAD}"

    # Install todo-tree
    install_todo_tree

    # Scan for TODOs
    scan_todos "$path" "$tags" "$include_patterns" "$exclude_patterns" "$changed_only" "$base_ref" "$head_ref"

    # Filter to new TODOs only if requested
    if [ "$new_only" = "true" ]; then
        find_new_todos "$base_ref"
    fi

    # Generate annotations if enabled
    if [ "$show_annotations" = "true" ]; then
        generate_annotations "$max_annotations"
    fi

    # Set outputs
    set_outputs

    # Check fail conditions
    if ! check_fail_conditions "$fail_on_todos" "$fail_on_fixme" "$max_todos"; then
        exit 1
    fi

    log_success "Todo Tree Action completed successfully"
}

# Run main function
main "$@"
