#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/parse_project.sh"

case "$registry_type" in
  gcr)
    list_cmd="get_gcr_image_tags $name $namespace"
    ;;
  *)
    abort "Unsupported registry: $registry_type"
    ;;
esac

if ! $list_cmd | grep "^$version$" &> /dev/null; then
  abort "Not found $name:$version on the remote"
fi

git tag "$name/$version"
git push --tags
