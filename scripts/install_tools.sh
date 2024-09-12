#!/bin/sh

# Talosctl install
curl -sL https://talos.dev/install | sh
talosctl version --client

# Kubectl install
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# dprint (formatter)
# curl -fsSL https://dprint.dev/install.sh | sh


# K9s (needs go installed)
go install github.com/derailed/k9s@latest
