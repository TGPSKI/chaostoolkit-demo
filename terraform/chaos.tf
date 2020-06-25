resource "kubernetes_namespace" "crd" {
  metadata {
    name = "chaostoolkit-crd"
  }
}

resource "kubernetes_namespace" "run" {
  metadata {
    name = "chaostoolkit-run"
  }
}

resource "kubernetes_service_account" "crd" {
  metadata {
    name      = "chaostoolkit-crd"
    namespace = "chaostoolkit-crd"
  }
  automount_service_account_token = true
}

resource "kubernetes_config_map" "resources_templates" {
  metadata {
    name      = "chaostoolkit-resources-templates"
    namespace = "chaostoolkit-crd"
  }

  data = {
    "chaostoolkit-ns.yaml" = <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: chaostoolkit-run
    EOF

    "chaostoolkit-sa.yaml" = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: chaostoolkit
    EOF

    "chaostoolkit-role.yaml" = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: chaostoolkit-experiment
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - "create"
  - "get"
  - "delete"
  - "list"
    EOF

    "chaostoolkit-role-psp-rule.yaml" = <<EOF
apiGroups:
- policy
- extensions
resources:
- podsecuritypolicies
resourceNames:
- chaostoolkit-run
verbs:
- use
    EOF

    "chaostoolkit-role-binding.yaml" = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: chaostoolkit-experiment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: chaostoolkit-experiment
subjects:
- kind: ServiceAccount
  name: chaostoolkit
  namespace: chaostoolkit-run
    EOF

    "chaostoolkit-pod.yaml" = <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: chaostoolkit
  labels:
    app: chaostoolkit
spec:
  restartPolicy: Never
  serviceAccountName: chaostoolkit
  containers:
  - name: chaostoolkit
    image: tgpski/chaostoolkit-kubernetes-run:latest
    imagePullPolicy: Always
    command:
    - /usr/local/bin/chaos
    args:
    - run
    - $(EXPERIMENT_PATH)
    env:
    - name: CHAOSTOOLKIT_IN_POD
      value: "true"
    - name: EXPERIMENT_PATH
      value: "/home/svc/experiment.json"
    envFrom:
    - configMapRef:
        name: chaostoolkit-env
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
    volumeMounts:
    - name: chaostoolkit-settings
      mountPath: /home/svc/.chaostoolkit/
      readOnly: true
    - name: chaostoolkit-experiment
      mountPath: /home/svc/experiment.json
      subPath: experiment.json
      readOnly: true
  volumes:
  - name: chaostoolkit-settings
    secret:
      secretName: chaostoolkit-settings
  - name: chaostoolkit-experiment
    configMap:
      name: chaostoolkit-experiment
    EOF

    "chaostoolkit-cronjob.yaml" = <<EOF
apiVersion: batch/v1beta1
  kind: CronJob
  metadata:
    name: chaostoolkit
    labels:
      app: chaostoolkit
  spec:
    schedule: "* * * * *"
    jobTemplate:
      metadata:
        labels:
          app: chaostoolkit
      EOF
  }
}

resource "kubernetes_deployment" "crd" {
  metadata {
    name      = "chaostoolkit-crd"
    namespace = "chaostoolkit-crd"
  }


  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "chaostoolkit"
      }
    }

    template {
      metadata {
        labels = {
          app = "chaostoolkit"
        }
      }

      spec {
        service_account_name = "chaostoolkit-crd"

        volume {
          name = "service-account-token"
          secret {
            secret_name = kubernetes_service_account.crd.default_secret_name
          }
        }

        container {
          image             = "tgpski/chaostoolkit-kubernetes-crd:latest"
          image_pull_policy = "Always"
          name              = "crd"

          resources {
            limits {
              cpu    = "100m"
              memory = "64Mi"
            }
            requests {
              cpu    = "100m"
              memory = "64Mi"
            }
          }

          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name       = "service-account-token"
            read_only  = true
          }
        }
      }
    }
  }
}
