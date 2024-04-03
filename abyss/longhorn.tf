resource "kubernetes_namespace" "longhorn" {
  metadata {
    name = "longhorn-system"
    labels = {
      "pod-security.kubernetes.io/enforce"         = "privileged"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/audit"           = "privileged"
      "pod-security.kubernetes.io/audit-version"   = "latest"
      "pod-security.kubernetes.io/warn"            = "privileged"
      "pod-security.kubernetes.io/warn-version"    = "latest"
    }
  }
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  namespace  = kubernetes_namespace.longhorn.metadata[0].name
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "1.6.0"

  values = [<<YAML
    defaultSettings:
      defaultDataLocality: best-effort
      replicaAutoBalance: best-effort
      createDefaultDiskLabeledNodes: false

      backupTarget: s3://${b2_bucket.backup_target.bucket_name}@us-east-1/
      backupTargetCredentialSecret: ${kubernetes_secret.longhorn_backup_auth.metadata[0].name}
  
    networkPolicies:
      enabled: true
    persistence:
      defaultClass: false
    metrics:
      serviceMonitor:
        enabled: true
  YAML
  ]

  depends_on = [helm_release.cilium, kubectl_manifest.coreos_crds]
}

# Nodes
resource "kubectl_manifest" "longhorn_node" {
  count      = var.node_count
  yaml_body  = <<YAML
    apiVersion: longhorn.io/v1beta2
    kind: Node
    metadata:
      name: nereid-${count.index + 1}
      namespace: longhorn-system
    spec:
      name: nereid-${count.index + 1}
      allowScheduling: true
      evictionRequested: false
      instanceManagerCPURequest: 0
      disks:
        ssd-1:
          allowScheduling: true
          diskType: filesystem
          evictionRequested: false
          path: /var/lib/longhorn
          storageReserved: 21474836480
          tags:
          - ssd
        ssd-2:
          allowScheduling: true
          diskType: filesystem
          evictionRequested: false
          path: /var/mnt/ssd-2
          storageReserved: 21474836480
          tags:
          - ssd
        hdd-1:
          allowScheduling: true
          diskType: filesystem
          evictionRequested: false
          path: /var/mnt/hdd
          storageReserved: 21474836480
          tags:
          - hdd
  YAML
  depends_on = [helm_release.longhorn]
}


# Backup target
resource "b2_bucket" "backup_target" {
  bucket_name = "super-cluster-backup-longhorn"
  bucket_type = "allPrivate"
}

resource "b2_application_key" "backup_target_key" {
  key_name     = "super-cluster-backup-longhorn"
  bucket_id    = b2_bucket.backup_target.id
  capabilities = ["readBuckets", "listBuckets", "listFiles", "readFiles", "writeFiles", "deleteFiles"]
}

# Storage classes
resource "kubernetes_secret" "longhorn_backup_auth" {
  metadata {
    name      = "longhorn-backup-auth"
    namespace = kubernetes_namespace.longhorn.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = b2_application_key.backup_target_key.application_key_id
    AWS_SECRET_ACCESS_KEY = b2_application_key.backup_target_key.application_key
    AWS_ENDPOINTS         = "https://s3.us-west-004.backblazeb2.com"
  }
}

resource "kubernetes_storage_class" "longhorn_ssd" {
  metadata {
    name = "ssd"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "driver.longhorn.io"
  parameters = {
    numberOfReplicas     = "2"
    staleReplicaTimeout  = "2880"
    diskSelector         = "ssd"
    recurringJobSelector = "[{ \"name\": \"ssd-backup\", \"isGroup\": true }]"
  }
}

resource "kubernetes_storage_class" "longhorn_hdd" {
  metadata {
    name = "hdd"
  }
  storage_provisioner = "driver.longhorn.io"
  parameters = {
    numberOfReplicas     = "2"
    staleReplicaTimeout  = "2880"
    diskSelector         = "hdd"
    recurringJobSelector = "[{ \"name\": \"hdd-backup\", \"isGroup\": true }]"
  }
}

resource "kubernetes_storage_class" "longhorn_hdd_unsafe" {
  metadata {
    name = "hdd-unsafe"
  }
  storage_provisioner = "driver.longhorn.io"
  parameters = {
    numberOfReplicas    = "1"
    staleReplicaTimeout = "2880"
    diskSelector        = "hdd"
  }
}

# Backups
resource "kubectl_manifest" "longhorn_backup_ssd" {
  yaml_body = <<YAML
    apiVersion: longhorn.io/v1beta1
    kind: RecurringJob
    metadata:
      name: ssd-backup
      namespace: ${kubernetes_namespace.longhorn.metadata[0].name}
    spec:
      cron: "0 0 */2 * *"
      task: "backup"
      groups:
        - ssd-backup
      retain: 3
      concurrency: 5
  YAML

  depends_on = [helm_release.longhorn]
}

resource "kubectl_manifest" "longhorn_backup_hdd" {
  yaml_body  = <<YAML
    apiVersion: longhorn.io/v1beta1
    kind: RecurringJob
    metadata:
      name: hdd-backup
      namespace: ${kubernetes_namespace.longhorn.metadata[0].name}
    spec:
      cron: "0 0 */2 * *"
      task: "backup"
      groups:
        - hdd-backup
      retain: 3
      concurrency: 5
  YAML
  depends_on = [helm_release.longhorn]
}

# Periodic trim
resource "kubectl_manifest" "longhorn_periodic_trim" {
  yaml_body  = <<YAML
    apiVersion: longhorn.io/v1beta1
    kind: RecurringJob
    metadata:
      name: trim
      namespace: ${kubernetes_namespace.longhorn.metadata[0].name}
    spec:
      cron: "0 0 * * *"
      task: trim-filesystem
      groups:
        - default
  YAML
  depends_on = [helm_release.longhorn]
}
