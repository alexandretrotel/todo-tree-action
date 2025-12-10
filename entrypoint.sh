#!/bin/bash
set -e

# Download and install todo-tree
echo "Installing todo-tree..."
curl -fsSL https://github.com/alexandretrotel/todo-tree/releases/latest/download/todo-tree-x86_64-unknown-linux-gnu.tar.gz | tar xz
chmod +x todo-tree

# Build the command
CMD="./todo-tree --format json"

# Add path if specified
if [ -n "$INPUT_PATH" ]; then
    CMD="$CMD $INPUT_PATH"
else
    CMD="$CMD ."
fi

# Run todo-tree and capture output
echo "Scanning for TODOs..."
$CMD > todos.json || true

# Output the results
echo "Scan complete. Results saved to todos.json"
cat todos.json
