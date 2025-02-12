FROM docker.io/archlinux:base-devel AS builder

RUN pacman-key --init
RUN pacman-key --populate
RUN pacman -Sy --noconfirm \
  arch-install-scripts \
  ostree

# This allows using this container to make a deployment.
RUN ln -s sysroot/ostree /ostree

# This allows using pacstrap -N in a rootless container.
RUN echo 'root:1000:5000' > /etc/subuid
RUN echo 'root:1000:5000' > /etc/subgid

# We need the ostree hook.
RUN install -d /mnt/etc
COPY files/ostree.conf /mnt/etc/dracut.conf.d/
COPY files/module-setup.sh /mnt/etc/dracut.conf.d/

# Install packages.
RUN pacstrap -c -G -M /mnt \
    base \
    btrfs-progs \
    linux \ 
    linux-firmware \
    linux-firmware-whence \
    intel-ucode \
    amd-ucode \
    grub \
    dracut \
    ostree \
    podman

RUN cp /etc/pacman.conf /mnt/etc/pacman.conf
RUN echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /mnt/etc/pacman.d/mirrorlist

# Turn the pacstrapped rootfs into a container image.
FROM scratch
COPY --from=builder /mnt /

# Setup keyring
RUN pacman-key --init && \
    pacman-key --populate

# Install bootc and bootupd
COPY pkgbuilds /pkgbuilds
RUN pacman -U --noconfirm /pkgbuilds/bootupd/*.pkg.tar.zst /pkgbuilds/bootc/*.pkg.tar.zst && rm -rf /pkgbuilds 

# Generate initramfs
COPY dracut-setup.sh /
RUN /dracut-setup.sh && rm /dracut-setup.sh

# Add ostree tmpfile
COPY files/ostree-0-integration.conf /usr/lib/tmpfiles.d/

# Alter root file structure a bit for ostree
RUN mkdir /sysroot && \
    mkdir /efi && \
    rm -rf /boot && mkdir /boot && \
    mv /home /var/ && ln -s /var/home /home && \
    mv /root /var/roothome && ln -s /var/roothome /home && \
    mv /usr/local /var/usrlocal && ln -s /var/roothome /root && \
    mv /srv /var/ && ln -s /var/srv /srv

# Cleanup pacman sockets
RUN  find "/etc" -type s -exec rm {} \;

# Necessary labels
LABEL containers.bootc 1
