#!/bin/bash
set -euo pipefail

# see https://github.com/siderolabs/talos/releases
# renovate: datasource=github-releases depName=siderolabs/talos
talos_version="1.8.1"
# https://github.com/siderolabs/pkgs/tags
talos_pkg_branch="release-1.8"

# see https://github.com/siderolabs/extensions/pkgs/container/qemu-guest-agent
# see https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent
talos_qemu_guest_agent_extension_tag="9.1.0@sha256:cd8154036a0711f6f0a2ec9d6ce8539219d0e46a78e0eca22598d4d884f3f52c"

# see https://github.com/siderolabs/extensions/pkgs/container/iscsi-tools
talos_iscsi_tools_tag="v0.1.5@sha256:9ca66809dcd794b9313c1a5bafe4f648de8c0af03a4148e4a82722e378fd62e0"

# see https://www.talos.dev/v1.7/talos-guides/install/boot-assets/
# see https://www.talos.dev/v1.7/advanced/metal-network-configuration/
# see Profile type at https://github.com/siderolabs/talos/blob/v1.7.6/pkg/imager/profile/profile.go#L22-L45
talos_version_tag="v$talos_version"
rm -rf tmp/talos
mkdir -p tmp/talos

BUILD_NVIDIA=0

# Template from https://github.com/siderolabs/pkgs/blob/main/nonfree/kmod-nvidia/lts/pkg.yaml
# Building kernel driver NVIDIA with GRID (=> https://github.com/wvthoog/proxmox-vgpu-installer), already installed in Proxmox
# Check updates depending on new versions
if [ $BUILD_NVIDIA -ne 0 ]; then
  git clone --branch $talos_pkg_branch https://github.com/siderolabs/pkgs.git tmp/talos/pkgs

  nvidia_driver_version="535.161.07"
  nvidia_driver="NVIDIA-Linux-x86_64-${nvidia_driver_version}-grid"

  # TODO : next version pkg.yaml is in nonfree/kmod-nvidia/lts/pkg.yaml (and rename the "name")
  cat >"tmp/talos/pkgs/nonfree/kmod-nvidia/pkg.yaml" <<EOF
name: nonfree-kmod-nvidia-pkg
variant: scratch
shell: /toolchain/bin/bash
dependencies:
  - stage: kernel-build
steps:
  - sources:
    - url: https://storage.googleapis.com/nvidia-drivers-us-public/GRID/vGPU16.4/${nvidia_driver}.run
      destination: nvidia.run
      sha256: a3c7723e3734f5c7628185aa916246e87fc03fbd5b1fae697f01534bfed5f463
      sha512: c7554a3b581ff70a5cfd3f2d4e370af9e18556defdaa6d318acc957d40283cd14969c923edd0cc2a95a54a4aaaf2ca67453ccd8026e28a3e0ed15fd1dd35fa17
    # env:
    #   ARCH: {{ if eq .ARCH "aarch64"}}arm64{{ else if eq .ARCH "x86_64" }}x86_64{{ else }}unsupported{{ end }}
    prepare:
      - |
        export PATH=/toolchain/bin:$PATH
        export GUESS_MD5_PATH=/toolchain/bin

        rm -f /dev/tty && ln -s /dev/stdout /dev/tty
        ln -s /toolchain/bin/echo /toolchain/bin/which

        /toolchain/bin/bash nvidia.run --extract-only
    build:
      - |
        cd NVIDIA-Linux-*/kernel

        make -j \$(nproc) SYSSRC=/src
    install:
      - |
        cd NVIDIA-Linux-*/kernel

        mkdir -p /rootfs/lib/modules/\$(cat /src/include/config/kernel.release)/
        cp /src/modules.order /rootfs/lib/modules/\$(cat /src/include/config/kernel.release)/
        cp /src/modules.builtin /rootfs/lib/modules/\$(cat /src/include/config/kernel.release)/
        cp /src/modules.builtin.modinfo /rootfs/lib/modules/\$(cat /src/include/config/kernel.release)/

        make -j \$(nproc) modules_install SYSSRC=/src DEPMOD=/toolchain/bin/depmod INSTALL_MOD_PATH=/rootfs INSTALL_MOD_DIR=extras INSTALL_MOD_STRIP=1
finalize:
  - from: /rootfs
    to: /
EOF

  cat >"tmp/talos/pkgs/builder-config.toml" <<EOF
[registry."localhost"]
  http = true
  insecure = true

[worker.oci]
  gc = true
  gckeepstorage = 50000

  [[worker.oci.gcpolicy]]
    keepBytes = 10737418240
    keepDuration = 604800
    filters = [ "type==source.local", "type==exec.cachemount", "type==source.git.checkout"]
  [[worker.oci.gcpolicy]]
    all = true
    keepBytes = 53687091200
