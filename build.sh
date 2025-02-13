#!/usr/bin/env bash

IMAGE_NAME="arch-bootc"

(
  cd pkgbuilds/bootc
  makepkg -Ccs
)

(
  cd pkgbuilds/bootupd
  makepkg -Ccs
)

sudo podman build . -t $IMAGE_NAME --net=host --cap-add sys_admin --cap-add mknod
