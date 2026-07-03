#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (c) 2026 Western Digital Corporation or its affiliates.
#
# Author: Dennis Maisenbacher <dennis.maisenbacher@wdc.com>
#
# Build the customized containerDisk qcow2 for a <distro>/<variant>: extract the
# base cloud image out of its KubeVirt containerDisk and inject the variant's
# tools (the bundle of the same name in ci-containers.yaml). Produces
# <variant>/build/<distro>-<variant>.qcow2, which
# <variant>/Dockerfile.<distro>.containerdisk then packages as a scratch
# containerDisk.
#
# The tools are injected by mounting the guest filesystem with libguestfs
# (guestmount, which needs no network) and running the guest's own package
# manager in a chroot that borrows the *host's* network. We deliberately do
# NOT use `virt-customize --install`: on hosted CI runners the libguestfs
# appliance never gets working networking.
#
# Needs guestmount (libguestfs) and runs mount/chroot/guestmount under sudo:
# guestmount as root can read the mode-0600 host kernel and use /dev/kvm. The
# container runtime can be overridden, e.g. DOCKER="sudo docker".

set -euo pipefail

distro="${1:?usage: build-containerdisk.sh <distro> <variant>}"
variant="${2:?usage: build-containerdisk.sh <distro> <variant>}"
DOCKER="${DOCKER:-docker}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

base_image="$(./generate.py --distro "$distro" --bundles "$variant" \
    --base-images containerdisk_base_images --print-base-image)"
packages="$(./generate.py --distro "$distro" --bundles "$variant" --print-packages)"

builddir="${variant}/build"
workdir="${builddir}/.extract-${distro}"
qcow="${builddir}/${distro}-${variant}.qcow2"
mnt="$(mktemp -d)"

# Extract the bootable qcow2 from the base containerDisk. It is a scratch image
# holding the disk in /disk, so give `docker create` a dummy command (the
# container is never started).
rm -rf "$workdir"
mkdir -p "$workdir"
echo "Extracting base disk from ${base_image} ..."
cid="$($DOCKER create "$base_image" "${variant}-extract")"
$DOCKER cp "${cid}:/disk/." "$workdir/"
$DOCKER rm "$cid" >/dev/null

src="$(find "$workdir" -maxdepth 1 -type f | head -n1)"
if [ -z "$src" ]; then
    echo "error: no disk image found in ${base_image}:/disk" >&2
    exit 1
fi

# Package-manager invocation per distro, mirroring what `virt-customize
# --install` runs so the resulting image is equivalent.
case "$distro" in
    debian)
        # --force-unsafe-io skips dpkg's per-file fsync (needless durability
        # that is very slow over the guestmount FUSE); APT::Sandbox::User=root
        # avoids apt trying to drop to the _apt user, which cannot read the
        # root-only FUSE mount. Neither changes which packages get installed.
        install_cmd="export DEBIAN_FRONTEND=noninteractive
apt_opts='-q -y -o APT::Sandbox::User=root -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-unsafe-io'
apt-get \$apt_opts update
apt-get \$apt_opts install ${packages//,/ }"
        ;;
    fedora)
        install_cmd="dnf -y install ${packages//,/ }"
        ;;
    tumbleweed)
        # kernel-default-base (pre-installed in the base containerdisk) conflicts
        # with kernel-default; remove it first (only if kernel-default is being
        # installed) so the zypper install succeeds.
        rm_cmd=""
        if [[ ",${packages}," == *",kernel-default,"* ]]; then
            rm_cmd="zypper -n rm kernel-default-base; "
        fi
        install_cmd="${rm_cmd}zypper -n in -l ${packages//,/ }"
        ;;
    *)
        echo "error: unknown distro '${distro}'" >&2
        exit 1
        ;;
esac

# A bind/pseudo mount can momentarily report "busy" right after the chroot
# exits. Retry a few times and fall back to a lazy unmount so cleanup never
# aborts the build.
umount_retry() {
    local target="$1"
    for _ in 1 2 3; do
        sudo umount "$target" 2>/dev/null && return 0
        sleep 1
    done
    sudo umount -l "$target" 2>/dev/null || true
}

mounted=0
cleanup() {
    set +e
    if [ "$mounted" = 1 ]; then
        for d in dev proc sys; do
            umount_retry "$mnt/$d"
        done
        for _ in 1 2 3 4 5; do
            sudo guestunmount "$mnt" 2>/dev/null && break
            sleep 1
        done
    fi
    rmdir "$mnt" 2>/dev/null
}
trap cleanup EXIT