EOF

  # Attempt to create a builder, skip if alread exist
  docker buildx create --driver-opt network=host --buildkitd-flags '--allow-insecure-entitlement security.insecure' --name local --use --config=tmp/talos/pkgs/builder-config.toml || true

  # Attempt to create a local image registry, add { "insecure-registries": ["localhost:15555"] } to /etc/docker/daemon.json
  registry_name="talos-build-registry"
  docker run -d -p 15555:5000 --restart always --name $registry_name registry:2 || true

  cd tmp/talos/pkgs/

  # Make both kernel and nvidia images to be used after
  export REGISTRY="localhost:15555"
  export USERNAME="taloscustom"
  TAG="${talos_version_tag}-nvidiacustom"
  make kernel PLATFORM=linux/amd64 PUSH=true TAG=$TAG
  make nonfree-kmod-nvidia-pkg PLATFORM=linux/amd64 PUSH=true TAG=$TAG


  repo="$REGISTRY/$USERNAME"

  cat >"Dockerfile" <<EOF
FROM scratch as customization
COPY --from=$repo/nonfree-kmod-nvidia-pkg:$TAG /lib/modules /lib/modules

FROM ghcr.io/siderolabs/installer:$talos_version_tag
COPY --from=$repo/kernel:$TAG /boot/vmlinuz /usr/install/amd64/vmlinuz
EOF

  # Attempt to delete the previously created builder
  # docker buildx rm local || true

  nvidia_installer_custom_image=$repo/installer:$talos_version_tag-nvidiacustom
  # Build installer
  DOCKER_BUILDKIT=0 docker build --squash --build-arg RM="/lib/modules" -t $nvidia_installer_custom_image .

  # Build NVIDIA container toolkit for this target version
  # https://github.com/siderolabs/extensions/blob/release-1.7
  git clone --branch $talos_pkg_branch https://github.com/siderolabs/extensions.git ../extensions

  cd ../extensions

  cat >"nvidia-gpu/nvidia-container-toolkit/nvidia-pkgs/pkg.yaml" <<EOF
name: nvidia-pkgs
variant: scratch
shell: /bin/bash
install:
  - bash
dependencies:
  - image: cgr.dev/chainguard/wolfi-base@{{ .WOLFI_BASE_REF }}
  # depends on glibc to update ld.so.cache
  # so any stage depending on nvidia-pkgs will have the updated cache
  - stage: glibc
steps:
  - sources:
    - url: https://storage.googleapis.com/nvidia-drivers-us-public/GRID/vGPU16.4/${nvidia_driver}.run
      destination: nvidia.run
      sha256: a3c7723e3734f5c7628185aa916246e87fc03fbd5b1fae697f01534bfed5f463
      sha512: c7554a3b581ff70a5cfd3f2d4e370af9e18556defdaa6d318acc957d40283cd14969c923edd0cc2a95a54a4aaaf2ca67453ccd8026e28a3e0ed15fd1dd35fa17
    prepare:
      - |
        # the nvidia installer validates these packages are installed
        ln -s /bin/true /bin/modprobe
        ln -s /bin/true /bin/rmmod
        ln -s /bin/true /bin/lsmod
        ln -s /bin/true /bin/depmod

        bash nvidia.run --extract-only
    install:
      - |
        mkdir -p /rootfs/usr/local \
          /rootfs/usr/local/lib/containers/nvidia-persistenced \
          /rootfs/usr/local/etc/containers \
          /rootfs/usr/etc/udev/rules.d

        cd NVIDIA-Linux-*

        ./nvidia-installer --silent \
          --opengl-prefix=/rootfs/usr/local \
          --utility-prefix=/rootfs/usr/local \
          --documentation-prefix=/rootfs/usr/local \
          --no-rpms \
          --no-kernel-modules \
          --log-file-name=/tmp/nvidia-installer.log \
          --no-distro-scripts \
          --no-wine-files \
          --no-kernel-module-source \
          --no-check-for-alternate-installs \
          --override-file-type-destination=NVIDIA_MODPROBE:/rootfs/usr/local/bin \
          --override-file-type-destination=FIRMWARE:/rootfs/lib/firmware/nvidia/${nvidia_driver_version} \
          --no-systemd

        # copy vulkan/OpenGL json files
        mkdir -p /rootfs/{etc/vulkan,usr/{lib/xorg,share/{glvnd,egl}}}

        cp -r /usr/share/glvnd/* /rootfs/usr/share/glvnd
        cp -r /usr/share/egl/* /rootfs/usr/share/egl
        cp -r /etc/vulkan/* /rootfs/etc/vulkan

        # copy xorg files
        mkdir -p /rootfs/usr/local/lib/nvidia/xorg
        find /usr/lib/xorg/modules -type f -exec cp {} /rootfs/usr/local/lib/nvidia/xorg \;

        # run ldconfig to update the cache
        /rootfs/usr/local/glibc/sbin/ldconfig -r /rootfs

        # copy udev rule
        cp /pkg/files/15-nvidia-device.rules /rootfs/usr/etc/udev/rules.d
finalize:
  - from: /rootfs
    to: /rootfs
EOF

  sed -i "s/NVIDIA_DRIVER_VERSION: .*/NVIDIA_DRIVER_VERSION: ${nvidia_driver_version}/" nvidia-gpu/vars.yaml

  cat >"nvidia-gpu/nonfree/kmod-nvidia/pkg.yaml" <<EOF
