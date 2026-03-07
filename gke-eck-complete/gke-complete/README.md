# GKE + ECK — Complete Infrastructure Solution

## End-to-End Architecture

```
 TERRAFORM                                          ECK (Kubernetes YAMLs)
 ─────────────────────────────────                  ──────────────────────────────
 ┌─────────────────────────────┐
 │ Foundation Stack (persistent)│
 │  VPC + Firewall Rules       │
 │  GCS Bucket ←───────────────────────── ES Snapshots stored here
 │  Secret Manager ←───────────────────── Kibana creds pushed here
 └──────────────┬──────────────┘
                │
 ┌──────────────▼──────────────┐
 │ Cluster Stack (per cluster) │
 │  Subnet                     │
 │  GKE Cluster                │
 │  ┌────────────────────────┐ │        ┌──────────────────────────┐
 │  │ system-pool (2×)       │──────────│ Kibana ×2, ECK Operator, │
 │  │ e2-standard-4          │ │        │ Jobs (snapshot, sync)    │
 │  │ 4 vCPU, 16GB, no taint│ │        └──────────────────────────┘
 │  ├────────────────────────┤ │        ┌──────────────────────────┐
 │  │ es-master-pool (3×)    │──────────│ ES Master ×3             │
 │  │ e2-standard-2          │ │        │ 4Gi RAM, 2g heap         │
 │  │ 2 vCPU, 8GB           │ │        │ Dedicated coordination   │
 │  │ taint: master          │ │        └──────────────────────────┘
 │  ├────────────────────────┤ │        ┌──────────────────────────┐
 │  │ es-data-pool (3×)      │──────────│ ES Data ×3               │
 │  │ n2-highmem-4           │ │        │ 28Gi RAM, 14g heap       │
 │  │ 4 vCPU, 32GB          │ │        │ 500Gi SSD each           │
 │  │ taint: data            │ │        │ data + ingest roles      │
 │  └────────────────────────┘ │        └──────────────────────────┘
 └─────────────────────────────┘
 ┌─────────────────────────────┐
 │ Backup Stack                │
 │  GKE Backup Plan            │
 └─────────────────────────────┘
```

## Why These Machine Types

| Node Pool | Machine | vCPU | RAM | Why |
|---|---|---|---|---|
| system-pool | e2-standard-4 | 4 | 16GB | Cost-efficient for Kibana (2Gi×2) + operator + jobs. E2 is cheapest. |
| es-master-pool | e2-standard-2 | 2 | 8GB | Masters manage cluster state only. No data, no queries. 2g heap is ample. |
| es-data-pool | n2-highmem-4 | 4 | 32GB | **High memory is #1 ES requirement.** 14g heap (50%) + 14g OS file cache for Lucene reads. N2 gives consistent performance. |

### Why not Autopilot?
Autopilot doesn't support privileged init containers (needed for `vm.max_map_count=262144`) or node taints. Standard mode gives us full control over the node→pod mapping.

### Why taints?
Without taints, the Kubernetes scheduler might put system pods on the expensive highmem nodes, wasting memory. Taints on es-master-pool and es-data-pool ensure ONLY Elasticsearch pods (which have matching tolerations) get scheduled there.

## Resource Summary

| Component | Pods | CPU (req) | RAM (req) | Storage | GKE Pool |
|---|---|---|---|---|---|
| ES Master | 3 | 3 | 12Gi | 60Gi SSD | es-master-pool |
| ES Data | 3 | 6 | 84Gi | 1.5TB SSD | es-data-pool |
| Kibana | 2 | 1 | 4Gi | — | system-pool |
| ECK Operator | 1 | 0.5 | 0.5Gi | — | system-pool |
| **Total** | **9** | **~11** | **~101Gi** | **~1.6TB** | **8 nodes** |

## Deployment Order

```
Step 1:  Terraform → Foundation (VPC, GCS bucket, Secret Manager)
Step 2:  Terraform → Cluster (Subnet, GKE with 3 node pools)
Step 3:  Terraform → Backup (GKE backup plan)
Step 4:  ECK → ./deploy.sh (entire Elastic stack)
```

### Step-by-Step

```bash
# ── 1. Foundation (once per project) ──
# Pipeline: foundation-pipeline.yml → action: apply

# ── 2. GKE Cluster with 3 ECK-ready node pools ──
# Pipeline: cluster-pipeline.yml → action: apply
# This creates: system-pool(2), es-master-pool(3), es-data-pool(3) = 8 nodes

# ── 3. Backup plan ──
# Pipeline: backup-pipeline.yml → action: apply

# ── 4. ECK Stack ──
gcloud container clusters get-credentials proja-cluster-1 --region us-east1

# Create GCS credentials secret
kubectl create namespace elastic-stack
kubectl create secret generic gcs-credentials \
  --from-file=gcs.client.default.credentials_file=/path/to/sa-key.json \
  -n elastic-stack

# Deploy everything
cd eck-stack
chmod +x deploy.sh
./deploy.sh
```

## Before Deploying — Replace These

