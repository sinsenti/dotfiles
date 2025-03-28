#!/bin/bash

# Prompt the user for the commit message
read -p "Enter commit message: " commit_message

# Stage all changes
git add .

# Commit changes with the provided message
git commit -m "$commit_message"

# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Push to the current branch
git push origin "$current_branch"

echo "Changes pushed to origin $current_branch with message: $commit_message"
