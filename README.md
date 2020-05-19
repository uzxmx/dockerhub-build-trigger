# dockerhub-build-trigger

[![Build Status](https://travis-ci.org/uzxmx/dockerhub-build-trigger.svg?branch=version-checker)](https://travis-ci.org/uzxmx/dockerhub-build-trigger)

This project aims to mirroring images from sources like `gcr.io` to
[dockerhub](https://hub.docker.com/u/mirror4gcr).

Basically, it periodically (relies on Travis CI cron job) checks versions from
sources based on configurations in [projects.txt](projects.txt), and creates
tags if they don't exist yet. On dockerhub side, automatically pre-created
repositories observe tag events and parse them to build new versions for images.

For immediate checking and building, you can also run scripts from local.

## TOC

* [Why this repo](#why-this-repo)
* [No image or versions found](#no-image-or-versions-found)
* [Run manually from local](#run-manually-from-local)
  * [Mirror a specific version for an image](#mirror-a-specific-version-for-an-image)
* [Magic branches](#magic-branches)

## Why this repo

* Access to `gcr.io` from China is blocked.
* [mirrorgooglecontainers](https://hub.docker.com/u/mirrorgooglecontainers) and
  [kubeimage](https://hub.docker.com/u/kubeimage) in dockerhub haven't provided latest or all
  needed images.
* `gcr.azk8s.cn` is no longer for public access (see [here](https://github.com/Azure/container-service-for-azure-china/issues/58)).
* `gcr.mirrors.ustc.edu.cn` seems not working.
* Mirror from aliyun requires login, inconvenient.
* [anjia0532/gcr.io_mirror](https://github.com/anjia0532/gcr.io_mirror) is no
  longer maintained, and it relies on Travis CI's docker pulling and pushing,
  may overuse Travis CI's resources.
* Luckily, dockerhub still can be accessed from China, and for more fast pulling
  speed, we can also use `docker.mirrors.ustc.edu.cn` etc. as a mirror of
  dockerhub.

## No image or versions found

If you cannot find an image in [dockerhub](https://hub.docker.com/u/mirror4gcr),
please create an issue or PR to add new images or versions.

## Run manually from local

Add a new image to be mirrored in [projects.txt](projects.txt) with the
following format:

```
<name> <registry_type> <namespace>
```

Currently, only `gcr` registry type is supported.

Then, create repositories in dockerhub by running below command. You may need to
export `DOCKERHUB_USERNAME` and `DOCKERHUB_PASSWORD` before running the command.
Otherwise, you may fail to create repositories.

```
$ make create_repositories
```

Finally, run below command to check new versions for images. When new versions
are available, tags will be created and pushed to the remote, which will trigger
dockerhub builds.

```
$ make check_new_versions
```

### Mirror a specific version for an image

Before running the command, make sure corresponding project exists in
[projects.txt](projects.txt) and repository is created in dockerhub.

```
$ ./scripts/create_tag.sh <name> <version>
```

## Magic branches

* version-checker

  Travis CI uses this branch to check new versions for images weekly. When this
  branch changes, an immediate build will also be triggered.

* repo-creator

  If this branch changes, Travis CI will be triggered to check and create
  repositories in dockerhub.

## License

[MIT License](LICENSE)