| Placeholder | Where | Replace With |
|---|---|---|
| `gcp-project-a-id` | terraform tfvars, eck-stack YAMLs | Your GCP project ID |
| `gcp-project-a-id-tf-state` | cluster/backup tfvars | Your state bucket name |
| `proja-elastic-snapshots` | foundation.tfvars, setup-snapshots.yaml | Your GCS bucket name |
| `gke-sa@...` | foundation.tfvars | Your GKE service account |
| `REPLACE_WITH_openssl_rand_hex_32_*` | kibana.yaml (3 places) | `openssl rand -hex 32` |
| `REPLACE_WITH_BASE64...` | gcs-credentials.yaml (or use kubectl) | SA key base64 |

## File Structure

```
gke-complete/
├── terraform/
│   ├── modules/           ← Generic (never edit)
│   │   ├── vpc/
│   │   ├── subnet/
│   │   ├── gke-cluster/
│   │   ├── gke-backup-plan/
│   │   ├── gcs-bucket/
│   │   └── secret-manager/
│   ├── stacks/            ← Root configs
│   │   ├── foundation/
│   │   ├── cluster/
│   │   └── backup/
│   ├── environments/      ← EDIT THESE .tfvars
│   │   ├── project-a/
│   │   │   ├── foundation.tfvars      ← VPC, GCS bucket, secrets
│   │   │   ├── cluster-1.tfvars       ← 3 node pools for ECK
│   │   │   └── backup-cluster-1.tfvars
│   │   └── project-b/
│   └── pipelines/         ← Azure DevOps YAML
│       ├── templates/
│       ├── foundation-pipeline.yml
│       ├── cluster-pipeline.yml
│       └── backup-pipeline.yml
│
└── eck-stack/
    ├── deploy.sh                              ← Run this
    ├── 00-namespace.yaml
    ├── 01-operator/
    │   ├── install-operator.sh
    │   └── enterprise-trial-license.yaml
    ├── 02-secrets/
    │   └── gcs-credentials.yaml
    ├── 03-configmaps/
    │   └── synonyms.yaml
    ├── 04-elasticsearch/
    │   └── elasticsearch.yaml                 ← Master×3 + Data×3
    ├── 05-kibana/
    │   └── kibana.yaml                        ← ×2 HA behind LB
    ├── 06-security/
    │   ├── rbac.yaml
    │   ├── network-policies.yaml
    │   └── pod-disruption-budgets.yaml
    ├── 07-snapshot/
    │   └── setup-snapshots.yaml               ← GCS repo + daily SLM
    ├── 08-creds-sync/
    │   └── sync-to-secret-manager.yaml        ← Kibana creds → GCP SM
    └── 09-index-settings/
        └── setup-index-defaults.yaml          ← Slow logs + synonyms
```

## Accessing Kibana Without Cluster Access

```bash
gcloud secrets versions access latest \
  --secret=elastic-stack-kibana-credentials \
  --project=gcp-project-a-id
# Returns: {"username":"elastic","password":"...","kibana_url":"https://..."}
```

## Snapshot & Restore

```bash
# Get credentials
ES_PASS=$(kubectl -n elastic-stack get secret elasticsearch-es-elastic-user \
  -o jsonpath='{.data.elastic}' | base64 -d)
ES_URL="https://$(kubectl -n elastic-stack get svc elasticsearch-es-http \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):9200"

# List snapshots
curl -sk -u "elastic:${ES_PASS}" "${ES_URL}/_snapshot/gcs-snapshots/_all?pretty"

# Manual snapshot
curl -sk -u "elastic:${ES_PASS}" -X PUT \
  "${ES_URL}/_snapshot/gcs-snapshots/manual-$(date +%Y%m%d)?wait_for_completion=true"

# Restore
curl -sk -u "elastic:${ES_PASS}" -X POST \
  "${ES_URL}/_snapshot/gcs-snapshots/<snapshot-name>/_restore" \
  -H "Content-Type: application/json" \
  -d '{"indices": "my-index-*", "ignore_unavailable": true}'
```

## Slow Logs

| Type | Warn | Info | Debug | Trace |
|---|---|---|---|---|
| Search Query | 5s | 2s | 500ms | 200ms |
| Search Fetch | 1s | 500ms | 200ms | 100ms |
| Indexing | 10s | 5s | 2s | 500ms |

Override per-index:
```bash
curl -sk -u "elastic:${ES_PASS}" -X PUT "${ES_URL}/my-index/_settings" \
  -H "Content-Type: application/json" -d '{"index.search.slowlog.threshold.query.warn":"1s"}'
```

## Synonyms

Pre-built analyzers available in all indices:
- `text_with_synonyms` — index-time synonym expansion
- `search_with_synonyms` — search-time graph-aware (handles multi-word)

Update synonyms without restart:
```bash
# 1. Edit ConfigMap
kubectl -n elastic-stack edit configmap elasticsearch-synonyms
# 2. Wait ~90s for volume propagation
# 3. Reload
curl -sk -u "elastic:${ES_PASS}" -X POST "${ES_URL}/my-index/_reload_search_analyzers"
```

## Scaling

| Want to... | Action |
|---|---|
| Add data nodes | Terraform: increase es-data-pool `node_count`. ECK: increase data `count`. |
| Bigger data nodes | Terraform: change to `n2-highmem-8`. ECK: adjust resources + heap. |
| Add warm tier | Terraform: add es-warm-pool with `pd-balanced`. ECK: add warm nodeset. |
| More Kibana | ECK: increase Kibana `count` (system-pool has capacity). |
