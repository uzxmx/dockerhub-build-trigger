#!/usr/bin/env bash

set -eo pipefail

rootdir="$(dirname $BASH_SOURCE)/.."

# Build request will be canceled since Docker Hub does not support more than 30
# concurrent pending actions for one repository.
max_pending_allowed=30

source "$rootdir/scripts/utils.sh"

usage() {
  cat <<-EOF 1>&2
Check new versions by parsing projects.txt and compare local verions with remote.

Usage: $0 [-s] [-h]

[-s] Synchronize all projects by checking all newer versions than the minimum local version.
[-h] Show help
EOF
  exit 1
}

synchronize_all=
while getopts "sh" opt; do
  case "$opt" in
    s)
      synchronize_all=1
      ;;
    *)
      usage
      ;;
  esac
done

if ! which utils &> /dev/null; then
  PATH="$(realpath $rootdir/bin):$PATH"
fi

if [ "$TRAVIS_CI" = "1" -a -n "$TRAVIS_GITHUB_TOKEN" ]; then
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "Travis CI"
  git remote set-url origin https://${TRAVIS_GITHUB_TOKEN}@github.com/uzxmx/dockerhub-build-trigger.git
fi

get_local_min_version() {
  local name=$1
  git tag -l "$name/*" | sed "s/^$name\///" | utils sort --from-stdin | tail -1
}

get_local_max_version() {
  local name=$1
  git tag -l "$name/*" | sed "s/^$name\///" | utils max --from-stdin
}

filter_versions() {
  local name=$1
  local target
  if [ -n "$synchronize_all" ]; then
    target=$(get_local_min_version $name)
  fi

  if [ -z "$target" ]; then
    target=$(get_local_max_version $name)
  fi

  if [ -n "$target" ]; then
    # Here we don't limit the number of new versions in order to get all newer
    # versions than the local version. We process each version in ascending
    # order, if some error happens, next time it will continue from last failed
    # position.
    utils gt --from-stdin -t $target --sort --asc
  else
    utils max --from-stdin
  fi
}

trigger_dockerhub_build() {
  local name=$1
  shift

  local versions
  if [ -p /dev/stdin ]; then
    versions=$(cat /dev/stdin)
  else
    versions="$@"
  fi

  if [ -z "$versions" ]; then
    return
  fi

  info "Trigger dockerhub build for $name:"

  local i=0
  for version in $versions; do
    info $version

    if [ "$i" -eq "$max_pending_allowed" ]; then
      info 'Max pending actions reached, break out.'
      break
    fi

    if git tag "$name/$version" &> /dev/null; then
      # If we push many tags one time, dockerhub may not pick up all. So instead
      # we push one tag one time. We also sleep some time to avoid putting much
      # pressure to github and dockerhub.
      git push --tags
      sleep 2
      i=$((i+1))
    fi
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

check_github() {
  local name=$1
  local namespace=$2
  local i=1
  local page_size=100
  local tags
  local tmpfile=$(mktemp)
  local curl_opts=()
  if [ -n "$TRAVIS_GITHUB_TOKEN" ]; then
    curl_opts+=("-H" "Authorization: token $TRAVIS_GITHUB_TOKEN")
  fi
  info "Check github for $name"
  while true; do
    tags=$(curl "${curl_opts[@]}" -s "https://api.github.com/repos/$namespace/tags?page=$i&per_page=$page_size" | jq -r '.[].name')
    echo "$tags" >> "$tmpfile"
    if [ "$(echo "$tags" | wc -l)" -eq "$page_size" ]; then
      i=$((i + 1))
      # Sleep some time to avoid exceeding ratelimit.
      sleep 0.5
    else
      break
    fi
  done
  cat "$tmpfile" | filter_versions $name | trigger_dockerhub_build $name
  info "Finished checking github for $name"
  rm "$tmpfile"
}

while read name registry namespace; do
  case "$registry" in
    gcr)
      check_gcr $name $namespace
      ;;
    github)
      check_github $name $namespace
      ;;
    *)
      error "Unsupported registry: $registry"
      ;;
  esac
done < "$rootdir/projects.txt"
