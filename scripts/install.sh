#!/bin/bash

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

# Install todo-tree binary
# Downloads the appropriate binary for the current architecture and OS
# Extracts it and places it in the current directory as ./todo-tree
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
                return 1
            fi
            ;;
        aarch64|arm64)
            if [ "$OS" = "linux" ]; then
                BINARY="todo-tree-aarch64-unknown-linux-gnu.tar.gz"
            elif [ "$OS" = "darwin" ]; then
                BINARY="todo-tree-aarch64-apple-darwin.tar.gz"
            else
                log_error "Unsupported OS: $OS"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/alexandretrotel/todo-tree/releases/latest/download/${BINARY}"
    TMP_DIR=$(mktemp -d)
    log_info "Downloading todo-tree to temporary directory $TMP_DIR..."

    # Download and extract
    if ! curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"; then
        log_error "Failed to download or extract todo-tree from $DOWNLOAD_URL"
        rm -rf "$TMP_DIR"
        return 1
    fi

    # Find the binary (search recursively)
    # First try exact match, then with prefix
    TODO_BINARY=$(find "$TMP_DIR" -type f -name "todo-tree" | head -n 1)
    if [ -z "$TODO_BINARY" ]; then
        TODO_BINARY=$(find "$TMP_DIR" -type f -name "todo-tree-*" | head -n 1)
    fi

    # Also try to find any executable file as last resort
    if [ -z "$TODO_BINARY" ]; then
        TODO_BINARY=$(find "$TMP_DIR" -type f -executable | head -n 1)
    fi

    if [ -z "$TODO_BINARY" ]; then
        log_error "todo-tree binary not found in the archive"
        log_error "Archive contents:"
        find "$TMP_DIR" -type f
        rm -rf "$TMP_DIR"
        return 1
    fi

    log_info "Found binary at: $TODO_BINARY"

    if [ ! -f "$TODO_BINARY" ]; then
        log_error "Binary path exists but is not a file: $TODO_BINARY"
        rm -rf "$TMP_DIR"
        return 1
    fi

    chmod +x "$TODO_BINARY"

    # Copy to current working directory
    cp "$TODO_BINARY" ./todo-tree

    if [ ! -f "./todo-tree" ]; then
        log_error "Failed to copy binary to current directory"
        rm -rf "$TMP_DIR"
        return 1
    fi

    chmod +x ./todo-tree

    # Clean up temporary directory
    rm -rf "$TMP_DIR"

    log_success "todo-tree installed successfully"
    return 0
}
