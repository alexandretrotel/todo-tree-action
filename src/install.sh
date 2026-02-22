#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

    local ARCH
    ARCH=$(uname -m)
    local OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    local binary
    case "$ARCH" in
        x86_64)
            if [ "$OS" = "linux" ]; then
                binary="todo-tree-x86_64-unknown-linux-gnu.tar.gz"
            elif [ "$OS" = "darwin" ]; then
                binary="todo-tree-x86_64-apple-darwin.tar.gz"
            else
                log_error "Unsupported OS: $OS"
                return 1
            fi
            ;;
        aarch64|arm64)
            if [ "$OS" = "linux" ]; then
                binary="todo-tree-aarch64-unknown-linux-gnu.tar.gz"
            elif [ "$OS" = "darwin" ]; then
                binary="todo-tree-aarch64-apple-darwin.tar.gz"
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

    local download_url
    download_url="https://github.com/alexandretrotel/todo-tree/releases/latest/download/${binary}"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "Downloading todo-tree to temporary directory $tmp_dir..."

    if ! curl -fsSL "$download_url" | tar -xz -C "$tmp_dir"; then
        log_error "Failed to download or extract todo-tree from $download_url"
        rm -rf "$tmp_dir"
        return 1
    fi

    local todo_binary
    todo_binary=$(find "$tmp_dir" -type f -name "todo-tree" | head -n 1)
    if [ -z "$todo_binary" ]; then
        todo_binary=$(find "$tmp_dir" -type f -name "todo-tree-*" | head -n 1)
    fi

    if [ -z "$todo_binary" ]; then
        todo_binary=$(find "$tmp_dir" -type f -executable | head -n 1)
    fi

    if [ -z "$todo_binary" ]; then
        log_error "todo-tree binary not found in the archive"
        log_error "Archive contents:"
        find "$tmp_dir" -type f
        rm -rf "$tmp_dir"
        return 1
    fi

    log_info "Found binary at: $todo_binary"

    if [ ! -f "$todo_binary" ]; then
        log_error "Binary path exists but is not a file: $todo_binary"
        rm -rf "$tmp_dir"
        return 1
    fi

    chmod +x "$todo_binary"
    cp "$todo_binary" ./todo-tree

    if [ ! -f ./todo-tree ]; then
        log_error "Failed to copy binary to current directory"
        rm -rf "$tmp_dir"
        return 1
    fi

    chmod +x ./todo-tree
    rm -rf "$tmp_dir"

    log_success "todo-tree installed successfully"
    return 0
}
