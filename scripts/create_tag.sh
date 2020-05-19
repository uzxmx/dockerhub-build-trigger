#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

name="$1"
if [ -z "$name" ]; then
  abort 'name is required'
fi

version="$2"
if [ -z "$version" ]; then
  abort 'version is required'
fi

project="$(get_project "$name")"
if [ -z "$project" ]; then
  abort "Cannot find project for $name"
fi

registry_type="$(get_registry_type "$project")"
namespace="$(get_namespace "$project")"

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
