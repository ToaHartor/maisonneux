#!/bin/bash

set -euo pipefail

kubectl run nvidia-test --restart=Never \
      --rm -it \
      --image=nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1-ubuntu20.04 \
      --overrides='{
        "apiVersion": "v1",
        "spec": {
          "runtimeClassName": "nvidia",
          "containers": [{
            "name": "nvidia-smi",
            "image": "nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1-ubuntu20.04",
            "command": ["nvidia-smi"],
            "resources": {
              "limits": {
                "nvidia.com/gpu": "1"
              }
            },
            "securityContext": {
              "runAsNonRoot": false,
              "allowPrivilegeEscalation": false,
              "capabilities": { "drop": ["ALL"] },
              "seccompProfile": { "type": "RuntimeDefault" }
            }
          }]
        }
      }' \
      nvidia-smi