# GKE Elastic Stack — Deployment Guide

---

## 1. Architecture

```
Azure DevOps Pipelines
        │
        ├── 01-foundation.yml       ← VPC (run once per project)
        ├── 02-cluster.yml          ← GKE cluster + node pool + GCS bucket
        ├── 03-backup.yml           ← GKE backup agent config
        ├── 04-eck-deploy.yml       ← ECK operator + Elasticsearch + Kibana
        ├── 05-eck-destroy.yml      ← Tear down ECK stack
        ├── 06-monitoring-self.yml  ← Self-monitoring (Metricbeat + Filebeat)
        └── 07-monitoring-dedicated.yml ← Dedicated monitoring cluster

GCP Project
  └── VPC
       └── GKE Regional Cluster (us-east1, 3 zones)
            └── 3 × n1-highmem-16 nodes
                 ├── Elasticsearch (3 pods)
                 └── Kibana (2 pods)
```

**Run order:** `01-foundation` → `02-cluster` → `04-eck-deploy`
**Destroy order:** `05-eck-destroy` → `02-cluster (destroy)` → `01-foundation (destroy)`

---

## 2. Environments

| | Dev | Prod |
|---|---|---|
| **GCP Project** | `pg-us-n-app-259723` | `pg-us-e-app-012345` |
| **ADO Variable Group** | `gcp-credentials-pg-us-n-app-259723` | `gcp-credentials-pg-us-e-app-012345` |
| **Region / Zones** | `us-east1` (b, c, d) | `us-east1` (b, c, d) |
| **VPC** | `pg-us-n-app-259723-vpc` | `pg-us-e-app-012345-vpc` |
| **Node Machine** | `n1-highmem-16` (16 vCPU / 104 GB) | `n1-highmem-16` (16 vCPU / 104 GB) |
| **Nodes** | 3 (1 per zone) | 3 (1 per zone) |
| **Disk** | 500 GB `pd-ssd` | 1000 GB `pd-ssd` |

### Elastic Stack Specs

| Component | Spec |
|---|---|
| **ES Version** | `9.3.1` |
| **ES Nodes** | 3 (master + data + ingest + transform) |
| **ES CPU** | 8 request / 12 limit |
| **ES Memory** | 16Gi request / 32Gi limit |
| **ES JVM Heap** | `8g` (default) |
| **ES Storage** | 500Gi `pd-ssd` per pod |
| **Kibana Replicas** | 2 |
| **Kibana CPU / Memory** | 2 / 4Gi |
| **TLS** | Self-signed (ECK-managed) |
| **Endpoints** | LoadBalancer (ES `:9200`, Kibana `:5601`) |

---

## 3. Prerequisites (One-Time)

### 3.1 ADO Variable Group

Create a variable group `gcp-credentials-<project>` in Azure DevOps Library with:

| Variable | Description |
|---|---|
| `GCP_SA_KEY` | Full JSON of the GCP service account key |
| `GCP_PROJECT_ID` | GCP project ID |
| `TF_STATE_BUCKET` | GCS bucket for Terraform remote state |

### 3.2 GCP Service Account Permissions

The Terraform SA needs:

- `roles/container.admin` — GKE clusters
- `roles/compute.networkAdmin` — Subnets
- `roles/storage.admin` — GCS buckets
- `roles/iam.serviceAccountUser` — Node pool SA

### 3.3 Run Pipeline 01 — Foundation (once per project)

Creates the VPC. GCS bucket is managed by the cluster pipeline, so it gets created and deleted along with the cluster.

| Parameter | Value |
|---|---|
| Action | `apply` |
| GCP Project | Select your project |

---

## 4. Pipeline 02 — GKE Cluster

Creates the GKE cluster, node pool, subnet, and GCS snapshot bucket.

**Destroying the cluster also deletes the GCS bucket** — take a snapshot first if you need the data.

### 4.1 Parameters

| Parameter | Example | Required |
|---|---|---|
| `action` | `apply` or `destroy` | Yes |
| `project` | `pg-us-n-app-259723` | Yes |
| `clusterName` | `eck-dev-01` | **Yes** |