name: nonfree-kmod-nvidia
variant: scratch
shell: /toolchain/bin/bash
dependencies:
- stage: base
# The pkgs version for a particular release of Talos as defined in
# https://github.com/siderolabs/talos/blob/<talos version>/pkg/machinery/gendata/data/pkgs
- image: "${repo}/nonfree-kmod-nvidia-pkg:${TAG}"
steps:
  - prepare:
      - |
        sed -i 's#\$VERSION#{{ .VERSION }}#' /pkg/manifest.yaml
  - install:
      - |
        mkdir -p /rootfs/lib/modules \
          /rootfs/usr/local/lib/modprobe.d

        cp /pkg/files/nvidia.conf /rootfs/usr/local/lib/modprobe.d/nvidia.conf

        cp -R /lib/modules/* /rootfs/lib/modules
finalize:
  - from: /rootfs
    to: /rootfs
  - from: /pkg/manifest.yaml
    to: /
EOF

  container_toolkit_ver=$(sed -nE "s/CONTAINER_TOOLKIT_VERSION: (.*)/\\1/p" nvidia-gpu/vars.yaml)
  container_toolkit_tag="${nvidia_driver_version}-${container_toolkit_ver}"

  # Nonfree-kmod-nvidia-extension gets its base from pkg image built before PKGS=${repo}/nonfree-kmod-nvidia-pkg:${TAG}
  make nonfree-kmod-nvidia PLATFORM=linux/amd64 PUSH=true
  nvidia_ext_tag="${nvidia_driver_version}-${talos_version_tag}-dirty"

  make nvidia-container-toolkit PLATFORM=linux/amd64 PUSH=true

  # TODO : Get access token from license server and insert it in the image or with talosctl if possible


  # Go back to root
  cd ../../../
fi;

# Generating talos build manifest with our custom image versions
# To build controller image with nvidia, add the following
    # - imageRef: $repo/nvidia-container-toolkit:$container_toolkit_tag
    # - imageRef: $repo/nonfree-kmod-nvidia:$nvidia_ext_tag

cat >"tmp/talos/talos-$talos_version.yaml" <<EOF
arch: amd64
platform: nocloud
secureboot: false
version: $talos_version_tag
customization:
  extraKernelArgs:
    - console=ttyS0
    - net.ifnames=0
    # - net.core.bpf_jit_harden=1
input:
  kernel:
    path: /usr/install/amd64/vmlinuz
  initramfs:
    path: /usr/install/amd64/initramfs.xz
  baseInstaller:
    imageRef: ghcr.io/siderolabs/installer:$talos_version_tag  # or \$nvidia_installer_custom_image
  systemExtensions:
    - imageRef: ghcr.io/siderolabs/qemu-guest-agent:$talos_qemu_guest_agent_extension_tag
    - imageRef: ghcr.io/siderolabs/iscsi-tools:$talos_iscsi_tools_tag
output:
  kind: image
  imageOptions:
    diskSize: $((2*1024*1024*1024))
    diskFormat: raw
  outFormat: raw
EOF

docker run --rm -i \
-v $PWD/tmp/talos:/secureboot:ro \
-v $PWD/tmp/talos:/out \
-v /dev:/dev \
--privileged \
--network host \
"ghcr.io/siderolabs/imager:$talos_version_tag" \
- < "tmp/talos/talos-$talos_version.yaml"
img_path="tmp/talos/talos-$talos_version.qcow2"
qemu-img convert -O qcow2 tmp/talos/nocloud-amd64.raw $img_path
qemu-img info $img_path

sed -i "s/^talos_version = \".*\"/talos_version = \"$talos_version\"/" $PWD/terraform/k8s/config.tfvars

# Delete local image registry
if [ $BUILD_NVIDIA -ne 0 ]; then
  docker stop $registry_name && docker rm $registry_name
fi
