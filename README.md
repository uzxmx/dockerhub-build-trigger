# dockerhub-build-trigger

[![Build Status](https://travis-ci.org/uzxmx/dockerhub-build-trigger.svg?branch=version-checker)](https://travis-ci.org/uzxmx/dockerhub-build-trigger)

This project aims to mirroring images from sources like `gcr.io` to
[dockerhub](https://hub.docker.com/u/mirror4gcr).

Basically, it periodically (relies on Travis CI cron job) checks versions from
sources based on configurations in [projects.txt](projects.txt), and creates
tags if they don't exist yet. On dockerhub side, automatically pre-created
repositories observe tag events and parse them to build new versions for images.

For immediate checking and building, you can also run scripts from local.

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