### 4.2 How to Run

1. Go to **Azure DevOps → Pipelines → `02-cluster`**
2. Click **Run pipeline**
3. Fill in parameters
4. Review the **Plan** stage output
5. Apply runs automatically on plan success (~10–15 min)

### 4.3 What Gets Created

- **Subnet:** `<clusterName>-subnet-01` with pod/service secondary ranges
- **GKE Cluster:** Regional, VPC-native, Kubernetes `1.30`, 3 zones
- **Node Pool:** `elastic-pool` — 3 × `n1-highmem-16`, `pd-ssd`, auto-upgrade on
- **GCS Bucket:** `<clusterName>-bucket-01` for ES snapshots
- **Maintenance window:** Saturdays

### 4.4 Verify

```bash
gcloud container clusters get-credentials <clusterName> \
  --region us-east1 --project <project>

kubectl get nodes   # Expect: 3 nodes, all Ready
```

---

## 5. Pipeline 04 — ECK Stack

Installs ECK operator, deploys Elasticsearch and Kibana, configures snapshots.

### 5.1 Parameters

| Parameter | Default | Description |
|---|---|---|
| `project` | `pg-us-n-app-259723` | Target GCP project |
| `clusterName` | *(required)* | GKE cluster name (must exist) |
| `esJvmHeap` | `8g` | JVM heap per ES pod (50% of memory request) |

### 5.2 Stages

```
Stage 1: ECK Operator
  → Create namespaces (elastic-system, elastic-stack)
  → Install ECK CRDs + operator
  → Wait for operator ready

Stage 2: ECK Stack
  → Create GCS credentials secret
  → Apply synonyms ConfigMap
  → Deploy Elasticsearch (3 nodes)
  → Deploy Kibana (2 replicas)
  → Wait for ES green (10 min timeout)
  → Wait for Kibana green (5 min timeout)

Stage 3: Configure
  → Setup GCS snapshot repository
  → Create daily SLM policy (01:00 UTC, 7-day retention)
  → Setup default index settings
```

### 5.3 How to Run

1. Confirm Pipeline 02 completed and nodes are Ready
2. Go to **Azure DevOps → Pipelines → `04-eck-deploy`**
3. Fill in parameters and run
4. Total runtime: ~20–35 min (mostly waiting for ES green)

### 5.4 Fixed Pipeline Variables

These live in `pipelines/04-eck-deploy.yml` — edit in source control to change:

| Variable | Value |
|---|---|
| `ES_CLUSTER_NAME` | `elasticsearch` |
| `KIBANA_NAME` | `kibana` |
| `ES_VERSION` | `9.3.1` |
| `ECK_OPERATOR_VERSION` | `9.3.1` |
| `CLUSTER_LOCATION` | `us-east1` |
| `SNAPSHOT_REPO_NAME` | `gcs-snapshots` |
| `SLM_POLICY_NAME` | `daily-snapshots` |

### 5.5 Manifest Files

| File | Purpose |
|---|---|
| `eck/00-namespaces.yaml` | Namespaces |
| `eck/03-synonyms-configmap.yaml` | Search synonyms ConfigMap |
| `eck/04-elasticsearch.yaml` | Elasticsearch CRD |
| `eck/05-kibana.yaml` | Kibana CRD |
| `eck/06-snapshot-repository.yaml` | Snapshot repo + SLM policy (K8s Job) |
| `eck/07-index-settings.yaml` | Default index settings (K8s Job) |

---

## 6. JVM Heap Sizing

**Rules:**
- JVM heap = **50% of container memory request**
- Minimum: **8g** (current default)
- Maximum: **32g**
- `-Xms` must equal `-Xmx`

**Current:** Container memory request is `16Gi` → JVM heap is `8g`

To change: update memory in `eck/04-elasticsearch.yaml`, then pass new heap via `esJvmHeap` parameter.

| Container Memory (request) | JVM Heap |
|---|---|
| `16Gi` | `8g` ← current |
| `24Gi` | `12g` |
| `32Gi` | `16g` |
| `64Gi` | `32g` ← maximum |

---

## 7. Resource Layout Per Node

