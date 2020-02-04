#!/usr/bin/env bash

# Before this script will work, you need to:
# travis env set DOCKERHUB_USERNAME value
# travis env set DOCKERHUB_PASSWORD value

# fail fast
set -e

if [[ ! $# -gt 2 ]]; then
  echo "usage: $(basename $0) source_image target_image tag1 [tag2..]"
  exit 1
fi

source_image=$1; shift
target_image=$1; shift
tags="$@"

echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

for tag in $tags; do
  target="${target_image}:${tag}"
  echo "Pushing image: '$target'"
  docker tag "$source_image" "$target"
  docker push "$target"
done

# Broken - personal access tokens no longer allow updating readme?
# Set README on docker hub
#docker run -v $PWD:/workspace \
#  -e DOCKERHUB_USERNAME \
#  -e DOCKERHUB_PASSWORD \
#  -e DOCKERHUB_REPOSITORY="${target_image}" \
#  -e README_FILEPATH='/workspace/README.md' \
#  peterevans/dockerhub-description:2.1.0
