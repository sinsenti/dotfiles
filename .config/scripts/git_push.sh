#!/bin/bash

# Prompt the user for the commit message
read -p "Enter commit message (or type 'auto' for autocommit): " commit_message

# If the user typed 'auto', generate an auto-commit message
if [ "$commit_message" == "auto" ]; then
  commit_message="Auto-commit: $(date +'%Y-%m-%d %H:%M:%S')"
fi

# Stage all changes
git add .

# Commit changes with the chosen message
git commit -m "$commit_message"

# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Push to the current branch
git push origin "$current_branch"

echo "Changes pushed to origin $current_branch with message: $commit_message"