```
n1-highmem-16  (16 vCPU / 104 GB / pd-ssd)
├── Elasticsearch pod
│   ├── Memory: 16Gi request / 32Gi limit
│   ├── CPU:    8 request / 12 limit
│   ├── JVM:    -Xms8g -Xmx8g
│   └── PVC:    500Gi (dev) / 1000Gi (prod)
├── Kibana pod (2 replicas across cluster)
│   ├── Memory: 4Gi
│   └── CPU:    2
└── System: ~2 GB reserved

× 3 nodes across zones (b, c, d)
```

---

## 8. Post-Deployment Verification

### Quick Health Check

```bash
# Connect to cluster
gcloud container clusters get-credentials <clusterName> \
  --region us-east1 --project <project>

# Check nodes (expect 3 Ready)
kubectl get nodes

# Check ECK operator
kubectl get pods -n elastic-system

# Check ES and Kibana health (expect green / Ready)
kubectl get elasticsearch,kibana -n elastic-stack

# Check all pods (expect 3 ES + 2 Kibana, all Running)
kubectl get pods -n elastic-stack
```

### Get Credentials and Access URLs

```bash
# Elastic password
kubectl get secret elasticsearch-es-elastic-user \
  -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d

# Elasticsearch URL
ES_IP=$(kubectl get svc elasticsearch-es-http -n elastic-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "https://$ES_IP:9200"

# Kibana URL
KB_IP=$(kubectl get svc kibana-kb-http -n elastic-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "https://$KB_IP:5601"
```

> TLS uses self-signed certs. Use `curl -sk` or accept the browser warning.

### Test Elasticsearch

```bash
ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user \
  -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d)

# Cluster health
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_cluster/health?pretty"

# Nodes (expect 3)
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_cat/nodes?v"

# Snapshots
curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_snapshot/gcs-snapshots?pretty"
```

---

## 9. Teardown

**Always destroy in reverse order.**

```
Step 1:  05-eck-destroy.yml         →  removes ECK stack
Step 2:  02-cluster.yml (destroy)   →  removes cluster + subnet + GCS bucket
Step 3:  01-foundation.yml (destroy) → removes VPC (only if decommissioning)
```

> **Warning:** Destroying the cluster deletes all PVCs and ES data. Take a snapshot first if needed.

---

## 10. Troubleshooting

### ES pods not starting

```bash
kubectl describe pod <pod> -n elastic-stack
kubectl logs <pod> -n elastic-stack -c elasticsearch | grep -i error
```

| Symptom | Fix |
|---|---|
| `IllegalArgumentException: index level settings` | Remove `index.*` from ES node config |
| `CrashLoopBackOff` / JVM OOM | `ES_JVM_HEAP` must be ≤ 50% of memory limit |
| `vm.max_map_count too low` | Check sysctl init container: `kubectl logs <pod> -c sysctl` |
| `Pending` | Not enough node resources — check `kubectl describe pod` |

### ES stuck in ApplyingChanges

| Symptom | Fix |
|---|---|
| `health=unknown`, no pods | Delete stale license: `kubectl delete secret eck-trial-license -n elastic-system` |
| `spec.nodeSets: Required value` | Use `kubectl patch --type=json` not `kubectl apply` for partial updates |

### Kibana not connecting

| Symptom | Fix |
|---|---|
| `Unable to retrieve version` | Wait for ES to be green first |
| `elasticsearchRef not found` | Check `elasticsearchRef.name` matches `ES_CLUSTER_NAME` |

### Snapshot repository fails

```bash
kubectl logs -l job-name=setup-snapshot-repo -n elastic-stack
```

| Symptom | Fix |
|---|---|
| `403 Forbidden` | SA missing `storage.objectAdmin` on the bucket |
| `bucket not found` | Cluster pipeline didn't create the bucket — check Pipeline 02 |
| `client credentials not found` | `gcs-credentials` secret missing — check ECK deploy Stage 2 |

### `gke-gcloud-auth-plugin not found`

Plugin is installed fresh each pipeline run. Check that the Google Cloud SDK APT repo is reachable and `sudo` is available on the agent.
