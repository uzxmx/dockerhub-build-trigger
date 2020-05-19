#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

get_local_max_version() {
  local name=$1
  git tag -l "$name/*" | sed "s/^$name\///" | utils max --from-stdin
}

filter_versions() {
  local name=$1
  local local_max_version=$(get_local_max_version $name)
  local cmd
  if [ -n "$local_max_version" ]; then
    utils gt --from-stdin -t $local_max_version --sort | head -5
  else
    utils max --from-stdin
  fi
}

trigger_dockerhub_build() {
  local name=$1
  shift

  if [ -p /dev/stdin ]; then
    versions=$(cat /dev/stdin)
  else
    versions="$@"
  fi

  if [ -z "$versions" ]; then
    return
  fi

  info "Trigger dockerhub build for $name:"

  for version in $versions; do
    info $version
    git tag "$name/$version"
  done

  git push --tags
  info "Finished to trigger dockerhub build for $name"
}

check_gcr() {
  local name=$1
  local namespace=$2
  get_gcr_image_tags $name $namespace | filter_versions $name | trigger_dockerhub_build $name
}

while read name registry namespace; do
  case "$registry" in
    gcr)
      check_gcr $name $namespace
      ;;
    *)
      error "Unsupported registry: $registry"
      ;;
  esac
done < "$rootdir/projects.txt"
