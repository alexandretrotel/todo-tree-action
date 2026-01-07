#!/bin/bash

set -e

# Source shared installation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/install.sh"

# Override log functions with TEST prefix for clarity
log_info() {
    echo -e "${BLUE}[TEST INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[TEST ERROR]${NC} $1"
}

# Test 1: Download and extract real binary using shared install function
test_real_download() {
    log_info "Test 1: Real download and extraction using shared install function"

    # Create a temporary directory for testing
    TEST_INSTALL_DIR=$(mktemp -d)

    # Change to test directory
    pushd "$TEST_INSTALL_DIR" > /dev/null

    # Use the shared install function
    if install_todo_tree; then
        log_success "Shared install function succeeded"

        # Verify the binary was installed
        if [ -f "./todo-tree" ]; then
            log_success "Binary installed at ./todo-tree"

            # Test if it's actually a binary
            log_info "File type: $(file ./todo-tree)"

            # Test execution
            if ./todo-tree --version 2>/dev/null; then
                log_success "Binary works! Version:"
                ./todo-tree --version
            else
                log_error "Binary doesn't execute or doesn't support --version"
                popd > /dev/null
                rm -rf "$TEST_INSTALL_DIR"
                return 1
            fi
        else
            log_error "Binary not found at ./todo-tree"
            popd > /dev/null
            rm -rf "$TEST_INSTALL_DIR"
            return 1
        fi
    else
        log_error "Shared install function failed"
        popd > /dev/null
        rm -rf "$TEST_INSTALL_DIR"
        return 1
    fi

    # Clean up
    popd > /dev/null
    rm -rf "$TEST_INSTALL_DIR"
    log_success "Test 1 completed successfully"
}

# Test 2: Simulate different archive structures
test_archive_structures() {
    log_info "Test 2: Testing different archive structures"

    TEST_DIR=$(mktemp -d)

    # Structure 1: Binary at root
    log_info "Testing structure: binary at root"
    STRUCT1="$TEST_DIR/struct1"
    mkdir -p "$STRUCT1"
    echo "fake binary" > "$STRUCT1/todo-tree"
    chmod +x "$STRUCT1/todo-tree"

    FOUND=$(find "$STRUCT1" -type f -name "todo-tree" | head -n 1)
    if [ -n "$FOUND" ]; then
        log_success "Structure 1: Found at $FOUND"
    else
        log_error "Structure 1: Not found"
    fi

    # Structure 2: Binary in subdirectory
    log_info "Testing structure: binary in subdirectory"
    STRUCT2="$TEST_DIR/struct2"
    mkdir -p "$STRUCT2/todo-tree-x86_64-unknown-linux-gnu"
    echo "fake binary" > "$STRUCT2/todo-tree-x86_64-unknown-linux-gnu/todo-tree"
    chmod +x "$STRUCT2/todo-tree-x86_64-unknown-linux-gnu/todo-tree"

    FOUND=$(find "$STRUCT2" -type f -name "todo-tree" | head -n 1)
    if [ -n "$FOUND" ]; then
        log_success "Structure 2: Found at $FOUND"
    else
        log_error "Structure 2: Not found"
    fi

    # Structure 3: Binary with suffix
    log_info "Testing structure: binary with suffix"
    STRUCT3="$TEST_DIR/struct3"
    mkdir -p "$STRUCT3"
    echo "fake binary" > "$STRUCT3/todo-tree-x86_64"
    chmod +x "$STRUCT3/todo-tree-x86_64"

    FOUND=$(find "$STRUCT3" -type f -name "todo-tree-*" | head -n 1)
    if [ -n "$FOUND" ]; then
        log_success "Structure 3: Found at $FOUND"
    else
        log_error "Structure 3: Not found"
    fi

    # Clean up
    rm -rf "$TEST_DIR"
    log_success "Test 2 completed successfully"
}

# Test 3: Run the actual entrypoint in a controlled way
test_entrypoint() {
    log_info "Test 3: Testing entrypoint script"

    # Set up minimal environment
    export INPUT_PATH="."
    export INPUT_TAGS="TODO,FIXME"
    export INPUT_CHANGED_ONLY="false"
    export INPUT_NEW_ONLY="false"
    export INPUT_FAIL_ON_TODOS="false"
    export INPUT_FAIL_ON_FIXME="false"
    export INPUT_SHOW_ANNOTATIONS="false"
    export INPUT_MAX_ANNOTATIONS="50"

    # Run in a subshell to avoid affecting current environment
    (
        cd "$(dirname "$0")/.."
        if bash entrypoint.sh 2>&1; then
            log_success "Entrypoint script completed successfully"
        else
            log_error "Entrypoint script failed"
            exit 1
        fi
    )
}

# Main test runner
main() {
    log_info "Starting todo-tree-action installation tests"
    echo ""

    # Run tests
    test_real_download
    echo ""

    test_archive_structures
    echo ""

    test_entrypoint
    echo ""

    log_info "All tests completed!"
}

# Run tests
main "$@"
