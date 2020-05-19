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

tag="$name/$version"
git push -d origin $tag
git tag -d $tag
