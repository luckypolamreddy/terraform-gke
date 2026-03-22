# Importing Existing GKE Clusters into Terraform

## Overview

This guide walks you through bringing existing GKE clusters under Terraform management without any downtime or changes to the running cluster.

**What happens:** Terraform "learns" about your existing cluster. It does NOT recreate, restart, or modify anything.

## Prerequisites

- `gcloud` CLI authenticated to the project
- `terraform` CLI (v1.5+)
- `jq` installed
- Access to the GCP project containing the cluster
- A GCS bucket for Terraform state

## Quick Start (3 Commands)

```bash
# 1. Dry run — see what will happen (no changes made)
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster my-existing-cluster \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state \
  --dry-run

# 2. Review the generated tfvars file
cat environments/pg-us-n-app-259723/cluster-imported-my-existing-cluster.tfvars

# 3. Run the actual import
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster my-existing-cluster \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state
```

## Step-by-Step Detailed Guide

### Step 1: List Your Existing Clusters

```bash
gcloud container clusters list --project pg-us-n-app-259723
```

Example output:
```
NAME                  LOCATION    STATUS
eck-nonprod-cluster   us-east1    RUNNING
dev-cluster-01        us-east1    RUNNING
```

### Step 2: Dry Run

Run the import script with `--dry-run` to:
- Discover the cluster configuration
- Discover all node pools
- Generate a `.tfvars` file
- Show the import commands that WOULD run (without executing them)

```bash
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster eck-nonprod-cluster \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state \
  --dry-run
```

### Step 3: Review Generated tfvars

The script auto-generates a `.tfvars` file at:
```
environments/pg-us-n-app-259723/cluster-imported-eck-nonprod-cluster.tfvars
```

**Review it carefully.** Check:
- [ ] Kubernetes version matches (minor version, e.g., `1.30`)
- [ ] Node pool machine types are correct
- [ ] Disk sizes and types match
- [ ] Labels and taints are correct
- [ ] Maintenance window is correct
- [ ] Network mode is correct (`default` or `custom`)

### Step 4: Run the Import

```bash
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster eck-nonprod-cluster \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state
```

The script will:
1. `terraform init` with backend pointing to your state bucket
2. `terraform import` the cluster resource
3. `terraform import` each node pool
4. `terraform import` the subnet (custom network mode only)
5. `terraform plan` to check for differences

### Step 5: Fix Any Diffs

If `terraform plan` shows differences, this is normal. Common causes:

| Diff | Fix |
|------|-----|
| `kubernetes_version` shows patch version (e.g., `1.30.5-gke.1234567`) | Change tfvars to just `1.30` (minor only) |
| `maintenance_policy` differs | Copy exact times from plan output |
| `node_config.metadata` has extra entries | Safe to ignore or add to module |
| `addons_config` shows extra addons | Add missing addon toggles to tfvars |
| `deletion_protection` changed | Set to match existing cluster |

Edit the tfvars and re-run plan until you see:
```
No changes. Your infrastructure matches the configuration.
```

### Step 6: Commit the tfvars

Once plan shows zero diff:
```bash
git add environments/pg-us-n-app-259723/cluster-imported-eck-nonprod-cluster.tfvars
git commit -m "Import existing cluster eck-nonprod-cluster into Terraform"
git push
```

### Step 7: Use the Pipeline Going Forward

All future changes go through the `02-cluster.yml` pipeline:
- Use `cluster-imported-eck-nonprod-cluster.tfvars` as the tfvars file
- Pipeline runs Plan -> Apply as usual

## Using the Pipeline (Instead of CLI)

If you prefer to import via Azure DevOps:

1. Run pipeline `12-import-cluster.yml`
2. Select `dry-run` first
3. Download the generated tfvars from pipeline artifacts
4. Review and commit the tfvars
5. Run again with `import`

## Importing Multiple Clusters

Run the script for each cluster:

```bash
# Cluster 1
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster dev-cluster-01 \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state

# Cluster 2
./scripts/import-gke-cluster.sh \
  --project pg-us-n-app-259723 \
  --cluster staging-cluster \
  --region us-east1 \
  --state-bucket pg-us-n-app-259723-tf-state

# Prod cluster (different project)
./scripts/import-gke-cluster.sh \
  --project pg-us-e-app-012345 \
  --cluster prod-cluster \
  --region us-east1 \
  --state-bucket pg-us-e-app-012345-tf-state \
  --network-mode custom \
  --cluster-index 1
```

Each cluster gets:
- Its own `.tfvars` file
- Its own Terraform state prefix (`cluster/<project>/<cluster-name>`)
- Independent lifecycle management

## Custom Network Mode

If your cluster uses a custom VPC (not the default network):

```bash
./scripts/import-gke-cluster.sh \
  --project pg-us-e-app-012345 \
  --cluster prod-cluster \
  --region us-east1 \
  --state-bucket pg-us-e-app-012345-tf-state \
  --network-mode custom \
  --cluster-index 1
```

This also imports the subnet. Make sure the `cluster-index` doesn't conflict with other clusters' CIDR allocations.

## Troubleshooting

### "Cluster not found"
```bash
# Verify the cluster exists and you have access
gcloud container clusters list --project <PROJECT_ID>
```

### "Resource already in state"
This means the cluster was already imported. Safe to ignore — re-run plan to verify.

### "Error acquiring state lock"
Another Terraform process holds the lock. Wait or force unlock:
```bash
terraform force-unlock <LOCK_ID>
```

### Plan shows destroy + recreate
**STOP!** This means the tfvars don't match. Do NOT apply.
1. Compare plan output with actual cluster config
2. Adjust tfvars to match exactly
3. Re-run plan until it shows zero diff

### Node pool order matters
Terraform uses `for_each` on node pools keyed by name. The order in tfvars doesn't matter — only the `name` field is used for matching.
