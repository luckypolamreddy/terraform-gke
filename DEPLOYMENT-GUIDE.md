# GKE Elastic Stack — Deployment Guide

**Audience:** Platform Engineers · DevOps Engineers · Developers
**Scope:** Pipeline 02 (Cluster) and Pipeline 04 (ECK Deploy)
**Maintained by:** Platform Engineering

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Environment Reference](#2-environment-reference)
3. [Prerequisites & One-Time Setup](#3-prerequisites--one-time-setup)
4. [Pipeline 02 — GKE Cluster Deployment](#4-pipeline-02--gke-cluster-deployment)
5. [Pipeline 04 — ECK Stack Deployment](#5-pipeline-04--eck-stack-deployment)
6. [JVM Sizing Reference](#6-jvm-sizing-reference)
7. [Resource Allocation Per Node](#7-resource-allocation-per-node)
8. [Kubernetes Resource Inventory](#8-kubernetes-resource-inventory)
9. [Post-Deployment Verification](#9-post-deployment-verification)
10. [Teardown Order](#10-teardown-order)
11. [Troubleshooting Reference](#11-troubleshooting-reference)

---

## 1. Architecture Overview

```
Azure DevOps Pipelines
        │
        ├── 01-foundation.yml      ← VPC                                  (run once)
        ├── 02-cluster.yml         ← GKE cluster + node pool + GCS bucket (this guide)
        ├── 03-backup.yml          ← GKE backup agent config
        ├── 04-eck-deploy.yml      ← ECK operator, ES, Kibana          (this guide)
        ├── 05-eck-destroy.yml     ← Tear down ECK stack
        ├── 06-monitoring-self.yml ← Self-monitoring (Metricbeat + Filebeat)
        └── 07-monitoring-dedicated.yml ← Dedicated monitoring cluster

GCP Project (per environment)
  └── VPC: <project>-vpc
       └── GKE Regional Cluster (us-east1)
            └── Node Pool: elastic-pool
                 └── 3 nodes × n1-highmem-16 (1 per zone: b, c, d)
                      ├── elastic-system namespace
                      │    └── ECK Operator (elastic-operator deployment)
                      └── elastic-stack namespace
                           ├── Elasticsearch  (3 pods — master+data+ingest)
                           └── Kibana         (2 pods)
```

---

## 2. Environment Reference

### 2.1 Environment Summary

| Attribute              | Dev (Non-Prod)                        | Prod                                  |
|------------------------|---------------------------------------|---------------------------------------|
| **GCP Project**        | `pg-us-n-app-259723`                  | `pg-us-e-app-012345`                  |
| **ADO Variable Group** | `gcp-credentials-pg-us-n-app-259723`  | `gcp-credentials-pg-us-e-app-012345`  |
| **Region**             | `us-east1`                            | `us-east1`                            |
| **Zones**              | `us-east1-b`, `us-east1-c`, `us-east1-d` | `us-east1-b`, `us-east1-c`, `us-east1-d` |
| **VPC**                | `pg-us-n-app-259723-vpc`              | `pg-us-e-app-012345-vpc`              |
| **Subnet CIDR**        | `10.10.0.0/20`                        | `10.20.0.0/20`                        |
| **Pods CIDR**          | `10.10.16.0/20`                       | `10.20.16.0/20`                       |
| **Services CIDR**      | `10.10.32.0/20`                       | `10.20.32.0/20`                       |
| **GCS Snapshot Bucket**| `pg-us-n-app-259723-eck-snapshots`    | `pg-us-e-app-012345-eck-snapshots`    |
| **TF State Prefix**    | `cluster/pg-us-n-app-259723/<name>`   | `cluster/pg-us-e-app-012345/<name>`   |
| **Terraform SA**       | `terraform-sa@pg-us-n-app-259723...`  | `terraform-sa@pg-us-e-app-012345...`  |
| **Deletion Protection**| `false`                               | `false`                               |

### 2.2 Node Pool Comparison

| Attribute         | Dev                        | Prod                       |
|-------------------|----------------------------|----------------------------|
| **Pool Name**     | `elastic-pool`             | `elastic-pool`             |
| **Machine Type**  | `n1-highmem-16`            | `n1-highmem-16`            |
| **vCPU / RAM**    | 16 vCPU / 104 GB           | 16 vCPU / 104 GB           |
| **Node Count**    | 1 per zone = **3 total**   | 1 per zone = **3 total**   |
| **Disk Type**     | `pd-ssd`                   | `pd-ssd`                   |
| **Disk Size**     | **500 GB** per node        | **1000 GB** per node       |
| **Image**         | `COS_CONTAINERD`           | `COS_CONTAINERD`           |
| **Autoscaling**   | Disabled                   | Disabled                   |
| **Auto Upgrade**  | Enabled                    | Enabled                    |
| **Taints**        | None                       | None                       |
| **Labels**        | None                       | None                       |

### 2.3 Elastic Stack Component Comparison

| Component             | Dev                   | Prod                  |
|-----------------------|-----------------------|-----------------------|
| **ES Version**        | `9.3.1`               | `9.3.1`               |
| **ECK Operator**      | `9.3.1`               | `9.3.1`               |
| **ES Nodes**          | 3                     | 3                     |
| **ES Roles**          | master + data + ingest + transform | master + data + ingest + transform |
| **ES Memory (request)**| `16Gi`               | `16Gi`                |
| **ES Memory (max)**   | `32Gi`                | `32Gi`                |
| **ES CPU (request)**  | `8`                   | `8`                   |
| **ES CPU (max)**      | `12`                  | `12`                  |
| **ES JVM Heap**       | `8g` (default)        | `8g` (default)        |
| **ES Storage**        | `500Gi` per pod (pd-ssd) | `500Gi` per pod (pd-ssd) |
| **Kibana Replicas**   | 2                     | 2                     |
| **Kibana Memory**     | `4Gi`                 | `4Gi`                 |
| **Kibana CPU**        | `2`                   | `2`                   |
| **ES Endpoint**       | External LoadBalancer  | External LoadBalancer  |
| **Kibana Endpoint**   | External LoadBalancer  | External LoadBalancer  |
| **TLS**               | Self-signed cert       | Self-signed cert       |

---

## 3. Prerequisites & One-Time Setup

> These must be completed **before** running either pipeline. They only need to be done once per environment.

### 3.1 ADO Variable Groups

Each environment requires a variable group named `gcp-credentials-<project>` in Azure DevOps Library.

**Required secrets per group:**

| Variable Name          | Description                                              | Example / Notes                             |
|------------------------|----------------------------------------------------------|---------------------------------------------|
| `GCP_SA_KEY`           | Full JSON content of the GCP service account key        | `{ "type": "service_account", ... }`        |
| `GCP_PROJECT_ID`       | GCP project ID                                          | `pg-us-n-app-259723`                        |
| `TF_STATE_BUCKET`      | GCS bucket storing Terraform remote state               | `pg-us-n-app-259723-tf-state`               |

### 3.2 Run Pipeline 01 — Foundation (one-time per environment)

Pipeline `01-foundation.yml` creates the VPC that persists across cluster lifecycles:

| Resource          | Dev                                        | Prod                                        |
|-------------------|--------------------------------------------|---------------------------------------------|
| VPC               | `pg-us-n-app-259723-vpc`                   | `pg-us-e-app-012345-vpc`                    |

> **Note:** GCS bucket is now managed by the cluster pipeline (`02-cluster.yml`) so it is automatically created/deleted with the cluster.

### 3.3 GCP Service Account Permissions

The Terraform SA (`terraform-sa@<project>.iam.gserviceaccount.com`) must have:

- `roles/container.admin` — Create/manage GKE clusters
- `roles/compute.networkAdmin` — Create subnets
- `roles/storage.admin` — Create GCS buckets
- `roles/iam.serviceAccountUser` — Impersonate for node pool SA

### 3.4 ADO Environment Approvals (optional but recommended for prod)

Pipeline 02 uses deployment environments:
- `pg-us-n-app-259723-cluster` (dev — no approval gate required)
- `pg-us-e-app-012345-cluster` (prod — configure approval gate in ADO)

---

## 4. Pipeline 02 — GKE Cluster Deployment

**File:** `pipelines/02-cluster.yml`
**Terraform stack:** `stacks/cluster/`
**Config files:** `environments/<project>/cluster.tfvars`

### 4.1 When to Run

| Scenario                              | Action     |
|---------------------------------------|------------|
| First-time cluster creation           | `apply`    |
| Changing node pool size or machine type| `apply`   |
| Kubernetes version upgrade            | `apply`    |
| Tear down the cluster                 | `destroy`  |

### 4.2 Pipeline Parameters

| Parameter     | Type   | Values                                    | Default              | Required |
|---------------|--------|-------------------------------------------|----------------------|----------|
| `action`      | string | `apply` / `destroy`                       | `apply`              | Yes      |
| `project`     | string | `pg-us-n-app-259723` / `pg-us-e-app-012345` | `pg-us-n-app-259723` | Yes    |
| `clusterName` | string | Free text (e.g. `eck-dev-01`)             | *(none)*             | **Yes**  |

> **Cluster naming convention:** Use descriptive names like `eck-dev-01`, `eck-prod-01`. The name is used as the Kubernetes context name and in Terraform state path (`cluster/<project>/<clusterName>`). It must be unique within the project.

### 4.3 Pipeline Stages

```
┌─────────────────────────────────────────────────────────────┐
│  STAGE 1: Plan  (always runs)                               │
│  ─ Terraform init → plan → print diff                       │
│  ─ No infrastructure changes made                           │
│  ─ Shows exactly what will be created/modified/destroyed    │
└──────────────────────┬──────────────────────────────────────┘
                       │ on success
           ┌───────────┴───────────┐
           ▼                       ▼
┌──────────────────┐    ┌──────────────────────┐
│  STAGE 2: Apply  │    │  STAGE 3: Destroy     │
│  (action=apply)  │    │  (action=destroy)     │
│  ─ terraform apply│   │  ─ terraform destroy  │
│  ─ Creates:       │   │  ─ Removes:           │
│    • Subnet       │   │    • Subnet           │
│    • GKE cluster  │   │    • GKE cluster      │
│    • Node pool    │   │    • Node pool        │
└──────────────────┘    └──────────────────────┘
```

### 4.4 What Gets Created (apply)

#### Subnet
| Attribute         | Dev                  | Prod                 |
|-------------------|----------------------|----------------------|
| Name              | `<clusterName>-subnet-01` | `<clusterName>-subnet-01` |
| Primary CIDR      | `10.10.0.0/20`       | `10.20.0.0/20`       |
| Pods secondary    | `10.10.16.0/20`      | `10.20.16.0/20`      |
| Services secondary| `10.10.32.0/20`      | `10.20.32.0/20`      |
| Region            | `us-east1`           | `us-east1`           |

#### GKE Cluster
| Attribute              | Dev / Prod (same)                    |
|------------------------|--------------------------------------|
| Type                   | Regional (multi-zone)                |
| Location               | `us-east1`                           |
| Zones                  | `us-east1-b`, `us-east1-c`, `us-east1-d` |
| Kubernetes version     | `1.30`                               |
| Networking mode        | VPC-native (`VPC_NATIVE`)            |
| Default node pool      | Removed (custom pools only)          |
| Control plane access   | DNS-based endpoint (no public IP)    |
| HTTP LB addon          | Enabled                              |
| GKE Backup addon       | Enabled                              |
| Managed Prometheus     | Enabled                              |
| Cost allocation        | Enabled                              |
| Logging                | `SYSTEM_COMPONENTS`, `WORKLOADS`     |
| Monitoring             | `SYSTEM_COMPONENTS`                  |
| Deletion protection    | `false`                              |

#### Maintenance Window
| Attribute   | Value                        |
|-------------|------------------------------|
| Day         | Saturday (weekly)            |
| Start       | `2026-02-21T00:00:00Z`       |
| End         | `2026-02-22T00:00:00Z`       |
| Recurrence  | `FREQ=WEEKLY;BYDAY=SA`       |

#### Node Pool: `elastic-pool`
| Attribute      | Dev                   | Prod                  |
|----------------|-----------------------|-----------------------|
| Machine type   | `n1-highmem-16`       | `n1-highmem-16`       |
| vCPU           | 16                    | 16                    |
| RAM            | 104 GB                | 104 GB                |
| Nodes per zone | 1                     | 1                     |
| Total nodes    | **3** (1 × 3 zones)   | **3** (1 × 3 zones)   |
| Disk type      | `pd-ssd`              | `pd-ssd`              |
| Disk size      | 500 GB                | 1000 GB               |
| Image type     | `COS_CONTAINERD`      | `COS_CONTAINERD`      |
| Autoscaling    | Off                   | Off                   |
| Auto upgrade   | On                    | On                    |
| Taints         | None                  | None                  |
| Auto repair    | On                    | On                    |

### 4.5 Terraform State Location

| Environment | State path                                                |
|-------------|-----------------------------------------------------------|
| Dev         | `gs://<TF_STATE_BUCKET>/cluster/pg-us-n-app-259723/<clusterName>` |
| Prod        | `gs://<TF_STATE_BUCKET>/cluster/pg-us-e-app-012345/<clusterName>` |

### 4.6 Step-by-Step: Running the Cluster Pipeline

1. Navigate to **Azure DevOps → Pipelines → `02-cluster` (or cluster-pipeline)**
2. Click **Run pipeline**
3. Fill in parameters:

   | Field        | Dev Example          | Prod Example          |
   |--------------|----------------------|-----------------------|
   | Action       | `apply`              | `apply`               |
   | GCP Project  | `pg-us-n-app-259723` | `pg-us-e-app-012345`  |
   | Cluster Name | `eck-dev-01`         | `eck-prod-01`         |

4. **Review the Plan stage output** before Apply proceeds
5. Apply stage runs automatically if Plan succeeds and `action=apply`
6. Total runtime: ~10–15 minutes

### 4.7 Verifying Cluster Creation

```bash
# Get credentials
gcloud container clusters get-credentials <clusterName> \
  --region us-east1 \
  --project <project>

# Verify nodes (should show 3)
kubectl get nodes -o wide

# Expected output:
# NAME                                   STATUS   ROLES    AGE   VERSION
# gke-<name>-elastic-pool-xxxx-b-xxxxx   Ready    <none>   Xm    v1.30.x
# gke-<name>-elastic-pool-xxxx-c-xxxxx   Ready    <none>   Xm    v1.30.x
# gke-<name>-elastic-pool-xxxx-d-xxxxx   Ready    <none>   Xm    v1.30.x
```

---

## 5. Pipeline 04 — ECK Stack Deployment

**File:** `pipelines/04-eck-deploy.yml`
**Manifests directory:** `eck/`

### 5.1 When to Run

| Scenario                              | Notes                                    |
|---------------------------------------|------------------------------------------|
| First-time ECK installation           | Run after Pipeline 02 completes         |
| Elasticsearch / Kibana version upgrade| Update `ES_VERSION` in pipeline vars first |
| JVM heap change                       | Change the `esJvmHeap` parameter        |
| Disaster recovery / reinstall         | Safe to re-run, all steps are idempotent|

### 5.2 Pipeline Parameters (User Inputs)

| Parameter     | Type   | Default              | Required | Description                               |
|---------------|--------|----------------------|----------|-------------------------------------------|
| `project`     | string | `pg-us-n-app-259723` | Yes      | Target GCP project / environment          |
| `clusterName` | string | *(none)*             | **Yes**  | GKE cluster name (must already exist)     |
| `esJvmHeap`   | string | `8g`                 | Yes      | JVM heap for each Elasticsearch pod       |

> **JVM Heap Rule:** Always set to **50% of the container memory request**. Container memory request is `16Gi`, so the default is `8g`. Never exceed `32g`. See [Section 6](#6-jvm-sizing-reference) for full sizing table.

### 5.3 Fixed Pipeline Variables (not user-configurable at runtime)

These are defined in the pipeline YAML and must be updated in source control to change:

| Variable             | Value                          | Where to change           |
|----------------------|--------------------------------|---------------------------|
| `ES_CLUSTER_NAME`    | `elasticsearch`                | `pipelines/04-eck-deploy.yml` |
| `KIBANA_NAME`        | `kibana`                       | `pipelines/04-eck-deploy.yml` |
| `ES_VERSION`         | `9.3.1`                        | `pipelines/04-eck-deploy.yml` |
| `ECK_OPERATOR_VERSION`| `9.3.1`                       | `pipelines/04-eck-deploy.yml` |
| `CLUSTER_LOCATION`   | `us-east1`                     | `pipelines/04-eck-deploy.yml` |
| `GCS_BUCKET_NAME`    | `<project>-eck-snapshots`      | Auto-derived from project  |
| `SNAPSHOT_REPO_NAME` | `gcs-snapshots`                | `pipelines/04-eck-deploy.yml` |
| `SNAPSHOT_BASE_PATH` | `es-snapshots`                 | `pipelines/04-eck-deploy.yml` |
| `SLM_POLICY_NAME`    | `daily-snapshots`              | `pipelines/04-eck-deploy.yml` |

### 5.4 Pipeline Stages and Steps

```
┌────────────────────────────────────────────────────────────────────┐
│  STAGE 1: ECK_Operator                                             │
│  ─ Install gke-gcloud-auth-plugin                                  │
│  ─ Authenticate to GKE                                             │
│  ─ Create Namespaces (elastic-system, elastic-stack)               │
│  ─ Install ECK CRDs  (from Elastic download CDN)                   │
│  ─ Install ECK Operator + wait for rollout ready                   │
└───────────────────────────────┬────────────────────────────────────┘
                                │ dependsOn: ECK_Operator
┌───────────────────────────────▼────────────────────────────────────┐
│  STAGE 2: ECK_Stack                                                │
│  ─ Install gke-gcloud-auth-plugin                                  │
│  ─ Authenticate to GKE                                             │
│  ─ Create GCS Credentials Secret  (gcs-credentials in elastic-stack)│
│  ─ Apply Synonyms ConfigMap       (03-synonyms-configmap.yaml)     │
│  ─ Deploy Elasticsearch           (04-elasticsearch.yaml)          │
│  ─ Deploy Kibana                  (05-kibana.yaml)                 │
│  ─ Wait for Elasticsearch green   (timeout: 10 min)                │
│  ─ Wait for Kibana green          (timeout: 5 min)                 │
└───────────────────────────────┬────────────────────────────────────┘
                                │ dependsOn: ECK_Stack
┌───────────────────────────────▼────────────────────────────────────┐
│  STAGE 3: ECK_Configure                                            │
│  ─ Install gke-gcloud-auth-plugin                                  │
│  ─ Authenticate to GKE                                             │
│  ─ Setup Snapshot Repository + SLM Policy  (K8s Job)              │
│  ─ Setup Index Settings                    (K8s Job)              │
│  ─ Wait for setup Jobs to complete                                 │
└────────────────────────────────────────────────────────────────────┘
```

### 5.5 Stage 1 Detail: ECK Operator

| Step                        | What it does                                                              |
|-----------------------------|---------------------------------------------------------------------------|
| Install gke-gcloud-auth-plugin | Installs the GKE auth plugin on the ADO agent (required for kubectl) |
| Authenticate to GKE         | Activates GCP SA key, runs `gcloud container clusters get-credentials`   |
| Create Namespaces           | `kubectl apply -f eck/00-namespaces.yaml` — idempotent                   |
| Install ECK CRDs            | `kubectl apply --server-side` from `download.elastic.co/downloads/eck/9.3.1/crds.yaml` |
| Install ECK Operator        | Applies `operator.yaml`, then waits for `elastic-operator` deployment rollout (120s timeout) |

**Namespaces created:**

| Namespace       | Purpose                           |
|-----------------|-----------------------------------|
| `elastic-system`| ECK operator lives here           |
| `elastic-stack` | Elasticsearch, Kibana, Beats live here |

### 5.6 Stage 2 Detail: Elasticsearch & Kibana

#### GCS Credentials Secret
Creates a Kubernetes secret `gcs-credentials` in `elastic-stack` namespace from the `GCP_SA_KEY` variable. This allows Elasticsearch to write snapshots to GCS. The secret key is `gcs.client.default.credentials_file`.

#### Synonyms ConfigMap
Applies `eck/03-synonyms-configmap.yaml` → `elasticsearch-synonyms` ConfigMap in `elastic-stack`. This is mounted into ES data nodes at `/usr/share/elasticsearch/config/synonyms`.

#### Elasticsearch Deployment (`eck/04-elasticsearch.yaml`)

Variables substituted at deploy time:

| Placeholder       | Source                    | Value                  |
|-------------------|---------------------------|------------------------|
| `${ES_CLUSTER_NAME}` | Pipeline variable      | `elasticsearch`        |
| `${ES_VERSION}`   | Pipeline variable         | `9.3.1`                |
| `${ES_JVM_HEAP}`  | **User parameter**        | `8g` (default)         |

Full specification deployed:

| Attribute             | Value                                                         |
|-----------------------|---------------------------------------------------------------|
| Kind                  | `Elasticsearch` (ECK CRD)                                     |
| Name                  | `elasticsearch`                                               |
| Namespace             | `elastic-stack`                                               |
| Node count            | 3                                                             |
| Node roles            | `master`, `data`, `data_content`, `data_hot`, `ingest`, `transform` |
| Memory request        | `16Gi`                                                        |
| Memory limit          | `32Gi`                                                        |
| CPU request           | `8`                                                           |
| CPU limit             | `12`                                                          |
| JVM heap (`-Xms/-Xmx`)| `${ES_JVM_HEAP}` — default `8g`                              |
| `node.store.allow_mmap`| `false` (GKE restriction — mmap disabled)                   |
| `vm.max_map_count`    | Set to `262144` by privileged init container (`sysctl`)       |
| PVC per pod           | `500Gi`, `pd-ssd`, `premium-rwo` StorageClass, `ReadWriteOnce`|
| HTTP service type     | `LoadBalancer` (external IP)                                  |
| TLS                   | Self-signed certificate (ECK-managed)                         |
| Port                  | `9200` (HTTPS)                                                |
| Secure settings       | `gcs-credentials` secret (for GCS snapshot plugin)           |
| Synonyms mount        | ConfigMap `elasticsearch-synonyms` → `/usr/share/elasticsearch/config/synonyms` |

#### Kibana Deployment (`eck/05-kibana.yaml`)

Variables substituted at deploy time:

| Placeholder               | Source             | Value                                          |
|---------------------------|--------------------|------------------------------------------------|
| `${KIBANA_NAME}`          | Pipeline variable  | `kibana`                                       |
| `${ES_CLUSTER_NAME}`      | Pipeline variable  | `elasticsearch`                                |
| `${ES_VERSION}`           | Pipeline variable  | `9.3.1`                                        |
| `${KIBANA_EXTERNAL_HOST}` | Pipeline (auto)    | `kibana.<project>.example.com`                 |

Full specification deployed:

| Attribute             | Value                                      |
|-----------------------|--------------------------------------------|
| Kind                  | `Kibana` (ECK CRD)                         |
| Name                  | `kibana`                                   |
| Namespace             | `elastic-stack`                            |
| Replica count         | `2`                                        |
| Memory limit/request  | `4Gi`                                      |
| CPU request           | `2`                                        |
| ES reference          | `elasticsearch` (auto-discovers ES service)|
| server.name           | `kibana`                                   |
| Stack monitoring      | `monitoring.kibana.collection.enabled: true`|
| HTTP service type     | `LoadBalancer` (external IP)               |
| TLS                   | Self-signed certificate (ECK-managed)      |
| Port                  | `5601` (HTTPS)                             |
| Log format            | JSON (structured)                          |

#### Health Waits

| Resource      | Condition     | Timeout     | ADO Timeout |
|---------------|---------------|-------------|-------------|
| Elasticsearch | `health=green` | 600 seconds | 12 minutes  |
| Kibana        | `health=green` | 300 seconds | 7 minutes   |

### 5.7 Stage 3 Detail: Configure

#### Snapshot Repository & SLM Policy (`eck/06-snapshot-repository.yaml`)

Runs as a Kubernetes Job (`setup-snapshot-repo`) in `elastic-stack`. The job:
1. Waits for Elasticsearch to respond on `/_cluster/health`
2. Creates a GCS snapshot repository via `PUT /_snapshot/gcs-snapshots`
3. Creates an SLM policy `daily-snapshots` via `PUT /_slm/policy/daily-snapshots`

| Attribute         | Value                               |
|-------------------|-------------------------------------|
| GCS Bucket        | `<project>-eck-snapshots`           |
| Base path         | `es-snapshots`                      |
| Snapshot schedule | Daily at 01:00 UTC (`0 0 1 * * ?`) |
| Indices           | All (`*`)                           |
| Retention         | 7 days / min 1 / max 7             |
| Auth              | `elastic` user from ECK-managed secret |

#### Index Settings (`eck/07-index-settings.yaml`)

Runs as a Kubernetes Job (`setup-index-settings`) in `elastic-stack`.
Sets default index templates/settings for the cluster.

### 5.8 Step-by-Step: Running the ECK Pipeline

1. Confirm Pipeline 02 completed successfully and nodes are Ready
2. Navigate to **Azure DevOps → Pipelines → `04-eck-deploy` (or eck-deploy-pipeline)**
3. Click **Run pipeline**
4. Fill in parameters:

   | Field        | Dev Example          | Prod Example          |
   |--------------|----------------------|-----------------------|
   | GCP Project  | `pg-us-n-app-259723` | `pg-us-e-app-012345`  |
   | Cluster Name | `eck-dev-01`         | `eck-prod-01`         |
   | ES JVM Heap  | `8g`                 | `8g`                  |

5. Monitor stages sequentially — each stage must pass before the next starts
6. Total runtime: ~20–35 minutes (most time is waiting for ES green)

### 5.9 Files Reference

| File                            | Purpose                                      |
|---------------------------------|----------------------------------------------|
| `eck/00-namespaces.yaml`        | Creates `elastic-system` and `elastic-stack` |
| `eck/03-synonyms-configmap.yaml`| Search synonyms for Elasticsearch            |
| `eck/04-elasticsearch.yaml`     | Elasticsearch cluster definition (ECK CRD)  |
| `eck/05-kibana.yaml`            | Kibana deployment (ECK CRD)                  |
| `eck/06-snapshot-repository.yaml`| K8s Job: GCS repo + SLM policy setup       |
| `eck/07-index-settings.yaml`    | K8s Job: Default index template/settings     |

---

## 6. JVM Sizing Reference

### 6.1 Rules

1. **JVM heap = 50% of container memory request** — standard Elasticsearch best practice
2. **Never exceed 32g** — keep heap within reasonable bounds for performance
3. **Minimum 8g** — the default and minimum recommended heap size
4. **`-Xms` must equal `-Xmx`** — prevents heap resizing at runtime

### 6.2 JVM Sizing Table by Machine Type

| Machine Type    | vCPU | Node RAM | Container Memory (req/limit) | JVM Heap | Remaining for OS/k8s |
|-----------------|------|----------|------------------------------|----------|----------------------|
| `n1-highmem-4`  | 4    | 26 GB    | — (not enough)               | —        | —                    |
| `n1-highmem-8`  | 8    | 52 GB    | `16Gi / 32Gi`                | `8g`     | ~20 GB               |
| **`n1-highmem-16`** | **16** | **104 GB** | **`16Gi / 32Gi`**    | **`8g`** | **~72 GB** ✓ current |
| `n1-highmem-32` | 32   | 208 GB   | `16Gi / 32Gi`                | `8g`–`16g` | large headroom    |
| `n1-highmem-64` | 64   | 416 GB   | `16Gi / 32Gi`                | `8g`–`16g` | large headroom    |

### 6.3 Current Configuration

```
Node: n1-highmem-16
Node RAM: 104 GB
├── Elasticsearch pod:  16Gi request / 32Gi limit  │  JVM: -Xms8g -Xmx8g  │  CPU: 8 req / 12 limit
├── Kibana pod:          4Gi memory limit           │                        │  CPU: 2
├── kube-system:        ~2 GB reserved
└── Available headroom: ~66 GB
```

### 6.4 Changing JVM Heap

**If container memory request stays at `16Gi`:** Use `8g` (default).

**If you change container memory in `eck/04-elasticsearch.yaml`:**

| New Container Memory (request) | New JVM Heap (50%) |
|-------------------------------|---------------------|
| `16Gi`                        | `8g` ← current      |
| `24Gi`                        | `12g`               |
| `32Gi`                        | `16g`               |
| `64Gi`                        | `32g` ← maximum     |
| `>64Gi`                       | **cap at `32g`**    |

To change: update memory in `eck/04-elasticsearch.yaml`, then pass new heap value in the `esJvmHeap` pipeline parameter.

---

## 7. Resource Allocation Per Node

Each `n1-highmem-16` node runs exactly:
- 1 Elasticsearch pod
- 1 Kibana pod
- 1 kube-proxy + node-level system pods

```
┌──────────────────────────────────────────────────────────┐
│  n1-highmem-16  (16 vCPU / 104 GB RAM / 500–1000 GB SSD)│
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Elasticsearch pod                                  │ │
│  │  memory: 16Gi request / 32Gi limit                  │ │
│  │  cpu:    8 request / 12 limit                       │ │
│  │  JVM:    -Xms8g -Xmx8g                             │ │
│  │  PVC:    500Gi pd-ssd (dev) / 1000Gi pd-ssd (prod) │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Kibana pod  (2 replicas across cluster, not per node)│
│  │  memory: 4Gi (request = limit)                      │ │
│  │  cpu:    2 (request)                                │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  Reserved:  20Gi RAM  │  10 CPU  (requests)              │
│  Available: 84Gi RAM  │   6 CPU  (system + headroom)     │
└──────────────────────────────────────────────────────────┘
Replicated across 3 zones (us-east1-b, c, d)
Total cluster: 3 ES pods (16Gi req each) │ 2 Kibana pods (4Gi each)
```

---

## 8. Kubernetes Resource Inventory

### 8.1 Namespaces

| Namespace       | Contents                                           |
|-----------------|----------------------------------------------------|
| `elastic-system`| ECK operator (`elastic-operator` Deployment)       |
| `elastic-stack` | Elasticsearch, Kibana, Beats, Jobs, Secrets        |

### 8.2 Resources in `elastic-stack`

| Resource Kind    | Name                               | Created by          |
|------------------|------------------------------------|---------------------|
| Elasticsearch    | `elasticsearch`                    | Pipeline 04, Stage 2|
| Kibana           | `kibana`                           | Pipeline 04, Stage 2|
| Secret           | `gcs-credentials`                  | Pipeline 04, Stage 2|
| Secret           | `elasticsearch-es-elastic-user`    | ECK operator (auto) |
| Secret           | `elasticsearch-es-http-certs-*`    | ECK operator (auto) |
| ConfigMap        | `elasticsearch-synonyms`           | Pipeline 04, Stage 2|
| PVC (×3)         | `elasticsearch-data-elasticsearch-es-master-{0,1,2}` | ECK operator (auto) |
| Service          | `elasticsearch-es-http`            | ECK operator (LoadBalancer) |
| Service          | `kibana-kb-http`                   | ECK operator (LoadBalancer) |
| Job              | `setup-snapshot-repo`              | Pipeline 04, Stage 3|
| Job              | `setup-index-settings`             | Pipeline 04, Stage 3|

### 8.3 ECK-Generated Secrets (do not delete)

| Secret Name                          | Contents                        |
|--------------------------------------|---------------------------------|
| `elasticsearch-es-elastic-user`      | `elastic` user password (base64)|
| `elasticsearch-es-http-certs-public` | Public TLS cert for ES          |
| `elasticsearch-es-internal-http-certificates` | Internal TLS cert     |
| `kibana-kb-http-certs-public`        | Public TLS cert for Kibana      |

---

## 9. Post-Deployment Verification

### 9.1 Quick Health Check

```bash
# Get kubeconfig
gcloud container clusters get-credentials <clusterName> \
  --region us-east1 --project <project>

# 1. Check nodes
kubectl get nodes
# Expect: 3 nodes, all STATUS=Ready

# 2. Check ECK operator
kubectl get pods -n elastic-system
# Expect: elastic-operator-* Running

# 3. Check ES and Kibana health
kubectl get elasticsearch,kibana -n elastic-stack
# Expect: health=green, phase=Ready

# 4. Check all pods running
kubectl get pods -n elastic-stack
# Expect: 3 ES pods + 2 Kibana pods, all Running
```

### 9.2 Get Access Credentials

```bash
# Get elastic user password
kubectl get secret elasticsearch-es-elastic-user \
  -n elastic-stack \
  -o jsonpath='{.data.elastic}' | base64 -d

# Get Elasticsearch external IP
kubectl get svc elasticsearch-es-http -n elastic-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get Kibana external IP
kubectl get svc kibana-kb-http -n elastic-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 9.3 Access URLs

| Service        | URL                                    | Port  |
|----------------|----------------------------------------|-------|
| Elasticsearch  | `https://<ES_LB_IP>:9200`             | 9200  |
| Kibana         | `https://<KIBANA_LB_IP>:5601`         | 5601  |
| Default user   | `elastic`                              | —     |

> TLS uses self-signed certificates. Use `-k` in curl or accept the cert warning in browser.

### 9.4 Test Elasticsearch

```bash
ES_IP=$(kubectl get svc elasticsearch-es-http -n elastic-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user \
  -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d)

# Cluster health
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_cluster/health?pretty"

# Node list (expect 3 nodes)
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_cat/nodes?v"

# Snapshot repository
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_snapshot/gcs-snapshots?pretty"

# SLM policy
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_slm/policy/daily-snapshots?pretty"
```

---

## 10. Teardown Order

**Always destroy in reverse order. Never destroy foundation while cluster exists.**

```
Step 1: Run 05-eck-destroy.yml        (removes ECK stack from GKE)
Step 2: Run 02-cluster.yml (destroy)  (removes GKE cluster + subnet)
Step 3: Run 01-foundation.yml (destroy) ← ONLY if decommissioning project
```

> **Warning:** Destroying the cluster (Step 2) will delete all Kubernetes PVCs (persistent volume claims) and therefore all Elasticsearch index data. Take a manual snapshot first if data needs to be preserved.

---

## 11. Troubleshooting Reference

### 11.1 Elasticsearch pods not starting

```bash
# Check pod events
kubectl describe pod <es-pod-name> -n elastic-stack

# Check ES logs
kubectl logs <es-pod-name> -n elastic-stack -c elasticsearch | grep -i error
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `IllegalArgumentException: node settings must not contain any index level settings` | `index.*` settings in node config | Remove `index.*` from `eck/04-elasticsearch.yaml` config section |
| `CrashLoopBackOff` with JVM OOM | JVM heap > container memory | Ensure `ES_JVM_HEAP` ≤ 50% of memory limit |
| `vm.max_map_count too low` | sysctl init container failed | Check init container logs: `kubectl logs <pod> -c sysctl` |
| `Pending` scheduling | Insufficient node resources | Check `kubectl describe pod` for resource constraints |

### 11.2 Elasticsearch stuck in ApplyingChanges

```bash
kubectl describe elasticsearch elasticsearch -n elastic-stack
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `health=unknown`, no pods in elastic-stack | `eck-trial-license` secret blocking reconciliation | `kubectl delete secret eck-trial-license -n elastic-system` |
| `Required value: spec.nodeSets` | Partial apply overwriting spec | Use `kubectl patch --type=merge` not `kubectl apply` for partial updates |

### 11.3 Kibana not connecting to Elasticsearch

```bash
kubectl logs <kibana-pod> -n elastic-stack | grep -i error
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Unable to retrieve version information` | ES not yet green | Wait for ES health=green first |
| `elasticsearchRef not found` | Wrong ES cluster name in Kibana spec | Check `elasticsearchRef.name` matches `ES_CLUSTER_NAME` |

### 11.4 Monitoring pipeline: `spec.version: Required value`

Caused by using `kubectl apply` with a partial spec. Always use `kubectl patch --type=merge` when updating only specific spec fields on existing ECK resources.

### 11.5 Pipeline: `gke-gcloud-auth-plugin not found`

The plugin is installed fresh on each ADO agent run. If the install step fails, check:
- Google Cloud SDK APT repo is reachable from agent network
- `sudo` is available on the agent

### 11.6 Snapshot repository fails

```bash
# Check job logs
kubectl logs -l job-name=setup-snapshot-repo -n elastic-stack
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `403 Forbidden` | GCS SA missing `storage.objectAdmin` on bucket | Add IAM binding for terraform SA |
| `bucket not found` | Foundation pipeline not run | Run Pipeline 01 first |
| `client credentials not found` | `gcs-credentials` secret missing | Check Stage 2 "Create GCS Credentials Secret" step succeeded |

---

*Document generated from source: `terraform-gke` repository*
*Pipelines: `02-cluster.yml`, `04-eck-deploy.yml`*
