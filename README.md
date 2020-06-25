# ChaosToolkit Demo

This repository shows a demo implementation of [ChaosToolkit](https://chaostoolkit.org/) in a [kubernetes environment](https://github.com/chaostoolkit-incubator/kubernetes-crd). Chaos experiment lifecycle is managed by a custom operator based on [kopf](https://github.com/zalando-incubator/kopf). Experiments are defined in json or yaml format written to kubernetes configmaps.

This does not represent a complete out of the box demo. The end user will need to understand how these pieces fit together and should have experience in Docker, Kubernetes, Terraform, ChaosToolkit, and logging strategies. The demo components should be implemented in order:

* Docker
* Terraform
* Manifests
* Experiments
* Logging

# Running an experiment

See the step-by-step breakdown and flow diagram [here](docs/running-an-experiment.md).

## Docker

### crd

The crd docker image is based on kopf, a python framework for writing kubernetes operators. In addition, the rest of the chaostoolkit codebase is written in python. The base repository for the kubernetes-crd is located [here](https://github.com/chaostoolkit-incubator/kubernetes-crd).

### run

The run docker image is based on [chaostoolkit/chaostoolkit](https://github.com/chaostoolkit/chaostoolkit). A custom docker file is required for use cases that use chaostoolkit plugins.

## Terraform

`chaos.tf` shows a Terraform implementation of the manifests found in the [kubernetes-crd](https://github.com/chaostoolkit-incubator/kubernetes-crd).

Importantly, the images used for crd and run must be specified in the configmap (for the runner) and the deployment (for the crd).

## Manifests

Currently, the kubernetes terraform provider cannot create custom resource definitions, so additional manifests are located here. The cluster-role-rbac.yaml file can easily be implemented in terraform. Once CRD support is merged with the master kubernetes terraform provider, this folder can be eliminated entirely. 

## Experiments

Three experiments are included in the demo.

* `hello-world` uses basic functionality in the chaostoolkit library
* `kill-pods-with-label` uses the chaostoolkit-kubernetes plugin to create chaos with the k8s api
* `stop-ec2-by-id` uses the chaostoolkit-aws plugin to create chaos with the aws api

In addition, the open chaos community has a [catalog](https://github.com/open-chaos/experiment-catalog) of chaos experiments based on plugin / provider. This is useful for kickstarting a chaos engineering effort.

## Logging

Logging configuration is driven by a settings.yaml file that can be mounted to running pods as a volume. Included in the demo is the output from the `kill-pod-by-label.yaml` experiment (by default written to chaostoolkit.log). Logging is appending to a local file, sending http requests to a data sink, sending webhooks to slack, or writing a custom logging driver. 

```
kubectl -n chaostoolkit-run \
    create secret generic chaostoolkit-settings \
    --from-file=settings.yaml=./settings.yaml
```
