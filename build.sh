#!/usr/bin/env bash

CWD=`python -c "import os; print(os.path.dirname(os.path.realpath(\"$0\")))"`

# Tag/Version
TAG="postgres"

docker build -t "${TAG}:${MAJOR}.${MINOR}" \
    --build-arg PG_MAJOR="${MAJOR}" \
    --build-arg PG_MINOR="${MAJOR}.${MINOR}" \
    ${CWD}