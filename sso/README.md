# Single Sign-On (SSO) for GKE & ECK Clusters

## Overview

This directory contains SSO configuration for 20 team members accessing GKE clusters
and ECK (Elasticsearch/Kibana) using Azure AD (Office 365) as the identity provider.

### Identity Mapping

| System           | Email Domain   | Auth Method                        |
|------------------|----------------|------------------------------------|
| GCP / GKE        | @gcp.pwc.com   | Google Cloud Identity + RBAC       |
| Kibana / ES      | @pwc.com       | Azure AD OIDC (Office 365)         |

### Architecture

```
                    +------------------+
                    |   Azure AD       |
                    | (Office 365)     |
                    | @pwc.com         |
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
     +--------v---------+       +-----------v----------+
     |  GKE Cluster      |       |  Elasticsearch       |
     |  (via Google       |       |  (OIDC Realm)        |
     |   Cloud Identity)  |       |                      |
     +--------+---------+       +-----------+----------+
              |                             |
     +--------v---------+       +-----------v----------+
     | K8s RBAC           |       |  Kibana              |
     | (Namespace-level)  |       |  (OIDC Provider)     |
     +-------------------+       +----------------------+
```

### Deployment Order

1. **01-azure-ad-setup/** - Azure AD App Registration (manual + Terraform)
2. **02-gke-rbac/** - GKE IAM bindings for @gcp.pwc.com users
3. **03-elasticsearch-oidc/** - Elasticsearch OIDC realm configuration
4. **04-kibana-oidc/** - Kibana OIDC provider configuration
5. **05-k8s-rbac/** - Kubernetes RBAC roles and bindings
6. **06-network-policies/** - Network policies for OIDC traffic

### Prerequisites

- Azure AD tenant with admin access to create App Registrations
- GCP project with Cloud Identity configured
- ECK operator deployed with Enterprise license (OIDC requires Platinum+)
- `kubectl` access to the GKE cluster
- `az` CLI for Azure AD configuration

### Team Member Management

Edit `team-members.yaml` to add/remove team members. This file drives:
- GKE IAM bindings (via Terraform)
- Kubernetes RBAC bindings
- Elasticsearch role mappings
