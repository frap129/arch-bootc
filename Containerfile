ARG BASE_IMAGE="docker.io/library/${BASE_IMAGE_NAME:-archlinux}"
ARG BASE_IMAGE_FLAVOR="${BASE_IMAGE_FLAVOR:-base}"

FROM ${BASE_IMAGE}:${BASE_IMAGE_FLAVOR} AS arch-bootc-base

# Setup keyring
RUN pacman-key --init && \
    pacman-key --populate

# Install temporary depndencies
RUN pacman -Syyu --noconfirm && \
    pacman -S --noconfirm \
    git \
    base-devel

# Install kernel, firmware, microcode, bootloader, depndencies
RUN pacman -S --noconfirm \
    btrfs-progs\
    linux \ 
    linux-firmware \
    linux-firmware-whence \
    intel-ucode \
    amd-ucode \
    grub \
    dracut \
    skopeo \
    ostree \
    podman

# Create build user
RUN useradd -m --shell=/bin/bash build && usermod -L build && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Build and install bootc and bootupd
USER build
WORKDIR /home/build
ADD --chown=build:build pkgbuilds /home/build/pkgbuilds
RUN cd /home/build/pkgbuilds/bootupd && makepkg -si --noconfirm
RUN cd /home/build/pkgbuilds/bootc && makepkg -si --noconfirm

USER root

# Add a platform to os-release
RUN echo "PLATFORM_ID=\"platform:arch\"" >> /etc/os-release

# Generate initramfs
COPY files/ostree.conf /mnt/etc/dracut.conf.d/
COPY files/module-setup.sh /mnt/etc/dracut.conf.d/
COPY dracut-setup.sh /
RUN /dracut-setup.sh && rm /dracut-setup.sh

# Add ostree tmpfile
COPY files/ostree-0-integration.conf /usr/lib/tmpfiles.d/

# Squash layers
FROM scratch

COPY --from=arch-bootc-base / /

# Necessary labels
LABEL containers.bootc 1
