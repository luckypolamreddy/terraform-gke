# Execution Plan

## Pre-requisites

1. **Azure DevOps Variable Groups** - Create one per project:
   - `gcp-credentials-project-a` containing:
     - `GCP_SA_KEY` - Full JSON content of GCP service account key
     - `GCP_PROJECT_ID` - GCP project ID
     - `TF_STATE_BUCKET` - GCS bucket for terraform state
   - `gcp-credentials-project-b` - Same variables for project B

2. **Azure DevOps Environments** - Create these environments (for deployment gates/approvals):
   - `project-a-foundation`
   - `project-a-cluster`
   - `project-a-backup`
   - `project-a-eck`
   - `project-b-foundation`, `project-b-cluster`, `project-b-backup`, `project-b-eck`

3. **Terraform State Bucket** - Create a GCS bucket for terraform state storage (one per project)

4. **ADO Agent** - Agent must have installed: `terraform`, `gcloud`, `kubectl`, `envsubst`

---

## Deployment Order (Build Up)

Run pipelines in this exact order:

```
Step 1: 01-foundation.yml     (action: apply)   → Creates VPC, GCS bucket, Secret Manager
Step 2: 02-cluster.yml        (action: apply)    → Creates Subnet + GKE cluster + Node pools
Step 3: 03-backup.yml         (action: apply)    → Creates GKE Backup Plan
Step 4: 04-eck-deploy.yml                        → Deploys ECK operator + Elasticsearch + Kibana + Snapshots
Step 5: 06-monitoring-self.yml (action: deploy)  → Option A: Self-monitoring
   OR
Step 5: 07-monitoring-dedicated.yml (action: deploy) → Option B: Dedicated monitoring cluster
```

### What each step creates:

| Step | Pipeline | Resources Created |
|------|----------|-------------------|
| 1 | Foundation | VPC, GCS Bucket, Secret Manager secrets |
| 2 | Cluster | Subnet, GKE Cluster, 3 Node Pools (controlplane, elastic-master, elastic-data) |
| 3 | Backup | GKE Backup Plan (daily RPO, elastic namespaces only, 7-day retention) |
| 4 | ECK Deploy | ECK Operator, Enterprise License, Elasticsearch (master+data), Kibana, GCS Snapshot Repo, SLM Policy, Index Settings, Kibana creds synced to Secret Manager |
| 5 | Monitoring | Metricbeat, Filebeat, Stack Monitoring (self or dedicated) |

---

## Destroy Order (Tear Down)

Run pipelines in this exact reverse order:

```
Step 1: 06-monitoring-self.yml (action: destroy)      → Remove monitoring
   OR
Step 1: 07-monitoring-dedicated.yml (action: destroy)  → Remove dedicated monitoring cluster

Step 2: 05-eck-destroy.yml                             → Remove ECK stack + operator

Step 3: 03-backup.yml  (action: destroy)               → Remove Backup Plan (auto-cleans backups)

Step 4: 02-cluster.yml (action: destroy)               → Remove GKE cluster + Subnet

Step 5: 01-foundation.yml (action: destroy)            → OPTIONAL: Remove VPC, GCS, Secrets
         ⚠️  Foundation has prevent_destroy - only destroy if decommissioning entirely
```

### Important destroy notes:
- **Backup Plan**: The terraform module automatically pauses the backup schedule and deletes existing backups before destroying the plan
- **Foundation**: VPC, GCS bucket, and Secret Manager have `prevent_destroy = true`. To destroy, first remove the lifecycle block from the module code
- **GKE Cluster**: Destroying the cluster also destroys the subnet (both in same terraform stack)

---

## Runtime Parameter Overrides

All terraform pipelines support overriding key values at runtime:

### Foundation Pipeline
| Parameter | Description |
|-----------|-------------|
| `vpcName` | Override VPC name |
| `gcsBucketName` | Override GCS bucket name |

### Cluster Pipeline
| Parameter | Description |
|-----------|-------------|
| `clusterName` | Override GKE cluster name |
| `kubernetesVersion` | Choose Kubernetes version (e.g., 1.30, 1.31) |
| `machineType` | Override machine type for controlplane pool |

### ECK Deploy Pipeline
| Parameter | Description |
|-----------|-------------|
| `esClusterName` | Elasticsearch cluster name |
| `esVersion` | Elasticsearch version |
| `eckOperatorVersion` | ECK operator version |
| `gcsBucketName` | GCS bucket for snapshots |

---

