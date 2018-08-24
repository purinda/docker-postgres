# Postgres Docker Image Builder

The purpose of the repository is to be generic enough that most of the Postgres
server versions can be built by using this repository.

The scripts in the repo uses generic notes and installation instructions from
https://www.postgresql.org/docs/9.6/static/installation.html

# Why

The official Postgres docker repository only contains the images for the current
major version and its minor version builds.

Official Postgres images in Docker Hub
https://hub.docker.com/_/postgres

# Instructions

Clone the repository
 > `git clone git@github.com:purinda/docker-postgres.git`

Build, the `MAJOR` and `MINOR` values gets concatanated to build an specific version image.
 > `export MAJOR=8.4 && export MINOR=20 && ./build.sh`

Now you can run the following to see the built image
> `docker images` 

## How to use it

The image tag can be used in your docker-compose file under `Image` tag or run standalone as below

```
docker run -it --rm --link some-postgres:postgres postgres psql -h postgres -U postgres
```