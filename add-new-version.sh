#!/usr/bin/env bash

# Downloads the rootfs file for a Docker image and prepares a Dockerfile for it
# After successful execution review the changes with 'git diff'
#
# Usage: ./add-new-version.sh 22.03-lts-sp2

set -e

die() {
    echo "Error: $1";
    exit 1;
}

archs="x86_64 aarch64"
VERSION=$1

if [[ -z ${VERSION} ]]; then
  echo "Usage: $0 <version>";
  echo -e "\nExample: $0 24.03-lts";
  exit 1
fi

for ARCH in ${archs} ;
do
    if [[ "$ARCH" = "aarch64" ]];then
        DOCKER_ARCH=arm64
    elif [[ "$ARCH" = "x86_64" ]];then
        DOCKER_ARCH=amd64
    else
        echo "Unknown arch: ${ARCH}"
        exit 1
    fi
    
    mkdir -p ${VERSION}
    
    # Download
    pushd ${VERSION}
    URL_VERSION=`echo ${VERSION} | tr 'a-z' 'A-Z'`
    if [ ! -f "openEuler-docker.${ARCH}.tar.xz" ]; then
        wget --quiet https://repo.openeuler.org/openEuler-${URL_VERSION}/docker_img/${ARCH}/openEuler-docker.${ARCH}.tar.xz || die "Cannot find version ${VERSION}!";
    fi

    # Re-download and validate sha256sum everytime
    rm -f openEuler-docker.$ARCH.tar.xz.sha256sum
    wget --quiet https://repo.openeuler.org/openEuler-${URL_VERSION}/docker_img/${ARCH}/openEuler-docker.${ARCH}.tar.xz.sha256sum || die "Cannot download sha256sum for ${VERSION}!";
    shasum -c openEuler-docker.${ARCH}.tar.xz.sha256sum
    
    # Extract rootfs
    if [ ! -f "openEuler-docker-rootfs.${DOCKER_ARCH}.tar.xz" ]; then
        tar -xf openEuler-docker.${ARCH}.tar.xz --wildcards "*.tar" --exclude "layer.tar"
        ROOT_FS=`ls | xargs -n1 | grep -v openEuler |grep *.tar`
        mv ${ROOT_FS} openEuler-docker-rootfs.${DOCKER_ARCH}.tar
        xz -z openEuler-docker-rootfs.${DOCKER_ARCH}.tar
    fi
    NEW_DOCKERFILE="Dockerfile-${VERSION}-${ARCH}"
    cp -f ../Dockerfile-22.03-lts-${ARCH} ./${NEW_DOCKERFILE}
    sed -i "s/22.03-lts/${VERSION}/" ${NEW_DOCKERFILE}

    cp -f ${NEW_DOCKERFILE} ../
    cp -f openEuler-docker-rootfs.${DOCKER_ARCH}.tar.xz ../openEuler-${VERSION}-docker-rootfs.${ARCH}.tar.xz
    git add ../${NEW_DOCKERFILE} ../openEuler-${VERSION}-docker-rootfs.${ARCH}.tar.xz

    popd
done

echo -e "\nDone! Please review the new changes with 'git diff' and commit+push them if they look good!"