#!/usr/bin/env bash

IMAGE_NAME="arch-bootc"

(
  cd pkgbuilds/bootc
  makepkg -fcCs
)

(
  cd pkgbuilds/bootupd
  makepkg -fcCs
)

sudo podman build . -t $IMAGE_NAME --net=host --cap-add sys_admin --cap-add mknod
