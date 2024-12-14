# Building internal images

Main problem : we have to build containers of some apps from other Git repositories OR from this repository, which will be deployed using custom Helm charts.
=> Dockerfiles : can be hosted in GitHub repository, not a problem
=> Modifications to the repository : directly made in Dockerfile + config made with k8s

## Main problems

Who's building ?
    - Github Actions ?
    - Gitea Actions in cluster ? Out of the cluster (VM / LXC / Docker) ?
    - Woodpecker CI ? We can reference repositories inside, and maybe define a ci inside the current GitHub repository, point to it and make woodpecker watch on it
    - All-in-one with Gitea ? (Registry + CI) => Need to init Gitea with repository from source

When should we build ?
    - New updates managed manually, by changing commit reference in the Dockerfile

Where should we store the images ?
    - Private container registry, yes but deployed in cluster or out ?
    - Can be deployed in-cluster, but at the system level and other deployments can use it as a proxy. In that case, build should occur in-cluster as well.

What about the deployment order ?
    - All apps using this system must be deployed after, using Kustomization relations
    - This still requires some timing, but since we can consider helm will stay stale if images do not exist, then cluster may naturally wait until the build is finished

## Some useful references ?

Image automation with FluxCD => <https://dev.to/azure/configure-image-automation-with-fluxcd-1ecc>
Using Tekton as CI to build images based on webhook triggers, and push them to a local registry => <https://baptistout.net/posts/kubernetes-native-ci-cd-stack-with-tekton-fluxcd-helm-operator/index.html>

## Process

We go with Tekton and its pipeline integration with Kubernetes, and Zot as a container registry, as both are lightweight (no dependencies besides MinIO for Zot).

FluxCD Alert watching on events forwards to a Provider (Tekton) => Tekton EventListener gets it,
filters the webhook with the Interceptor (signature verification with HMAC etc), and triggers the Trigger,
containing a TriggerTemplate which has a PipelineRun template inside, used to start our pipeline.

## Choosing the right trigger

- HelmChart : great for the scheduling, however if we update the version contained in the pipeline and the one in the chart, pipeline will be triggered before its changes (so before platform/ reconciliation)
- HelmRelease : based on reconciliation event. Won't work as expected, since it produces an event only after install/upgrade and not before
- Kustomization : triggers every reconciliation, not for modifications (so every 10 minutes by default)

HelmChart is the more natural to choose, but we need to resolve the pipeline trigger problem.
=> Do not register the chart version in the pipeline. Since we clone the repository in it, give in the alert the revision FluxCD is at and just check the image version in the helm chart values.

=> Unable to get commit SHA from webhook, as revision is only, so assume that recounciliation will have the same commmit.

Generic webhook example :

```json
{
    "involvedObject": {
        "apiVersion": "helm.toolkit.fluxcd.io/v2",
        "kind": "HelmRelease",
        "name": "test",
        "namespace": "test",
        "resourceVersion": 2830123,
        "uid": "cc0b6efc-3c51-486a-9d5b-4cc4c0d0ab85",
    },
    "message": "Event message here",
    "metadata": {
        "revision": "0.0.2+eb02f2ecb66c"
    },
    "reason": "UpgradeSucceeded",
    "reportingController": "helm-controller",
    "reportingInstance": "helm-controller-5547",
    "severity": "info",
    "timestamp": "2024-12-13T01:21:53Z"
}
```

=> In HelmRelease of the target chart, using `reconcileStrategy: ChartVersion` allows to repackage the chart only if its version changes.
Therefore, if we change the chart version each time we update images, then we only trigger the pipeline on new images.

**Another warning** for this is to not do commits which mix pipeline changes and chart changes, as a build will be triggered before the pipeline changes are applied.
