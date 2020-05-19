#!/usr/bin/env bash

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

name="$1"
if [ -z "$name" ]; then
  abort 'name is required'
fi

version="$2"
if [ -z "$version_required" -a -z "$version" ]; then
  abort 'version is required'
fi

project="$(get_project "$name")"
if [ -z "$project" ]; then
  abort "Cannot find project for $name"
fi

registry_type="$(get_registry_type "$project")"
namespace="$(get_namespace "$project")"
