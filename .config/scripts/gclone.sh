#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <repository-name>"
  exit 1
fi

repo="$1"
git clone "git@github.com:sinsenti/${repo}.git"
