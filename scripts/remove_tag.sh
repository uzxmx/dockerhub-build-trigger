#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/parse_project.sh"

tag="$name/$version"
git push -d origin $tag
git tag -d $tag
