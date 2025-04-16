#!/bin/bash

# Prompt the user for the commit message
read -p "Enter commit message (or press Enter for auto-push): " commit_message

# If no input is provided (user pressed Enter), generate an auto-commit message
if [ -z "$commit_message" ]; then
  commit_message="Auto-push: $(date +'%Y-%m-%d %H:%M:%S')"
# If the user typed 'auto', generate an auto-commit message
elif [ "$commit_message" == "auto" ]; then
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
