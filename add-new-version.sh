#!/usr/bin/env bash

# Downloads the rootfs file for a Docker image and prepares a Dockerfile for it
# After successful execution review the changes with 'git diff'
#
# Usage: ./add-new-version.sh 22.03-lts-sp2

set -e

CYAN="\033[0;36m"
RED="\033[0;31m"
NC='\033[0m' # No Color

die() {
    echo -e "${RED}Error: $1${NC}";
    exit 1;
}

info() {
    echo -e "${CYAN}$1${NC}"
}

archs="x86_64 aarch64"
VERSION=$1

if [[ -z ${VERSION} ]]; then
  info "Usage: $0 <version>";
  info "\nExample: $0 24.03-lts";
  exit 1
fi

for ARCH in ${archs} ;
do
    if [[ "$ARCH" = "aarch64" ]];then
        DOCKER_ARCH=arm64
    elif [[ "$ARCH" = "x86_64" ]];then
        DOCKER_ARCH=amd64
    else
        die "Unknown arch: ${ARCH}"
    fi
    
    mkdir -p ${VERSION}
    
    # Download
    pushd ${VERSION}
    URL_VERSION=`echo ${VERSION} | tr 'a-z' 'A-Z'`
    if [ ! -f "openEuler-docker.${ARCH}.tar.xz" ]; then
        info "Going to download openEuler-docker.${ARCH}.tar.xz"
        wget --quiet https://repo.openeuler.org/openEuler-${URL_VERSION}/docker_img/${ARCH}/openEuler-docker.${ARCH}.tar.xz || die "Cannot find version ${VERSION}!";
    fi

    # Re-download and validate sha256sum everytime
    rm -f openEuler-docker.$ARCH.tar.xz.sha256sum
    info "Going to download openEuler-docker.$ARCH.tar.xz.sha256sum"
    wget --quiet https://repo.openeuler.org/openEuler-${URL_VERSION}/docker_img/${ARCH}/openEuler-docker.${ARCH}.tar.xz.sha256sum || die "Cannot download sha256sum for ${VERSION}!";
    shasum -c openEuler-docker.${ARCH}.tar.xz.sha256sum
    
    if [ ! -f "openEuler-docker-rootfs.${DOCKER_ARCH}.tar.xz" ]; then
        info "Going to extract the rootfs.tar.xz ..."
        tar -xf openEuler-docker.${ARCH}.tar.xz --wildcards "*.tar" --exclude "layer.tar"
        ROOT_FS=`ls | xargs -n1 | grep -v openEuler |grep *.tar`
        mv ${ROOT_FS} openEuler-docker-rootfs.${DOCKER_ARCH}.tar
        xz -z openEuler-docker-rootfs.${DOCKER_ARCH}.tar
    fi
    DOCKERFILE="Dockerfile-${VERSION}-${ARCH}"
    cat <<EOF > ${DOCKERFILE} 
FROM scratch

ADD openEuler-${VERSION}-docker-rootfs.aarch64.tar.xz /
RUN sed -i "s@repo.openeuler.org@repo.huaweicloud.com/openeuler@g" /etc/yum.repos.d/openEuler.repo
# See more in https://gitee.com/openeuler/cloudnative/issues/I482Q6
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    sed -i "s/TMOUT=300/TMOUT=0/g" /etc/bashrc && \
    yum -y update && yum clean all
CMD ["bash"]
EOF

    cp -f ${DOCKERFILE} ../
    cp -f openEuler-docker-rootfs.${DOCKER_ARCH}.tar.xz ../openEuler-${VERSION}-docker-rootfs.${ARCH}.tar.xz
    git add ../${DOCKERFILE} ../openEuler-${VERSION}-docker-rootfs.${ARCH}.tar.xz

    popd
done

info "\nDone! Please review the new changes with 'git diff' and commit+push them if they look good!"