echo "Injecting ${variant} tools into ${distro}: ${packages}"
sudo guestmount -a "$src" -i --rw "$mnt"
mounted=1
sudo mount --bind /dev "$mnt/dev"
sudo mount -t proc proc "$mnt/proc"
sudo mount -t sysfs sys "$mnt/sys"

if sudo test -e "$mnt/etc/resolv.conf" || sudo test -L "$mnt/etc/resolv.conf"; then
    sudo mv "$mnt/etc/resolv.conf" "$mnt/etc/resolv.conf.ci-orig"
fi
if [ -e /run/systemd/resolve/resolv.conf ]; then
    sudo cp --remove-destination /run/systemd/resolve/resolv.conf "$mnt/etc/resolv.conf"
else
    sudo cp --remove-destination /etc/resolv.conf "$mnt/etc/resolv.conf"
fi

sudo chroot "$mnt" /bin/bash -c "$install_cmd"

sudo rm -f "$mnt/etc/resolv.conf"
if sudo test -e "$mnt/etc/resolv.conf.ci-orig" || sudo test -L "$mnt/etc/resolv.conf.ci-orig"; then
    sudo mv "$mnt/etc/resolv.conf.ci-orig" "$mnt/etc/resolv.conf"
fi

# Fedora boots SELinux enforcing, but the tools we inject offline end up
# unlabelled: dnf under the guestmount chroot cannot apply SELinux file
# contexts, and an offline relabel is not possible on the CI runner either. Set
# SELinux permissive so the VM boots (denials are logged, not enforced).
if [ "$distro" = "fedora" ] && sudo test -f "$mnt/etc/selinux/config"; then
    sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' "$mnt/etc/selinux/config"
fi

# openSUSE installs a kernel (kernel-default) here, and its %posttrans runs
# grub2-mkconfig and dracut *inside* the guestmount chroot, where the guest
# root filesystem is a libguestfs FUSE mount and the host's /proc,/sys,/dev are
# bind-mounted in. That corrupts the image in two ways that make it unbootable
# under KubeVirt:
#   * grub2-mkconfig probes the root device, sees the guest '/' backed by the
#     guestmount FUSE mount, and bakes "root=/dev/fuse" into grub.cfg. The guest
#     then hangs forever early in boot waiting for the dev-fuse.device unit.
#   * dracut builds a hostonly initramfs tuned to the build runner, which can
#     omit the virtio_blk/xfs (and virtiofs) drivers the KubeVirt VM needs.
# Repair both: rebuild a generic initramfs for the installed kernel and rewrite
# the bogus root= to the real root device taken from the guest's fstab.
if [ "$distro" = "tumbleweed" ]; then
    sudo chroot "$mnt" /bin/bash -euo pipefail -s <<'REPAIR'
kver="$(ls -1 /lib/modules | sort -V | tail -n1)"
echo "build-containerdisk: regenerating generic initramfs for ${kver}"
dracut --force --no-hostonly "/boot/initrd-${kver}" "${kver}"

root_spec="$(awk '$1 !~ /^#/ && $2 == "/" { print $1; exit }' /etc/fstab)"
[ -n "${root_spec}" ] || { echo "error: no '/' entry found in /etc/fstab" >&2; exit 1; }
while IFS= read -r cfg; do
    if grep -q 'root=/dev/fuse' "${cfg}"; then
        echo "build-containerdisk: rewriting root=/dev/fuse -> root=${root_spec} in ${cfg}"
        sed -i "s#root=/dev/fuse#root=${root_spec}#g" "${cfg}"
    fi
done < <(find /boot -name grub.cfg)

if grep -rIq 'root=/dev/fuse' /boot; then
    echo "error: root=/dev/fuse still present under /boot after repair" >&2
    exit 1
fi
REPAIR
fi

for d in dev proc sys; do
    umount_retry "$mnt/$d"
done
for _ in 1 2 3 4 5; do
    sudo guestunmount "$mnt" && break
    sleep 1
done
mounted=0

mkdir -p "$builddir"
sudo mv -f "$src" "$qcow"
sudo chown "$(id -u):$(id -g)" "$qcow"
sudo rm -rf "$workdir"
echo "Created ${qcow}"
