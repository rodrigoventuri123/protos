#!/usr/bin/env bash

# This script is highly inspired by https://gist.github.com/bobbytables/2fab9ac9509867b5acfe2bb5693aee71

# Exit on error
set -e

SUPPORTED_LANGUAGES=("nestjs")
GENERATED_BY=$(git remote get-url origin)

REPOSITORY_PREFIX=example-proto

# Helper for adding a directory to the stack and echoing the result
function enterDir() {
  echo "Entering $1"
  pushd $1 >/dev/null
}

# Helper for popping a directory off the stack and echoing the result
function leaveDir() {
  echo "Leaving $(pwd)"
  popd >/dev/null
}

function publish() {
  repository=$1
  version=$2

  echo "Publish ${repository} - ${version}"

  enterDir "repositories/${repository}"
  sudo cp ../../CHANGELOG.md README.md
  git add -N .

  if ! git diff --exit-code >/dev/null; then
    git add .
    git stash # Save generated content
    git rm -r . # Delete everything so we can get rid of old files that are not in proto definitions anymore
    git stash pop || true # Get back our content, there might be conflicts (due to deleting files), but that's okay
    git status
    git add .
    git commit \
      -m "Add generated version ${version} [CI]" \
      -m "${GENERATED_BY}"
    git tag -a $version -m "Version $version"
    git push --follow-tags origin HEAD
  else
    echo "No changes detected for ${repository}"
  fi

  leaveDir
}

echo "Start process"

# Prepare directory for generated libraries []
mkdir repositories

pre_version=$(git describe --abbrev=0 --tags || true)

echo "pre_version ${pre_version}"

# Semantic release - get new version
./semantic-release/bin/semantic-release.js

# Get newly created tag from semantic-version
version=$(git describe --abbrev=0 --tags)

echo "Get newly created tag from semantic-versioasn ${version}"

if [ "$pre_version" == "$version" ]; then
 echo "There was no new release. Stopping."
 exit
fi

# Iterate over available languages
for lang in "${SUPPORTED_LANGUAGES[@]}"; do
  repository="${REPOSITORY_PREFIX}-${lang}"
  echo "$(pwd) [] Generating proto stubs for ${lang}"

  # Prepare repository
  enterDir repositories
  git clone "https://${GH_TOKEN}@github.com/rodrigoventuri123/${repository}.git"
  leaveDir

  tsproto --path ./proto --output "gen/${lang}"

  sudo cp -R "proto/." "gen/${lang}"

  # Send new version to Git repository
  sudo cp -R "gen/${lang}/." "repositories/${repository}"
  publish $repository "v1.1.0"

done