## Node Pool Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     GKE Cluster                               │
├──────────────────┬───────────────────┬───────────────────────┤
│ controlplane-pool│ elastic-master-pool│ elastic-data-pool     │
│ n1-highmem-16    │ e2-standard-4      │ n1-highmem-16         │
│ 3 nodes          │ 3 nodes            │ 3 nodes               │
│ No taints        │ Taint: elastic-role│ Taint: elastic-role   │
│                  │ =master:NoSchedule │ =data:NoSchedule      │
│ Runs:            │ Runs:              │ Runs:                 │
│  - ECK Operator  │  - ES Master pods  │  - ES Data pods       │
│  - Kibana        │                    │                       │
│  - Monitoring    │                    │                       │
│    Beats         │                    │                       │
└──────────────────┴───────────────────┴───────────────────────┘
```

**How taints work with ECK:**
- `controlplane-pool` has NO taints → ECK operator, Kibana, and Beats schedule here
- `elastic-master-pool` has taint `elastic-role=master:NoSchedule` → Only ES master pods (with matching tolerations) schedule here
- `elastic-data-pool` has taint `elastic-role=data:NoSchedule` → Only ES data pods (with matching tolerations) schedule here
- Beats (Metricbeat/Filebeat) run as DaemonSets with `tolerations` for all elastic taints, so they collect metrics from ALL nodes

---

## Directory Structure

```
terraform-gke/
├── modules/                          # Generic, reusable Terraform modules
│   ├── vpc/                          # VPC network
│   ├── subnet/                       # Subnet (tied to cluster)
│   ├── gke-cluster/                  # GKE cluster + node pools
│   ├── gke-backup-plan/              # Backup plan with auto-cleanup
│   ├── gcs-bucket/                   # GCS bucket with IAM
│   └── secret-manager/              # Secret Manager secrets with IAM
│
├── stacks/                           # Terraform compositions (use modules)
│   ├── foundation/                   # VPC + GCS + Secrets (long-lived)
│   ├── cluster/                      # Subnet + GKE (cluster lifecycle)
│   └── backup/                       # Backup plan (cluster lifecycle)
│
├── environments/                     # Variable files per project/cluster
│   ├── project-a/
│   │   ├── foundation.tfvars
│   │   ├── cluster-1.tfvars
│   │   └── backup-cluster-1.tfvars
│   └── project-b/
│       └── ...
│
├── eck/                              # ECK Kubernetes manifests
│   ├── 00-namespaces.yaml
│   ├── 01-enterprise-license.yaml
│   ├── 02-gcs-credentials.yaml      # Template (populated by pipeline)
│   ├── 03-synonyms-configmap.yaml
│   ├── 04-elasticsearch.yaml         # Uses ${ES_CLUSTER_NAME}, ${ES_VERSION}
│   ├── 05-kibana.yaml
│   ├── 06-snapshot-repository.yaml   # Job: creates snapshot repo + SLM policy
│   ├── 07-index-settings.yaml       # Job: default index templates
│   └── monitoring/
│       ├── option-a-self/            # Self-monitoring (send to same cluster)
│       │   ├── stack-monitoring.yaml
│       │   ├── metricbeat.yaml
│       │   └── filebeat.yaml
│       └── option-b-dedicated/       # Dedicated monitoring cluster
│           ├── monitoring-elasticsearch.yaml
│           ├── stack-monitoring.yaml
│           ├── metricbeat.yaml
│           └── filebeat.yaml
│
├── pipelines/                        # Azure DevOps YAML pipelines
│   ├── templates/
│   │   └── terraform-steps.yml       # Reusable terraform template
│   ├── 01-foundation.yml
│   ├── 02-cluster.yml
│   ├── 03-backup.yml
│   ├── 04-eck-deploy.yml
│   ├── 05-eck-destroy.yml
│   ├── 06-monitoring-self.yml        # Option A
│   └── 07-monitoring-dedicated.yml   # Option B
│
└── EXECUTION-PLAN.md
```

---

## Adding a New Cluster

To add a new cluster (e.g., cluster-2) to an existing project:

1. Copy `environments/project-a/cluster-1.tfvars` → `cluster-1.tfvars` renamed to `cluster-2.tfvars`
2. Update values: `cluster_name`, `subnet_name`, `subnet_cidr`, `pods_cidr`, `services_cidr`
3. Copy `backup-cluster-1.tfvars` → `backup-cluster-2.tfvars`, update `backup_plan_name` and `cluster_id`
4. Add `cluster-2` to the `clusterConfig` parameter values in `02-cluster.yml` and `03-backup.yml`
5. Run the pipelines in order

---

## Adding a New Node Pool

To add a new node pool to an existing cluster:

1. Edit the cluster's `.tfvars` file
2. Add a new entry to the `node_pools` list
3. Re-run `02-cluster.yml` with action `apply`

Example - adding an ingest pool:
```hcl
{
  name               = "elastic-ingest-pool"
  machine_type       = "e2-standard-8"
  node_count         = 2
  disk_type          = "pd-ssd"
  disk_size_gb       = 100
  image_type         = "COS_CONTAINERD"
  enable_autoscaling = false
  min_node_count     = 0
  max_node_count     = 0
  auto_upgrade       = true
  labels = {
    "elastic-role" = "ingest"
  }
  taints = [
    {
      key    = "elastic-role"
      value  = "ingest"
      effect = "NO_SCHEDULE"
    }
  ]
}
```
