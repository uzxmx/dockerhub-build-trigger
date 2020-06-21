#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

source "$rootdir/scripts/utils.sh"

if [ -n "$TRAVIS_GITHUB_TOKEN" ]; then
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "Travis CI"
  git remote set-url origin https://${TRAVIS_GITHUB_TOKEN}@github.com/uzxmx/dockerhub-build-trigger.git
fi

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

    # If we push many tags one time, dockerhub may not pick up all. So instead
    # we push one tag one time. We also sleep some time to avoid putting much
    # pressure to github and dockerhub.
    git push --tags
    sleep 2
  done

  info "Finished to trigger dockerhub build for $name"
}

check_gcr() {
  local name=$1
  local namespace=$2
  info "Check gcr for $name"
  get_gcr_image_tags $name $namespace | filter_versions $name | trigger_dockerhub_build $name
  info "Finished checking gcr for $name"
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
