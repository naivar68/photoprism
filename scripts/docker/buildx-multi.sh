#!/usr/bin/env bash

# https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds
export DOCKER_BUILDKIT=1

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "Usage: ${0##*/} [name] [linux/amd64|linux/arm64|linux/arm] [tag] [/subimage]" 1>&2
    exit 1
fi

NUMERIC='^[0-9]+$'
BUILD_DATE=$(/bin/date -u +%y%m%d)

# kill old multi builder if still alive.
echo "Removing existing multibuilder..."
docker buildx rm multibuilder 2>/dev/null

# wait 3 seconds.
sleep 3

# Create multibuilder instance.
docker buildx create --name multibuilder --use  || { echo 'failed to create multibuilder'; exit 1; }

# Configure remote host for native arm builds.
docker buildx create --name multibuilder --append ssh://ci-arm || echo 'could not connect to remote host for native arm builds'

echo "Starting 'photoprism/$1' multi-arch build based on docker/${1/-//}$4/Dockerfile..."
echo "Build Arch: $2"

if [[ $1 ]] && [[ $2 ]] && [[ -z $3 || $3 == "preview" ]]; then
    echo "Build Tags: preview"

    if [[ $5 ]]; then
      echo "Build Params: $5"
    fi

    docker buildx build \
      --platform $2 \
      --pull \
      --no-cache \
      --build-arg BUILD_TAG=$BUILD_DATE \
      -f docker/${1/-//}$4/Dockerfile \
      -t photoprism/$1:preview $5 \
      --push .
elif [[ $3 =~ $NUMERIC ]]; then
    echo "Build Tags: $3, latest"

    if [[ $5 ]]; then
      echo "Build Params: $5"
    fi

    docker buildx build \
      --platform $2 \
      --pull \
      --no-cache \
      --build-arg BUILD_TAG=$3 \
      -f docker/${1/-//}$4/Dockerfile \
      -t photoprism/$1:latest \
      -t photoprism/$1:$3 $5 \
      --push .
elif [[ $4 ]] && [[ $3 == *"preview"* || $3 == *"unstable"* || $3 == *"test"* ]]; then
    echo "Build Tags: $3"

    if [[ $5 ]]; then
      echo "Build Params: $5"
    fi

    docker buildx build \
      --platform $2 \
      --pull \
      --no-cache \
      --build-arg BUILD_TAG=$BUILD_DATE \
      -f docker/${1/-//}$4/Dockerfile \
      -t photoprism/$1:$3 $5 \
      --push .
elif [[ $4 ]]; then
    echo "Build Tags: $BUILD_DATE-$3, $3"

    if [[ $5 ]]; then
      echo "Build Params: $5"
    fi

    docker buildx build \
      --platform $2 \
      --pull \
      --no-cache \
      --build-arg BUILD_TAG=$BUILD_DATE-$3 \
      -f docker/${1/-//}$4/Dockerfile \
      -t photoprism/$1:$3 \
      -t photoprism/$1:$BUILD_DATE-$3 $5 \
      --push .
else
    echo "Build Tags: $3"

    docker buildx build \
      --platform $2 \
      --pull \
      --no-cache \
      --build-arg BUILD_TAG=$BUILD_DATE \
      -f docker/${1/-//}/Dockerfile \
      -t photoprism/$1:$3 \
      --push .
fi

echo "Removing multibuilder..."
docker buildx rm multibuilder

echo "Done."
