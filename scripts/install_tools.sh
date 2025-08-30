#!/bin/bash

# Talosctl install (needs sudo to uninstall in /usr/local/bin/talosctl)
sudo rm /usr/local/bin/talosctl
curl -sSL https://talos.dev/install | sh
talosctl version --client

# Kubectl install
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client


# Kubectl plugin install
## cnpg for postgresql cluster
curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin

# dprint (formatter)
# curl -fsSL https://dprint.dev/install.sh | sh

# Flux CLI install
curl -s https://fluxcd.io/install.sh | sudo bash

# Cilium CLI
# From https://github.com/cilium/cilium-cli
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
curl -L --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}"
sha256sum --check "cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum"
sudo tar -C /usr/local/bin -xzvf "cilium-${GOOS}-${GOARCH}.tar.gz"
rm "cilium-${GOOS}-${GOARCH}.tar.gz" "cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum"