# GKE Elastic Stack — Deployment & Execution Plan

---

## 1. Architecture

```
Azure DevOps Pipelines
        │
        ├── 01-foundation.yml       ← VPC (prod only, skip for dev)
        ├── 02-cluster.yml          ← GKE cluster + node pool (+ subnet in custom mode)
        ├── 03-backup.yml           ← GKE backup plan (pause / destroy lifecycle)
        ├── 04-eck-deploy.yml       ← ECK operator + Elasticsearch + Kibana
        ├── 05-eck-destroy.yml      ← Tear down ECK stack
        ├── 06-monitoring-self.yml  ← Self-monitoring (Metricbeat + Filebeat)
        └── 07-monitoring-dedicated.yml ← Dedicated monitoring cluster

Dev (default VPC mode):
  GCP Project
    └── default VPC (pre-existing)
         └── default subnet (auto-allocated CIDRs)
              └── GKE Regional Cluster (us-east1, 3 zones)
                   ├── Elasticsearch (3 pods)
                   └── Kibana (2 pods)

Prod (custom VPC mode):
  GCP Project
    └── Custom VPC (via 01-foundation)
         └── <cluster>-subnet-01 (CIDRs from cluster_index)
              └── GKE Regional Cluster (us-east1, 3 zones)
                   ├── Elasticsearch (3 pods)
                   └── Kibana (2 pods)
```

---

## 2. Execution Order

### Deploy — Dev (default VPC, no foundation needed)

| Step | Pipeline | Action | What it does |
|------|----------|--------|-------------|
| 1 | `02-cluster.yml` | `apply` | Creates GKE cluster in default VPC (no CIDR config needed) |
| 2 | `04-eck-deploy.yml` | run | Deploys ECK operator, ES, Kibana, snapshots, SLM |
| 3 | `03-backup.yml` | `apply` | Creates GKE backup plan (daily backups) |
| 4 | `06-monitoring-self.yml` | `deploy` | Enables self-monitoring (optional) |

### Deploy — Prod (custom VPC, unique CIDRs per cluster)

| Step | Pipeline | Action | What it does |
|------|----------|--------|-------------|
| 1 | `01-foundation.yml` | `apply` | Creates custom VPC (one-time per project) |
| 2 | `02-cluster.yml` | `apply` | Creates GKE cluster + dedicated subnet (pass `clusterIndex`) |
| 3 | `04-eck-deploy.yml` | run | Deploys ECK operator, ES, Kibana, snapshots, SLM |
| 4 | `03-backup.yml` | `apply` | Creates GKE backup plan (daily backups) |
| 5 | `06-monitoring-self.yml` | `deploy` | Enables self-monitoring |

> **Multi-cluster prod:** Each cluster needs a unique `clusterIndex` (1, 2, 3...) to get non-overlapping CIDRs. Dev clusters use default VPC and don't need this.

### Teardown (decommission)

| Step | Pipeline | Action | What it does |
|------|----------|--------|-------------|
| 1 | `03-backup.yml` | `pause` | Pauses backup schedule (keeps backups 7 days) |
| 2 | `05-eck-destroy.yml` | run | Removes ECK stack from GKE |
| 3 | `02-cluster.yml` | `destroy` | Removes cluster (+ subnet in custom mode) |
| 4 | *(wait 7 days)* | — | Backup retention auto-expires old backups |
| 5 | `03-backup.yml` | `destroy` | Cleans up empty backup plan |
| 6 | `01-foundation.yml` | `destroy` | Removes custom VPC (prod only, skip for dev) |

> **Warning:** Destroying the cluster (step 3) deletes all PVCs and ES data. The GKE backups from step 1 remain available for 7 days for restore if needed.

---

## 3. Detailed Execution Plan (Step-by-Step)

This section provides the exact steps an operator should follow for a fresh deployment.

### Phase 1: Infrastructure Setup

```
STEP 1 — Create VPC (PROD ONLY — skip for Dev)
─────────────────────────────────────────────────
Pipeline:    01-foundation.yml
Parameters:  action=apply, project=pg-us-e-app-012345
Run once:    Yes (one-time per GCP project)
Wait for:    Pipeline completes (~3 min)
Verify:      VPC exists in GCP Console → VPC Network
NOTE:        Dev uses "default" VPC — skip this step entirely.
```

```
STEP 2 — Create GKE Cluster
─────────────────────────────────────────────────
Pipeline:    02-cluster.yml

Dev example:
  Parameters:  action=apply, project=pg-us-n-app-259723, clusterName=eck-dev-01
  Network:     Uses default VPC (clusterIndex ignored)

Prod example (first cluster):
  Parameters:  action=apply, project=pg-us-e-app-012345, clusterName=eck-prod-01, clusterIndex=1
  Network:     Creates subnet eck-prod-01-subnet-01 with CIDRs 10.1.0.0/20

Prod example (second cluster):
  Parameters:  action=apply, project=pg-us-e-app-012345, clusterName=eck-prod-02, clusterIndex=2
  Network:     Creates subnet eck-prod-02-subnet-01 with CIDRs 10.2.0.0/20

Wait for:    Pipeline completes (~15 min)
Verify:      gcloud container clusters list --project=<project>
             kubectl get nodes  (expect 3 Ready)
```

### Phase 2: Elastic Stack Deployment

```
STEP 3 — Deploy ECK + Elasticsearch + Kibana
─────────────────────────────────────────────────
Pipeline:    04-eck-deploy.yml
Parameters:  project=pg-us-n-app-259723, clusterName=<name>, jvmMemory=8g
Wait for:    Pipeline completes (~20 min)

Internal execution order (eck-deployment-steps.yaml):
  3a. Install gke-gcloud-auth-plugin → authenticate to GKE
  3b. Replace tokens in 04-elasticsearch.yaml and 05-kibana.yaml via sed
  3c. Install ECK CRDs + operator  → wait for operator pod ready
  3d. Create elastic-stack namespace
  3e. Upload synonyms ConfigMap
  3f. Create GCS credentials secret from service account key
  3g. Apply GCS credentials manifest
  3h. Deploy Elasticsearch (3 nodes) → wait for pods + green/yellow health
  3i. Deploy Kibana (2 replicas) → wait for pods + green health
  3j. Apply enterprise trial license
  3k. Apply default index settings (slow logs, replicas, refresh interval)
  3l. Register GCS snapshot repository via kubectl exec + ES API
  3m. Create SLM policy (daily-gcs-snapshots, 2 AM UTC)
  3n. Trigger immediate snapshot to validate
  3o. Show deployment summary (ES/Kibana health, service IPs)

Verify:
  kubectl get elasticsearch,kibana -n elastic-stack  (expect green)
  kubectl get pods -n elastic-stack                   (expect 3 ES + 2 Kibana)
  kubectl get svc -n elastic-stack                    (expect LoadBalancer IPs)
```

### Phase 3: Backup & Monitoring

```
STEP 4 — Enable GKE Backup
─────────────────────────────────────────────────
Pipeline:    03-backup.yml
Parameters:  action=apply, project=pg-us-n-app-259723, clusterName=<name>
Wait for:    Pipeline completes (~5 min)
Creates:     Backup plan with daily schedule, 7-day retention
Backs up:    elastic-system + elastic-stack namespaces (PVCs + secrets)
Verify:      gcloud beta container backup-restore backup-plans list \
               --project=<project> --location=us-east1
```

```
STEP 5 — Enable Self-Monitoring (Optional)
─────────────────────────────────────────────────
Pipeline:    06-monitoring-self.yml
Parameters:  project=pg-us-n-app-259723, clusterName=<name>
Wait for:    Pipeline completes (~5 min)
```

### Phase 4: Post-Deployment Validation

```
STEP 6 — Validate Everything
─────────────────────────────────────────────────
Run these commands manually:

  # Connect
  gcloud container clusters get-credentials <clusterName> \
    --region us-east1 --project <project>

  # Cluster health
  kubectl get elasticsearch,kibana -n elastic-stack

  # All pods running
  kubectl get pods -n elastic-stack -o wide

  # Get elastic password
  ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user \
    -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d)

  # Get ES LoadBalancer IP
  ES_IP=$(kubectl get svc elasticsearch-es-http -n elastic-stack \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

  # Test ES cluster health
  curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_cluster/health?pretty"

  # Verify index template was applied
  curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_index_template/default-settings?pretty"

  # Verify snapshot repository
  curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_snapshot/my_gcs_repository?pretty"

  # Verify SLM policy
  curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_slm/policy/daily-gcs-snapshots?pretty"

  # Verify snapshot was taken
  curl -sk -u "elastic:$ES_PASS" "https://$ES_IP:9200/_snapshot/my_gcs_repository/_all?pretty"

  # Get Kibana URL
  KIBANA_IP=$(kubectl get svc kibana-kb-http -n elastic-stack \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "Kibana: https://$KIBANA_IP:5601"
```

### Teardown Execution Plan

```
STEP T1 — Pause Backups (keep 7-day safety net)
─────────────────────────────────────────────────
Pipeline:    03-backup.yml
Parameters:  action=pause, project=<project>, clusterName=<name>

STEP T2 — Destroy ECK Stack
─────────────────────────────────────────────────
Pipeline:    05-eck-destroy.yml
Parameters:  project=<project>, clusterName=<name>, removeOperator=true
Stages:      RemoveMonitoring → RemoveStack → RemoveOperator

STEP T3 — Destroy GKE Cluster
─────────────────────────────────────────────────
Pipeline:    02-cluster.yml
Parameters:  action=destroy, project=<project>, clusterName=<name>
WARNING:     Deletes ALL data, PVCs, and GCS bucket!

STEP T4 — (Wait 7 days for backup retention to expire)

STEP T5 — Destroy Backup Plan
─────────────────────────────────────────────────
Pipeline:    03-backup.yml
Parameters:  action=destroy, project=<project>, clusterName=<name>

STEP T6 — Destroy VPC (only if decommissioning entire project)
─────────────────────────────────────────────────
Pipeline:    01-foundation.yml
Parameters:  action=destroy, project=<project>
```

---

## 4. Environments

| | Dev | Prod |
|---|---|---|
| **GCP Project** | `pg-us-n-app-259723` | `pg-us-e-app-012345` |
| **ADO Variable Group** | `gcp-credentials-pg-us-n-app-259723` | `gcp-credentials-pg-us-e-app-012345` |
| **Region / Zones** | `us-east1` (b, c, d) | `us-east1` (b, c, d) |
| **Network Mode** | `default` (GCP default VPC) | `custom` (dedicated VPC + auto-CIDRs) |
| **VPC** | `default` | `pg-us-e-app-012345-vpc` |
| **Subnet CIDRs** | Auto-allocated by GKE | Auto-calculated from `cluster_index` |
| **Nodes** | 3 × `n1-highmem-16` (16 vCPU / 104 GB) | 3 × `n1-highmem-16` |
| **Disk** | 500 GB `pd-ssd` | 1000 GB `pd-ssd` |

### Networking Modes

**Default mode (Dev):** Uses GCP's pre-existing `default` VPC and `default` subnet. GKE auto-allocates pod and service CIDRs. No foundation pipeline needed. You can create unlimited clusters without CIDR conflicts.

**Custom mode (Prod):** Creates a dedicated subnet per cluster inside a custom VPC. CIDRs are auto-calculated from `cluster_index`:

```
cluster_index=1  →  subnet: 10.1.0.0/20,  pods: 10.1.16.0/20,  services: 10.1.32.0/20
cluster_index=2  →  subnet: 10.2.0.0/20,  pods: 10.2.16.0/20,  services: 10.2.32.0/20
cluster_index=3  →  subnet: 10.3.0.0/20,  pods: 10.3.16.0/20,  services: 10.3.32.0/20
...up to 250
```

Each cluster gets 4096 IPs per range. No manual CIDR management needed — just increment the index.

---

## 5. Prerequisites (One-Time)

### ADO Variable Group

Create `gcp-credentials-<project>` in Azure DevOps Library:

| Variable | Description |
|---|---|
| `GCP_SA_KEY` | Full JSON of the GCP service account key |
| `GCP_PROJECT_ID` | GCP project ID |
| `TF_STATE_BUCKET` | GCS bucket for Terraform remote state |

### GCP Service Account Permissions

- `roles/container.admin` — GKE clusters
- `roles/compute.networkAdmin` — Subnets
- `roles/storage.admin` — GCS buckets
- `roles/iam.serviceAccountUser` — Node pool SA

---

## 6. Pipeline 01 — Foundation (VPC)

Creates a custom VPC. **Prod only** — Dev uses the GCP default VPC and skips this pipeline entirely.

| Parameter | Value |
|---|---|
| `action` | `apply` or `destroy` |
| `project` | Select your project |

> **Dev note:** When `network_mode = "default"` (in dev tfvars), no VPC or subnet is created. The cluster uses GCP's pre-existing `default` network. You can spin up multiple dev clusters without any CIDR conflicts.

---

## 7. Pipeline 02 — GKE Cluster

Creates the GKE cluster, node pool, and (in custom mode) a dedicated subnet.

| Parameter | Example | Required |
|---|---|---|
| `action` | `apply` / `destroy` | Yes |
| `project` | `pg-us-n-app-259723` | Yes |
| `clusterName` | `eck-dev-01` | **Yes** |
| `clusterIndex` | `1` (default), `2`, `3`... | Prod only |

**Dev (default mode):** Uses GCP default VPC. No subnet created. No CIDR conflicts. `clusterIndex` is ignored.

**Prod (custom mode):** Creates subnet `<clusterName>-subnet-01` with auto-calculated CIDRs from `clusterIndex`. Each cluster must have a unique index.

```
# Example: Creating 3 prod clusters
Cluster 1: clusterName=eck-prod-01, clusterIndex=1  →  10.1.0.0/20
Cluster 2: clusterName=eck-prod-02, clusterIndex=2  →  10.2.0.0/20
Cluster 3: clusterName=eck-prod-03, clusterIndex=3  →  10.3.0.0/20
```

**What gets created:**
- Subnet: `<clusterName>-subnet-01` (custom mode only)
- GKE cluster: Regional, 3 zones, Kubernetes 1.30
- Node pool: `elastic-pool` — 3 × `n1-highmem-16`, `pd-ssd`
- GCS bucket: `<clusterName>-bucket-01` (for ES snapshots)

**Destroying the cluster also deletes the GCS bucket.**

---

## 8. Pipeline 04 — ECK Deploy

Deploys the full Elastic stack in a **single stage** using a reusable template (`eck-deployment-steps.yaml`).

### How It Works

1. Installs `gke-gcloud-auth-plugin` and authenticates to GKE
2. Replaces tokens in manifest files using `sed` (e.g., `_ES_NAME_` → `elasticsearch`)
3. Installs ECK CRDs and operator
4. Creates namespaces, synonyms ConfigMap, GCS credentials secret
5. Deploys Elasticsearch → waits for green/yellow health
6. Deploys Kibana → waits for green health
7. Applies enterprise trial license
8. Registers GCS snapshot repository via `kubectl exec` + ES API
9. Creates SLM policy (daily at 2 AM UTC) + triggers immediate snapshot
10. Shows deployment summary

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `project` | `pg-us-n-app-259723` | Target GCP project |
| `clusterName` | *(required)* | GKE cluster name |
| `jvmMemory` | `8g` | JVM heap per ES pod |

### Elasticsearch Spec (pipeline variables)

| Setting | Variable | Default |
|---|---|---|
| Nodes | `elasticsearchNoOfNodes` | `3` |
| CPU request / limit | `elasticsearchCpu` / `elasticsearchCpuLimit` | `8` / `12` |
| Memory request / limit | `elasticsearchMemory` / `elasticsearchMemoryLimit` | `16Gi` / `32Gi` |
| Storage | `elasticsearchStorage` | `500Ti` |
| JVM Heap | `jvmMemory` parameter | `8g` |
| Roles | — | master, data, data_content, data_hot, ingest, transform |

### Kibana Spec (pipeline variables)

| Setting | Variable | Default |
|---|---|---|
| Replicas | `kibanaNoOfNodes` | `2` |
| CPU request / limit | `kibanaCpu` / `kibanaCpuLimit` | `2` / `4` |
| Memory request / limit | `kibanaMemory` / `kibanaMemoryLimit` | `4Gi` / `8Gi` |

### Snapshot Configuration

| Setting | Value |
|---|---|
| Repository name | `my_gcs_repository` |
| GCS bucket | `<clusterName>-bucket-01` |
| SLM policy | `daily-gcs-snapshots` |
| Schedule | `0 0 2 * * ?` (2 AM UTC / 10 PM EST) |
| Retention | 30 days, min 5, max 30 snapshots |

### Token Replacement

The template uses `sed` to replace tokens in manifest files before applying:

| Token | Replaced With | Example |
|---|---|---|
| `_ES_NAME_` | `$(elasticsearchName)` | `elasticsearch` |
| `_NAMESPACE_` | `$(eckNamespace)` | `elastic-stack` |
| `_ES_OPERATOR_VERSION_` | `$(elasticsearchOperatorVersion)` | `9.3.1` |
| `_ES_NODES_` | `$(elasticsearchNoOfNodes)` | `3` |
| `_ES_MEMORY_` | `$(elasticsearchMemory)` | `16Gi` |
| `_ES_CPU_` | `$(elasticsearchCpu)` | `8` |
| `_ES_MEMORY_LIMIT_` | `$(elasticsearchMemoryLimit)` | `32Gi` |
| `_ES_CPU_LIMIT_` | `$(elasticsearchCpuLimit)` | `12` |
| `_ES_HEAP_` | `${{ parameters.jvmMemory }}` | `8g` |
| `_KIBANA_NAME_` | `$(kibanaName)` | `kibana` |
| `_KIBANA_NODES_` | `$(kibanaNoOfNodes)` | `2` |
| `_KIBANA_MEMORY_` | `$(kibanaMemory)` | `4Gi` |
| `_KIBANA_CPU_` | `$(kibanaCpu)` | `2` |

### Index Settings (07-index-settings.yaml)

A Kubernetes Job that runs after ES is healthy. It configures default index templates via the ES REST API using `curl` from inside the cluster.

**What it configures:**

| Setting | Value | Purpose |
|---|---|---|
| `index.search.slowlog.threshold.query.warn` | `10s` | Slow query log |
| `index.search.slowlog.threshold.query.info` | `5s` | Slow query log |
| `index.search.slowlog.threshold.query.debug` | `2s` | Slow query log |
| `index.search.slowlog.threshold.fetch.warn` | `1s` | Slow fetch log |
| `index.search.slowlog.threshold.fetch.info` | `800ms` | Slow fetch log |
| `index.indexing.slowlog.threshold.index.warn` | `10s` | Slow indexing log |
| `index.indexing.slowlog.threshold.index.info` | `5s` | Slow indexing log |
| `index.number_of_replicas` | `1` | Data redundancy |
| `index.refresh_interval` | `5s` | Search visibility delay |

**How it authenticates:** Mounts the `elasticsearch-es-elastic-user` secret as a volume at `/mnt/elastic-internal/users` and reads the password from that file. No `envsubst` or token replacement needed — all values are hardcoded.

**Index template:** `default-settings` with pattern `["*"]` and priority `0` (lowest, so app-specific templates override it).

### Manifest Files

| File | Purpose |
|---|---|
| `eck/00-namespace.yaml` | Namespaces |
| `eck/01-enterprise-license.yaml` | Enterprise trial license |
| `eck/02-gcs-credentials.yaml` | GCS credentials secret |
| `eck/04-elasticsearch.yaml` | Elasticsearch CRD (token-based) |
| `eck/05-kibana.yaml` | Kibana CRD (token-based) |
| `eck/07-index-settings.yaml` | Default index settings (hardcoded, no token replacement) |
| `eck/synonyms/` | Synonym files directory |

---

## 9. Pipeline 03 — GKE Backup

Manages GKE backup plans with a safe teardown workflow.

