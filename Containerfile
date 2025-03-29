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
RUN pacstrap -c -P /mnt \
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

# Turn the pacstrapped rootfs into a container image.
FROM scratch
COPY --from=builder /mnt /

# Install bootc and bootupd
COPY pkgbuilds /pkgbuilds
RUN pacman -U --noconfirm /pkgbuilds/bootupd/*.pkg.tar.zst /pkgbuilds/bootc/*.pkg.tar.zst && rm -rf /pkgbuilds 

# Add ostree tmpfile
COPY files/ostree-0-integration.conf /usr/lib/tmpfiles.d/

# Generate initramfs
COPY dracut-setup.sh /
RUN /dracut-setup.sh && rm /dracut-setup.sh

# Move pacman db to /usr since /var will be a mount
RUN sed -i \
    -e 's|^#\(DBPath\s*=\s*\).*|\1/usr/lib/pacman|g' \
    -e 's|^#\(IgnoreGroup\s*=\s*\).*|\1modified|g' \
    "/etc/pacman.conf" && \
    mv "/var/lib/pacman" "/usr/lib/" && \
    rm -f /var/cache/pacman/pkg/* && \
    find "/etc" -type s -exec rm {} \;

# Alter root file structure a bit for ostree
RUN mkdir /sysroot /efi && \
    rm -rf /boot/* /var/log /home /root /usr/local /srv && \
    ln -s sysroot/ostree /ostree && \
    ln -s var/home /home && \
    ln -s var/roothome /root && \
    ln -s var/usrlocal /usr/local && \
    ln -s var/srv /srv

# Necessary labels
LABEL containers.bootc 1
