#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

check_tags() {
  local name=$1
  local version
  local tag
  while read version; do
    tag="$name/$version"
    info -n "Check if image for $tag exists..."
    code=$(curl -s -o /dev/null -w "%{http_code}" https://hub.docker.com/v2/repositories/mirror4gcr/$name/tags/$version/)
    if [ "$code" = "404" ]; then
      info 'Not exist, delete the tag.'
      git push -d origin $tag
      git tag -d $tag
    else
      info 'Exist.'
    fi
  done < <(git tag -l "$name/*" | sed "s/^$name\///")
}

while read name registry namespace; do
  check_tags $name
done < "$rootdir/projects.txt"
