###############################################################################
# Stack Monitoring — Choose Your Option
#
# Both options deploy the SAME monitoring components:
#   ✅ Stack Monitoring (Kibana UI: cluster health, node stats, shards, JVM)
#   ✅ Metricbeat (system + ES + Kibana detailed metrics + dashboards)
#   ✅ Filebeat (all logs + ES slow logs + audit logs + deprecation logs)
#
# The difference is WHERE the monitoring data is stored.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │             OPTION A — Self-Monitoring                                  │
# │                                                                         │
# │  Main ES Cluster ──── metrics/logs ────→ Main ES Cluster (itself)      │
# │  Kibana ──────────── Stack Monitoring ──→ reads from same cluster      │
# │                                                                         │
# │  PROS:  Simple, no extra resources, single Kibana for everything       │
# │  CONS:  If cluster is stressed, monitoring degrades too                │
# │         Monitoring indices consume main cluster resources              │
# │                                                                         │
# │  BEST FOR: Dev, staging, single-cluster setups, cost-sensitive         │
# │                                                                         │
# │  DEPLOY:  ./deploy-option-a.sh                                        │
# │  EXTRA RESOURCES: ~500Mi RAM, 200m CPU (Metricbeat + Filebeat)        │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │             OPTION B — Dedicated Monitoring Cluster                     │
# │                                                                         │
# │  Main ES Cluster ──── metrics/logs ────→ es-monitor (separate cluster) │
# │  Main Kibana (app data)                  kibana-monitor (ops data)     │
# │                                                                         │
# │  PROS:  Monitoring survives main cluster failures                      │
# │         No resource contention on main cluster                         │
# │         Separation of concerns (app team vs ops team)                  │
# │  CONS:  Extra cost (~5Gi RAM, 2.5 CPU, 100Gi storage)                │
# │         Two Kibana endpoints to manage                                 │
# │                                                                         │
# │  BEST FOR: Production, multi-team, compliance requirements             │
# │                                                                         │
# │  DEPLOY:  ./deploy-option-b.sh                                        │
# │  EXTRA RESOURCES:                                                      │
# │    es-monitor:      2 pods × (2Gi RAM, 0.5 CPU, 50Gi SSD)            │
# │    kibana-monitor:  1 pod × (1Gi RAM, 0.5 CPU)                        │
# │    Metricbeat:      DaemonSet (~300Mi RAM per node)                    │
# │    Filebeat:        DaemonSet (~200Mi RAM per node)                    │
# │    All on system-pool (no extra GKE nodes needed if pool has room)     │
# └─────────────────────────────────────────────────────────────────────────┘
#
# ⚠ IMPORTANT:
#   - Deploy ONLY ONE option. Do NOT apply both.
#   - Run AFTER the main deploy.sh has completed and cluster is green.
#   - Both Metricbeat and Filebeat DaemonSets have tolerations for ES node
#     pool taints, so they run on ALL GKE nodes to collect metrics everywhere.
#
# WHAT YOU SEE IN KIBANA AFTER DEPLOYING:
#
#   Stack Monitoring (Kibana sidebar):
#     ├── Cluster Overview (health, docs, storage, shard count)
#     ├── Nodes (JVM heap %, CPU, disk, search rate per node)
#     ├── Indices (doc count, store size, search/index rates)
#     └── Kibana instances (requests, response times)
#
#   Discover (filter by log_type field):
#     ├── es-slowlog-search   — Slow search queries
#     ├── es-slowlog-index    — Slow indexing operations
#     ├── es-audit            — Security audit events
#     ├── es-deprecation      — Deprecated API usage warnings
#     └── kibana              — Kibana application logs
#
#   Dashboards (auto-loaded by Metricbeat/Filebeat):
#     ├── [Metricbeat System] Host Overview ECS
#     ├── [Metricbeat System] Containers Overview ECS
#     ├── [Filebeat System] Syslog Dashboard ECS
#     └── ... (many more pre-built dashboards)
#
###############################################################################