### Actions

| Action | What happens |
|---|---|
| `apply` | Creates backup plan (daily schedule active) |
| `pause` | Pauses schedule — existing backups kept for 7-day retention |
| `destroy` | Deletes all backups (waits for completion), then removes plan |

### Parameters

| Parameter | Example | Required |
|---|---|---|
| `action` | `apply` / `pause` / `destroy` | Yes |
| `project` | `pg-us-n-app-259723` | Yes |
| `clusterName` | `eck-dev-01` | **Yes** |

### Backup Configuration

| Setting | Value |
|---|---|
| Backup plan name | `<clusterName>-backup-01` |
| Schedule | Daily (1440 min RPO) |
| Retention | 7 days |
| Namespaces backed up | `elastic-system`, `elastic-stack` |
| Volume data | Included |
| Secrets | Included |

### Safe Teardown Workflow

When decommissioning a cluster, you want backups available for restore in case a team needs them:

```
1. Run 03-backup with action=pause
   → Schedule stops, existing backups remain available

2. Destroy the cluster (02-cluster destroy)
   → Cluster gone, but backups still exist in GKE Backup

3. If a team requests restore within 7 days:
   → Create a new cluster, restore from backup

4. After 7 days (retention auto-expires backups):
   → Run 03-backup with action=destroy
   → Cleans up the empty backup plan
```

For **immediate teardown** (no retention needed): just run `action=destroy` directly.

---

## 10. JVM Heap Sizing

| Rule | Value |
|---|---|
| JVM heap | 50% of container memory request |
| Minimum | `8g` (current default) |
| Maximum | `32g` |
| `-Xms` must equal `-Xmx` | Prevents heap resizing |

| Container Memory (request) | JVM Heap |
|---|---|
| `16Gi` | `8g` ← current |
| `24Gi` | `12g` |
| `32Gi` | `16g` |
| `64Gi` | `32g` ← maximum |

---

## 11. Resource Layout Per Node

```
n1-highmem-16  (16 vCPU / 104 GB / pd-ssd)
├── Elasticsearch pod
│   ├── Memory: 16Gi request / 32Gi limit
│   ├── CPU:    8 request / 12 limit
│   ├── JVM:    -Xms8g -Xmx8g
│   └── PVC:    500Gi (dev) / 1000Gi (prod)
├── Kibana pod (2 replicas across cluster)
│   ├── Memory: 4Gi request / 8Gi limit
│   └── CPU:    2 request / 4 limit
└── System: ~2 GB reserved

× 3 nodes across zones (b, c, d)
```

---

## 12. Post-Deployment Verification

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

# Get elastic password
kubectl get secret elasticsearch-es-elastic-user \
  -n elastic-stack -o jsonpath='{.data.elastic}' | base64 -d

# Get service URLs
kubectl get svc -n elastic-stack
```

> TLS uses self-signed certs. Use `curl -sk` or accept the browser warning.

---

## 13. Troubleshooting

### ES pods not starting

```bash
kubectl describe pod <pod> -n elastic-stack
kubectl logs <pod> -n elastic-stack -c elasticsearch | grep -i error
```

| Symptom | Fix |
|---|---|
| `IllegalArgumentException: index level settings` | Remove `index.*` from ES node config |
| `CrashLoopBackOff` / JVM OOM | `jvmMemory` must be ≤ 50% of memory limit |
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
| `elasticsearchRef not found` | Check `elasticsearchRef.name` matches ES cluster name |

### Snapshot repository fails

| Symptom | Fix |
|---|---|
| `403 Forbidden` | SA missing `storage.objectAdmin` on the bucket |
| `bucket not found` | Cluster pipeline didn't create the bucket — check Pipeline 02 |

### GKE Backup destroy: "nested resources"

| Symptom | Fix |
|---|---|
| `has nested resources` error | Run `action=pause` first, wait for backup retention to expire, then `action=destroy` |

### `gke-gcloud-auth-plugin not found`

Plugin is installed fresh each pipeline run. Check that the Google Cloud SDK APT repo is reachable and `sudo` is available on the agent.
