# DevSecOps — Complete Guide

## Azure AKS | Terraform | Azure DevOps Pipelines

---

# Table of Contents

1. [What is DevSecOps?](#1-what-is-devsecops)
2. [Why DevSecOps?](#2-why-devsecops)
3. [DevSecOps vs DevOps vs Traditional Security](#3-devsecops-vs-devops-vs-traditional-security)
4. [Core Principles](#4-core-principles)
5. [DevSecOps Lifecycle](#5-devsecops-lifecycle)
6. [DevSecOps Toolchain](#6-devsecops-toolchain)
7. [Implementation Roadmap](#7-implementation-roadmap)
8. [Azure DevOps Pipelines — Security Integration](#8-azure-devops-pipelines--security-integration)
9. [Terraform — Infrastructure Security](#9-terraform--infrastructure-security)
10. [Azure AKS — Kubernetes Security](#10-azure-aks--kubernetes-security)
11. [Container Security](#11-container-security)
12. [Secret Management](#12-secret-management)
13. [Compliance as Code](#13-compliance-as-code)
14. [Monitoring, Logging & Incident Response](#14-monitoring-logging--incident-response)
15. [RBAC & Identity](#15-rbac--identity)
16. [Sample Pipeline Architecture](#16-sample-pipeline-architecture)
17. [Security Gates & Quality Gates](#17-security-gates--quality-gates)
18. [Maturity Model](#18-maturity-model)
19. [Common Mistakes & Anti-Patterns](#19-common-mistakes--anti-patterns)
20. [Checklist](#20-checklist)

---

# 1. What is DevSecOps?

DevSecOps is the practice of integrating security at every phase of the software development lifecycle (SDLC) — from planning and coding to building, testing, deploying, and operating.

```
Traditional:     Plan → Code → Build → Test → Deploy → SECURITY REVIEW → Operate
                                                              ↑
                                                     (bottleneck, late findings)

DevSecOps:       Plan → Code → Build → Test → Deploy → Operate
                   ↕       ↕      ↕       ↕      ↕        ↕
                 Security  Security Security Security Security Security
                 (threat   (SAST,  (SCA,   (DAST, (config  (runtime
                  model)   linting) images) pen    scan)    protect)
                                           test)
```

**In simple terms:** Security is not a gate at the end — it is embedded into every stage of the pipeline, automated wherever possible, and shared as a responsibility across development, operations, and security teams.

### Key Definition

> **DevSecOps = Development + Security + Operations**
>
> It is the philosophy of making security a shared responsibility throughout the entire IT lifecycle, rather than a separate team that reviews things after the fact.

---

# 2. Why DevSecOps?

### The Problem It Solves

| Traditional Approach | DevSecOps Approach |
|---|---|
| Security review happens at the end | Security checks happen continuously |
| Vulnerabilities found late are expensive to fix | Issues caught early are cheap to fix |
| Security team is a bottleneck | Security is automated and self-service |
| Developers and security are adversaries | Shared responsibility, shared tooling |
| Manual audits and checklists | Automated compliance scanning |
| "We'll fix it in the next release" | Fix it before it merges |

### Cost of Finding Bugs Late

```
Phase Found              Relative Cost to Fix
──────────────────────────────────────────────
Design                   1×
Development              6×
Testing                  15×
Production               100×
Post-breach              1000×+
```

### Business Benefits

- **Faster releases** — Security is automated, not a manual gate
- **Lower risk** — Vulnerabilities caught before they reach production
- **Compliance** — Continuous evidence of controls (SOC 2, HIPAA, PCI-DSS)
- **Cost savings** — Fix issues in dev ($100) vs production ($10,000+)
- **Trust** — Customers and auditors see proactive security posture
- **Developer productivity** — Clear, fast feedback instead of "security rejected your PR"

---

# 3. DevSecOps vs DevOps vs Traditional Security

| Aspect | Traditional | DevOps | DevSecOps |
|---|---|---|---|
| **Security timing** | End of cycle | Ad-hoc | Every stage |
| **Security team** | Gatekeeper | Consulted | Embedded |
| **Automation** | Manual reviews | CI/CD for code | CI/CD for code + security |
| **Feedback loop** | Weeks/months | Hours/days | Minutes |
| **Infrastructure** | Manual provisioning | IaC (Terraform) | IaC + policy-as-code |
| **Compliance** | Annual audits | Some automation | Continuous compliance |
| **Incident response** | Reactive | Somewhat proactive | Proactive + automated |
| **Culture** | "Security says no" | "Ship fast" | "Ship fast AND secure" |

---

# 4. Core Principles

### 4.1 Shift Left

Move security testing as early as possible in the pipeline. A vulnerability found in a pull request is 100x cheaper to fix than one found in production.

```
                    ← SHIFT LEFT ←

Production  ████████████████████ expensive, risky
Staging     ██████████████ moderate
PR/Build    ████████ cheap, fast
IDE/Local   ████ cheapest, instant
```

### 4.2 Automate Everything

If a security check can be automated, it should be. Manual reviews don't scale.

- Static analysis (SAST) → automated in PR pipeline
- Dependency scanning (SCA) → automated in build pipeline
- Container image scanning → automated before push to registry
- Infrastructure policy checks → automated in Terraform plan
- Dynamic testing (DAST) → automated in staging deployment

### 4.3 Security as Code

Define security policies, compliance rules, and configurations as code — version-controlled, peer-reviewed, and testable.

- Terraform for infrastructure
- OPA/Rego or Azure Policy for governance
- Kubernetes NetworkPolicies as YAML
- RBAC definitions as code

### 4.4 Shared Responsibility

Security is not just the security team's job:

| Role | Security Responsibility |
|---|---|
| **Developers** | Write secure code, fix SAST findings, manage secrets properly |
| **Ops/SRE** | Secure infrastructure, patch systems, monitor runtime |
| **Security** | Define policies, provide tools, review architecture, respond to incidents |
| **Product** | Include security in requirements, accept risk decisions |

### 4.5 Continuous Feedback

Every security finding should produce fast, actionable feedback to the developer who introduced it.

---

# 5. DevSecOps Lifecycle

```
    ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  PLAN   │────▶│  CODE   │────▶│  BUILD  │────▶│  TEST   │
    └────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
         │               │               │               │
    Threat Model    SAST/Linting    SCA/Image Scan   DAST/Pen Test
    Security Reqs   Secret Scan     License Check    Fuzz Testing
    Risk Assessment Pre-commit      SBOM Generate    Integration Tests
         │               │               │               │
    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
    │ RELEASE │◀────│ DEPLOY  │◀────│ OPERATE │◀────│ MONITOR │
    └─────────┘     └─────────┘     └─────────┘     └─────────┘
         │               │               │               │
    Approval Gates  Config Scan     Patch Mgmt      SIEM/Alerts
    Change Mgmt     Runtime Policy  Incident Resp   Log Analysis
    Sign Artifacts  Network Policy  Backup/DR       Anomaly Detection
```

### Phase-by-Phase Security Activities

| Phase | Security Activity | Tools |
|---|---|---|
| **Plan** | Threat modeling, security requirements | STRIDE, OWASP, Azure Boards |
| **Code** | SAST, secret scanning, linting | SonarQube, Checkov, GitLeaks, ESLint |
| **Build** | SCA, container scan, SBOM | Trivy, Snyk, Syft, Grype |
| **Test** | DAST, penetration testing, fuzzing | OWASP ZAP, Burp Suite |
| **Deploy** | Config validation, IaC scanning | Terraform Sentinel, OPA, tfsec |
| **Operate** | Runtime protection, patching | Falco, Defender for Cloud |
| **Monitor** | SIEM, alerting, anomaly detection | Azure Sentinel, Prometheus, Grafana |

---

# 6. DevSecOps Toolchain

### Complete Tool Matrix for Azure/AKS Stack

| Category | Tool | Purpose | Pipeline Stage |
|---|---|---|---|
| **Source Control** | Azure Repos / GitHub | Version control, branch policies | All |
| **CI/CD** | Azure DevOps Pipelines | Build, test, deploy automation | All |
| **IaC** | Terraform | Infrastructure provisioning | Deploy |
| **IaC Security** | tfsec, Checkov, Terrascan | Scan Terraform for misconfigs | Build |
| **SAST** | SonarQube, Semgrep, CodeQL | Static code analysis | Code/Build |
| **SCA** | Snyk, Dependabot, Trivy | Dependency vulnerability scan | Build |
| **Secret Scanning** | GitLeaks, Azure DevOps Credential Scanner | Find leaked secrets | Code/Build |
| **Container Scan** | Trivy, Aqua, Prisma Cloud | Scan container images | Build |
| **SBOM** | Syft, CycloneDX | Software Bill of Materials | Build |
| **License Check** | FOSSA, WhiteSource | Open source license compliance | Build |
| **DAST** | OWASP ZAP, Burp Suite | Dynamic application testing | Test |
| **K8s Policy** | OPA/Gatekeeper, Kyverno | Kubernetes admission control | Deploy |
| **Network Policy** | Calico, Azure NPM | Pod-to-pod traffic rules | Deploy |
| **Runtime Security** | Falco, Microsoft Defender | Runtime threat detection | Operate |
| **Monitoring** | Prometheus, Grafana, Azure Monitor | Metrics and dashboards | Monitor |
| **SIEM** | Azure Sentinel, Splunk | Security event management | Monitor |
| **Secret Mgmt** | Azure Key Vault, HashiCorp Vault | Secret storage and rotation | All |

---

# 7. Implementation Roadmap

### Phase 1: Foundation (Weeks 1–4)

```
Priority: HIGH — These are the "quick wins" that provide immediate value.

□ Set up Azure DevOps with branch policies
  - Require PR reviews (minimum 2 reviewers)
  - Require linked work items
  - Require successful build before merge
  - No direct pushes to main/release branches

□ Enable secret scanning
  - Install GitLeaks as pre-commit hook
  - Add credential scanner task to build pipeline
  - Configure Azure DevOps credential scanner

□ Add basic SAST
  - Integrate SonarQube or Semgrep into PR pipeline
  - Set quality gate: no critical/high findings allowed to merge
  - Start with "new code only" — don't block on legacy debt

□ Set up Terraform with remote state
  - Azure Storage backend with encryption
  - State file locking
  - Separate state per environment
```

### Phase 2: Build Security (Weeks 5–8)

```
Priority: HIGH — Secure what you're building and deploying.

□ Container image scanning
  - Scan images with Trivy before pushing to ACR
  - Block deployment if critical CVEs found
  - Use minimal base images (distroless, Alpine)

□ Dependency scanning (SCA)
  - Enable Snyk or Dependabot
  - Auto-create PRs for vulnerable dependencies
  - Set policy: critical CVEs must be fixed within 48 hours

□ IaC scanning
  - Add tfsec or Checkov to Terraform plan stage
  - Scan for: public endpoints, missing encryption, overly permissive RBAC
  - Generate compliance report artifacts

□ SBOM generation
  - Generate SBOM for every container image
  - Store SBOMs as pipeline artifacts
  - Required for supply chain security compliance
```

### Phase 3: Runtime & Kubernetes Security (Weeks 9–12)

```
Priority: MEDIUM — Secure the running environment.

□ AKS security hardening
  - Enable Azure Defender for Kubernetes
  - Enable Azure Policy for AKS
  - Implement NetworkPolicies (deny-all default + allow-list)
  - Enable pod security standards (restricted)

□ Admission control
  - Deploy OPA Gatekeeper or Kyverno
  - Policies: no privileged containers, no latest tags, required labels
  - Enforce resource limits on all pods

□ Runtime monitoring
  - Deploy Falco for runtime anomaly detection
  - Configure alerts for: shell exec in containers, unexpected network, file changes
  - Forward security events to Azure Sentinel

□ Secret management
  - Migrate all secrets to Azure Key Vault
  - Use AKS CSI Secret Store driver
  - Implement secret rotation
```

### Phase 4: Compliance & Maturity (Weeks 13–16)

```
Priority: MEDIUM — Prove compliance and continuously improve.

□ Compliance as code
  - Define compliance policies in OPA/Rego
  - Automated compliance reports per deployment
  - Evidence collection for auditors

□ DAST integration
  - Add OWASP ZAP to staging deployment pipeline
  - Scheduled penetration testing
  - Bug bounty program consideration

□ Incident response
  - Documented IR playbooks
  - Automated alerting and escalation
  - Regular tabletop exercises

□ Metrics and reporting
  - Mean time to remediate (MTTR) for vulnerabilities
  - Percentage of pipelines with security gates
  - Vulnerability trending over time
```

---

# 8. Azure DevOps Pipelines — Security Integration

### 8.1 Branch Policies (First Line of Defense)

Configure these in Azure DevOps → Repos → Branch Policies:

```yaml
# Branch: main
policies:
  - Minimum 2 reviewers
  - Require linked work item
  - Build must pass (including security checks)
  - Reset votes on new pushes
  - Include code owners as required reviewers
  - Comment resolution required

# Branch: release/*
policies:
  - Minimum 2 reviewers (must include security team)
  - All security scans must pass
  - Manual approval from release manager
```

### 8.2 Secure Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AZURE DEVOPS PIPELINE                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Stage 1: SECURITY SCAN (PR Trigger)                        │
│  ┌────────────┬────────────┬────────────┬──────────────┐    │
│  │   SAST     │  Secret    │   SCA      │  IaC Scan    │    │
│  │ (SonarQube)│  (GitLeaks)│  (Trivy)   │  (tfsec)     │    │
│  └─────┬──────┴─────┬──────┴─────┬──────┴──────┬───────┘    │
│        │            │            │             │             │
│        └────────────┴────────────┴─────────────┘             │
│                         │                                    │
│                    QUALITY GATE                               │
│              (fail if critical findings)                      │
│                         │                                    │
│  Stage 2: BUILD                                              │
│  ┌────────────┬────────────┬────────────┐                    │
│  │  Compile   │  Unit Test │ Image Build│                    │
│  │            │            │ + Scan     │                    │
│  └────────────┴────────────┴────────────┘                    │
│                         │                                    │
│  Stage 3: DEPLOY TO STAGING                                  │
│  ┌────────────┬────────────┬────────────┐                    │
│  │ Terraform  │  K8s Apply │   DAST     │                    │
│  │   Plan     │            │ (OWASP ZAP)│                    │
│  └────────────┴────────────┴────────────┘                    │
│                         │                                    │
│                  APPROVAL GATE                                │
│            (manual approval required)                        │
│                         │                                    │
│  Stage 4: DEPLOY TO PRODUCTION                               │
│  ┌────────────┬────────────┬────────────┐                    │
│  │ Terraform  │  K8s Apply │  Smoke     │                    │
│  │   Apply    │            │  Tests     │                    │
│  └────────────┴────────────┴────────────┘                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 8.3 Example: Security Scan Stage

```yaml
# azure-pipelines.yml — Security stage example
stages:
  - stage: SecurityScan
    displayName: 'Security Scanning'
    jobs:
      - job: SAST
        displayName: 'Static Analysis'
        steps:
          # Secret scanning with GitLeaks
          - task: Bash@3
            displayName: 'Secret Scan (GitLeaks)'
            inputs:
              targetType: inline
              script: |
                docker run --rm -v $(Build.SourcesDirectory):/code \
                  zricethezav/gitleaks:latest detect \
                  --source=/code --report-format=json \
                  --report-path=/code/gitleaks-report.json
            continueOnError: false

          # SAST with SonarQube
          - task: SonarQubePrepare@5
            inputs:
              SonarQube: 'SonarQube-Connection'
              scannerMode: 'CLI'
              configMode: 'manual'
              cliProjectKey: '$(Build.Repository.Name)'
              cliSources: '.'
              extraProperties: |
                sonar.qualitygate.wait=true

          - task: SonarQubeAnalyze@5
          - task: SonarQubePublish@5

          # Publish results as pipeline artifact
          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: '$(Build.SourcesDirectory)/gitleaks-report.json'
              artifactName: 'security-reports'

      - job: DependencyScan
        displayName: 'Dependency Scanning'
        steps:
          # Trivy for dependency vulnerabilities
          - task: Bash@3
            displayName: 'SCA Scan (Trivy)'
            inputs:
              targetType: inline
              script: |
                docker run --rm \
                  -v $(Build.SourcesDirectory):/code \
                  aquasec/trivy:latest fs /code \
                  --severity HIGH,CRITICAL \
                  --format json \
                  --output /code/trivy-sca-report.json \
                  --exit-code 1
            continueOnError: false

      - job: IaCScan
        displayName: 'Infrastructure as Code Scan'
        steps:
          # tfsec for Terraform
          - task: Bash@3
            displayName: 'Terraform Security Scan (tfsec)'
            inputs:
              targetType: inline
              script: |
                docker run --rm \
                  -v $(Build.SourcesDirectory):/code \
                  aquasec/tfsec:latest /code \
                  --format json \
                  --out /code/tfsec-report.json \
                  --severity-override HIGH,CRITICAL
            continueOnError: false

          # Checkov for broader IaC scanning
          - task: Bash@3
            displayName: 'IaC Policy Scan (Checkov)'
            inputs:
              targetType: inline
              script: |
                pip install checkov
                checkov -d $(Build.SourcesDirectory) \
                  --output json \
                  --output-file-path $(Build.SourcesDirectory)/checkov-report.json \
                  --framework terraform \
                  --check CKV_AZURE_1,CKV_AZURE_4,CKV_AZURE_7 \
                  --hard-fail-on HIGH,CRITICAL
```

### 8.4 Example: Container Image Scanning

```yaml
  - stage: Build
    displayName: 'Build & Scan'
    jobs:
      - job: BuildAndScan
        steps:
          - task: Docker@2
            displayName: 'Build Image'
            inputs:
              command: build
              repository: $(imageRepository)
              dockerfile: '**/Dockerfile'
              tags: '$(Build.BuildId)'

          # Scan the built image before pushing
          - task: Bash@3
            displayName: 'Scan Container Image (Trivy)'
            inputs:
              targetType: inline
              script: |
                docker run --rm \
                  -v /var/run/docker.sock:/var/run/docker.sock \
                  aquasec/trivy:latest image \
                  --severity HIGH,CRITICAL \
                  --exit-code 1 \
                  --format table \
                  $(imageRepository):$(Build.BuildId)

          # Generate SBOM
          - task: Bash@3
            displayName: 'Generate SBOM (Syft)'
            inputs:
              targetType: inline
              script: |
                curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
                syft $(imageRepository):$(Build.BuildId) \
                  -o spdx-json > $(Build.ArtifactStagingDirectory)/sbom.spdx.json

          # Only push if scans pass
          - task: Docker@2
            displayName: 'Push Image to ACR'
            inputs:
              command: push
              repository: $(imageRepository)
              tags: '$(Build.BuildId)'
```

### 8.5 Pipeline Variables — Secret Handling

```yaml
# WRONG — secrets in pipeline YAML
variables:
  DB_PASSWORD: 'my-secret-password'  # NEVER DO THIS

# CORRECT — secrets from Azure Key Vault
variables:
  - group: 'project-secrets'  # Linked to Azure Key Vault

# CORRECT — secret variable (masked in logs)
variables:
  - name: DB_PASSWORD
    value: $(db-password-from-keyvault)
```

---

# 9. Terraform — Infrastructure Security

### 9.1 Secure Terraform Setup

```
project/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── backend.tf        ← remote state config
│   ├── staging/
│   └── prod/
├── modules/
│   ├── aks/
│   ├── networking/
│   └── storage/
├── policies/                  ← OPA/Sentinel policies
│   ├── deny-public-aks.rego
│   ├── require-encryption.rego
│   └── enforce-tags.rego
└── .tfsec.yml                 ← tfsec config
```

### 9.2 Secure Remote State

```hcl
# backend.tf — Azure Storage with encryption and locking
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"     # Must have encryption enabled
    container_name       = "tfstate"
    key                  = "aks/dev/terraform.tfstate"

    # Security settings
    use_azuread_auth = true                        # Use Azure AD, not storage keys
  }
}

# Storage account security (provisioned separately)
# - Encryption at rest: Microsoft-managed keys (minimum) or CMK
# - Public access: Disabled
# - Firewall: Restrict to pipeline agent IPs only
# - Soft delete: Enabled (recover from accidental deletion)
# - Versioning: Enabled (rollback state)
# - Access: Azure AD RBAC only (no shared keys)
```

### 9.3 tfsec — Terraform Security Scanner

Common findings and how to fix them:

```hcl
# BAD — tfsec will flag this
resource "azurerm_kubernetes_cluster" "aks" {
  # ❌ No network policy
  # ❌ No Azure Defender
  # ❌ Default (public) API server
  # ❌ No disk encryption

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D4s_v3"
  }
}

# GOOD — tfsec-compliant
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-prod-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-prod"
  kubernetes_version  = "1.30"

  # ✅ Private cluster (API server not exposed to internet)
  private_cluster_enabled = true

  # ✅ Azure AD RBAC
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    managed            = true
  }

  # ✅ Network policy
  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
  }

  # ✅ Disk encryption
  disk_encryption_set_id = azurerm_disk_encryption_set.aks.id

  # ✅ Microsoft Defender
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id
  }

  # ✅ Azure Policy add-on
  azure_policy_enabled = true

  # ✅ Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  default_node_pool {
    name                 = "system"
    node_count           = 3
    vm_size              = "Standard_D4s_v3"
    os_disk_type         = "Managed"
    os_disk_size_gb      = 128
    max_pods             = 30
    zones                = [1, 2, 3]

    # ✅ Node pool encryption
    enable_host_encryption = true
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    CostCenter  = "infrastructure"
  }
}
```

### 9.4 Checkov — Policy as Code for Terraform

```bash
# Run Checkov on Terraform files
checkov -d ./terraform \
  --framework terraform \
  --output json \
  --hard-fail-on HIGH,CRITICAL

# Common Azure/AKS checks:
# CKV_AZURE_4  — AKS logging enabled
# CKV_AZURE_5  — AKS RBAC enabled
# CKV_AZURE_6  — AKS network policy configured
# CKV_AZURE_7  — AKS disk encryption
# CKV_AZURE_8  — AKS private cluster
# CKV_AZURE_115 — Defender for containers enabled
# CKV_AZURE_116 — Managed identity for AKS
# CKV_AZURE_117 — Azure Policy enabled on AKS
```

### 9.5 Terraform Plan Security Review in Pipeline

```yaml
- stage: TerraformPlan
  displayName: 'Terraform Plan + Security'
  jobs:
    - job: PlanAndScan
      steps:
        - task: Bash@3
          displayName: 'Terraform Init'
          inputs:
            targetType: inline
            script: |
              cd $(System.DefaultWorkingDirectory)/terraform
              terraform init -backend-config="key=$(environment).tfstate"

        - task: Bash@3
          displayName: 'Terraform Plan'
          inputs:
            targetType: inline
            script: |
              cd $(System.DefaultWorkingDirectory)/terraform
              terraform plan -out=tfplan -input=false
              terraform show -json tfplan > tfplan.json

        # Scan the plan output (catches runtime-resolved values)
        - task: Bash@3
          displayName: 'Scan Terraform Plan (tfsec)'
          inputs:
            targetType: inline
            script: |
              tfsec $(System.DefaultWorkingDirectory)/terraform \
                --tfvars-file $(environment).tfvars \
                --format json \
                --out tfsec-results.json

        # OPA policy check on plan
        - task: Bash@3
          displayName: 'Policy Check (OPA)'
          inputs:
            targetType: inline
            script: |
              opa eval \
                --input tfplan.json \
                --data policies/ \
                --format pretty \
                'data.terraform.deny[msg]'
```

---

# 10. Azure AKS — Kubernetes Security

### 10.1 AKS Security Checklist

```
CLUSTER LEVEL
─────────────────────────────────────────────────
✅ Private API server (or authorized IP ranges)
✅ Azure AD RBAC enabled (managed)
✅ Kubernetes RBAC enabled
✅ Azure Policy add-on enabled
✅ Microsoft Defender for Containers enabled
✅ Network policy (Calico or Azure)
✅ System and user node pool separation
✅ Disk encryption at rest
✅ Managed identity (not service principal)
✅ Automatic OS patching / node image upgrades
✅ Kubernetes version auto-upgrade (patch level)
✅ Audit logging enabled (kube-audit-admin to Log Analytics)

WORKLOAD LEVEL
─────────────────────────────────────────────────
✅ Pod Security Standards (restricted profile)
✅ No privileged containers
✅ No root containers (runAsNonRoot: true)
✅ Read-only root filesystem
✅ Resource limits on all pods
✅ No hostNetwork, hostPID, hostIPC
✅ No latest image tags
✅ Images from private registry only (ACR)
✅ NetworkPolicies: deny-all default + explicit allow
✅ Service accounts: automountServiceAccountToken: false
✅ Secrets via CSI Secret Store (not env vars)

NETWORK LEVEL
─────────────────────────────────────────────────
✅ NSG on AKS subnet
✅ Azure Firewall / UDR for egress control
✅ Internal load balancers where possible
✅ TLS everywhere (ingress, pod-to-pod with mTLS)
✅ DNS security (Azure Private DNS zones)
```

### 10.2 Pod Security Standards

```yaml
# Enforce restricted pod security standard at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 10.3 NetworkPolicy — Default Deny + Allow List

```yaml
# Step 1: Deny all ingress and egress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Step 2: Allow specific traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
---
# Step 3: Allow DNS resolution (required for all pods)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to: []
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### 10.4 OPA Gatekeeper — Admission Control

```yaml
# Constraint Template: Disallow privileged containers
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdisallowprivileged
spec:
  crd:
    spec:
      names:
        kind: K8sDisallowPrivileged
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdisallowprivileged
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.privileged == true
          msg := sprintf("Privileged container not allowed: %v", [container.name])
        }
---
# Constraint: Apply to all namespaces except kube-system
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowPrivileged
metadata:
  name: deny-privileged-containers
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
---
# Constraint: Require resource limits
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResourceLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresourcelimits
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container %v must have memory limits", [container.name])
        }
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf("Container %v must have CPU limits", [container.name])
        }
---
# Constraint: No latest tags
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdisallowlatesttag
spec:
  crd:
    spec:
      names:
        kind: K8sDisallowLatestTag
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdisallowlatesttag
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          endswith(container.image, ":latest")
          msg := sprintf("Image '%v' uses :latest tag, which is not allowed", [container.image])
        }
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not contains(container.image, ":")
          msg := sprintf("Image '%v' has no tag specified (defaults to :latest)", [container.image])
        }
```

---

# 11. Container Security

### 11.1 Secure Dockerfile Best Practices

```dockerfile
# ✅ Use specific version tags, not :latest
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS base

# ✅ Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# ✅ Use multi-stage build (smaller attack surface)
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app

# ✅ Final stage: minimal image
FROM base AS final
WORKDIR /app
COPY --from=build /app .

# ✅ Run as non-root
USER appuser

# ✅ Read-only filesystem compatible
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### 11.2 Container Scanning Pipeline

```
Source Code → Build Image → Scan Image → Push to ACR → Deploy to AKS
                               │
                    ┌──────────┴──────────┐
                    │                     │
               Vulnerabilities?      Clean?
                    │                     │
               BLOCK PUSH           ALLOW PUSH
               + Alert Team         + Tag as "scanned"
```

### 11.3 Image Signing & Verification

```bash
# Sign images with Notary v2 (notation)
notation sign myacr.azurecr.io/myapp:v1.0

# Verify before deploy (can be enforced via policy)
notation verify myacr.azurecr.io/myapp:v1.0

# In AKS: Use Azure Policy to require signed images
# Built-in policy: "Kubernetes cluster containers should only use allowed images"
```

---

# 12. Secret Management

### 12.1 Secret Hierarchy

```
WORST → BEST (security level)

❌ Hardcoded in source code        — NEVER
❌ Environment variables in YAML    — Visible in kubectl describe
❌ Kubernetes Secrets (default)     — Base64, not encrypted at rest by default
⚠️  Kubernetes Secrets + etcd enc   — Better, but secrets still in cluster
✅ Azure Key Vault + CSI driver     — Secrets stored outside cluster
✅ Azure Key Vault + Managed ID     — No credentials to manage at all
```

### 12.2 Azure Key Vault + AKS CSI Secret Store

```yaml
# SecretProviderClass — mounts Key Vault secrets into pods
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secrets
  namespace: production
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "<managed-identity-client-id>"
    keyvaultName: "kv-myapp-prod"
    objects: |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
        - |
          objectName: api-key
          objectType: secret
    tenantId: "<tenant-id>"
  # Sync to Kubernetes secret (optional, for env var use)
  secretObjects:
    - secretName: app-secrets
      type: Opaque
      data:
        - objectName: db-connection-string
          key: DB_CONNECTION_STRING
        - objectName: api-key
          key: API_KEY
---
# Pod using the secret
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: production
spec:
  containers:
    - name: myapp
      image: myacr.azurecr.io/myapp:v1.0
      volumeMounts:
        - name: secrets
          mountPath: "/mnt/secrets"
          readOnly: true
      env:
        - name: DB_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_CONNECTION_STRING
  volumes:
    - name: secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: azure-keyvault-secrets
```

### 12.3 Secret Rotation

```
Azure Key Vault
  │
  ├── Secret: db-password
  │   ├── Version 1 (expired)
  │   ├── Version 2 (current) ← AKS CSI driver polls every 2m
  │   └── Auto-rotation: Every 90 days
  │
  └── Secret: api-key
      └── Auto-rotation: Every 30 days

AKS Pod
  │
  └── /mnt/secrets/db-password ← Updated automatically (no pod restart needed)
```

---

# 13. Compliance as Code

### 13.1 Azure Policy for AKS

```
Built-in Policy Initiatives for AKS:

□ "Kubernetes cluster pod security restricted standards for Linux-based workloads"
  - No privileged containers
  - No privilege escalation
  - Runs as non-root
  - Restricted volume types
  - Required seccomp profile

□ "Kubernetes clusters should not allow container privilege escalation"
□ "Kubernetes cluster containers should only use allowed images"
□ "Kubernetes cluster pods should only use approved host network and port range"
□ "Kubernetes cluster should not allow privileged containers"
□ "AKS clusters should have Defender profile enabled"
□ "AKS clusters should have Azure Policy add-on enabled"
```

### 13.2 Compliance Reporting in Pipeline

```yaml
- task: Bash@3
  displayName: 'Generate Compliance Report'
  inputs:
    targetType: inline
    script: |
      # Collect evidence for auditors
      echo "=== Compliance Report ===" > compliance-report.txt
      echo "Date: $(date -u)" >> compliance-report.txt
      echo "Pipeline: $(Build.BuildNumber)" >> compliance-report.txt
      echo "Commit: $(Build.SourceVersion)" >> compliance-report.txt
      echo "" >> compliance-report.txt

      echo "=== Security Scan Results ===" >> compliance-report.txt
      echo "SAST: $(cat sast-results.json | jq '.issues | length') findings" >> compliance-report.txt
      echo "SCA: $(cat sca-results.json | jq '.vulnerabilities | length') vulnerabilities" >> compliance-report.txt
      echo "Container Scan: $(cat trivy-results.json | jq '.Results[0].Vulnerabilities | length') CVEs" >> compliance-report.txt
      echo "IaC Scan: $(cat tfsec-results.json | jq '.results | length') findings" >> compliance-report.txt
      echo "" >> compliance-report.txt

      echo "=== Policy Compliance ===" >> compliance-report.txt
      echo "OPA Policies: PASS" >> compliance-report.txt
      echo "Azure Policies: PASS" >> compliance-report.txt

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: 'compliance-report.txt'
    artifactName: 'compliance'
```

### 13.3 Mapping to Compliance Frameworks

| Control | SOC 2 | PCI-DSS | HIPAA | How We Address It |
|---|---|---|---|---|
| Access control | CC6.1 | 7.1 | 164.312(a) | Azure AD RBAC, K8s RBAC, least privilege |
| Encryption at rest | CC6.1 | 3.4 | 164.312(a)(2)(iv) | AKS disk encryption, Key Vault |
| Encryption in transit | CC6.7 | 4.1 | 164.312(e) | TLS everywhere, mTLS between pods |
| Vulnerability mgmt | CC7.1 | 6.1 | 164.308(a)(1) | Trivy, SonarQube, automated scanning |
| Logging & monitoring | CC7.2 | 10.1 | 164.312(b) | Azure Monitor, Sentinel, Falco |
| Change management | CC8.1 | 6.4 | 164.312(c)(1) | Git, PR reviews, pipeline approval gates |
| Incident response | CC7.3 | 12.10 | 164.308(a)(6) | Playbooks, Sentinel automation |
| Backup & recovery | A1.2 | 9.5 | 164.308(a)(7) | GKE Backup, ES snapshots, GCS |

---

# 14. Monitoring, Logging & Incident Response

### 14.1 Security Monitoring Stack

```
APPLICATION LAYER
├── Azure Application Insights → Application performance + errors
├── Custom metrics → Business-level security events

KUBERNETES LAYER
├── Prometheus + Grafana → Cluster metrics, pod health
├── Falco → Runtime anomaly detection
│   ├── Alert: Shell spawned in container
│   ├── Alert: Unexpected outbound connection
│   ├── Alert: Sensitive file read (/etc/shadow)
│   └── Alert: Namespace created/deleted
├── kube-audit-admin → API server audit logs
└── Azure Defender for Kubernetes → Threat detection

INFRASTRUCTURE LAYER
├── Azure Monitor → VM, disk, network metrics
├── Azure Activity Log → Control plane operations
├── NSG Flow Logs → Network traffic analysis
└── Azure Firewall Logs → Egress traffic

AGGREGATION
└── Azure Sentinel (SIEM)
    ├── Correlation rules
    ├── Automated playbooks (SOAR)
    ├── Threat intelligence feeds
    └── Investigation workbooks
```

### 14.2 Key Security Alerts

| Alert | Severity | Source | Action |
|---|---|---|---|
| Container shell exec detected | HIGH | Falco/Defender | Investigate immediately |
| Failed login attempts > 10/min | MEDIUM | ES audit log | Check for brute force |
| Privileged container created | CRITICAL | OPA/Audit | Block + alert security |
| Outbound to known-bad IP | HIGH | Azure Firewall | Block + investigate |
| Secret accessed by unknown identity | HIGH | Key Vault audit | Verify authorization |
| AKS admin role assigned | HIGH | Azure Activity Log | Verify with team |
| Terraform state file accessed | MEDIUM | Storage audit | Verify pipeline run |

### 14.3 Incident Response Playbook

```
SEVERITY LEVELS
─────────────────────────────────────────
P1 (Critical): Active breach, data exfiltration, complete service outage
P2 (High):     Vulnerability being exploited, partial breach
P3 (Medium):   Vulnerability found in production, suspicious activity
P4 (Low):      Informational finding, policy violation

RESPONSE STEPS
─────────────────────────────────────────
1. DETECT    → Automated alert triggers (Sentinel, Falco, Defender)
2. TRIAGE    → On-call engineer assesses severity (15 min SLA for P1)
3. CONTAIN   → Isolate affected workload (NetworkPolicy, scale to 0)
4. ERADICATE → Remove root cause (patch, revoke credentials, fix config)
5. RECOVER   → Restore service, verify fix, monitor for recurrence
6. REVIEW    → Post-incident review within 48 hours, update runbooks
```

---

# 15. RBAC & Identity

### 15.1 Azure AD + AKS RBAC

```
Azure AD Groups → AKS ClusterRoles → Namespace Permissions

Group: AKS-Developers
  └── ClusterRole: developer
      └── Namespaces: dev, staging
      └── Permissions: get, list, watch, create, update pods/deployments/services

Group: AKS-SRE
  └── ClusterRole: sre
      └── Namespaces: ALL
      └── Permissions: get, list, watch, exec, logs, port-forward

Group: AKS-Admins
  └── ClusterRole: cluster-admin
      └── Namespaces: ALL
      └── Permissions: ALL (use sparingly, break-glass only)

Group: AKS-Security
  └── ClusterRole: security-auditor
      └── Namespaces: ALL
      └── Permissions: get, list, watch (read-only, including secrets metadata)
```

### 15.2 Kubernetes RBAC Example

```yaml
# ClusterRole for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "services", "configmaps", "jobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
  # Explicitly deny secret access
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
    # Note: To deny, simply don't include. RBAC is additive-only.
---
# RoleBinding for dev namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: dev
subjects:
  - kind: Group
    name: "AKS-Developers-ObjectID"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### 15.3 Managed Identity (No Credentials)

```hcl
# AKS with managed identity (Terraform)
resource "azurerm_kubernetes_cluster" "aks" {
  identity {
    type = "SystemAssigned"
  }

  kubelet_identity {
    # Kubelet uses managed identity to pull from ACR
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

# Grant AKS managed identity access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Grant AKS managed identity access to Key Vault
resource "azurerm_role_assignment" "aks_kv" {
  principal_id         = azurerm_kubernetes_cluster.aks.key_vault_secrets_provider[0].secret_identity[0].object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.kv.id
}
```

---

# 16. Sample Pipeline Architecture

### End-to-End Secure Deployment

```
Developer
  │
  ├── Pre-commit hooks (local)
  │   ├── GitLeaks (secret scan)
  │   ├── ESLint / pylint (code quality)
  │   └── terraform fmt / validate
  │
  ▼
Git Push → PR Created
  │
  ├── PR Pipeline (triggers automatically)
  │   ├── Stage: Security
  │   │   ├── SAST (SonarQube)
  │   │   ├── Secret Scan (GitLeaks)
  │   │   ├── SCA (Trivy/Snyk)
  │   │   └── IaC Scan (tfsec/Checkov)
  │   │
  │   ├── Stage: Build
  │   │   ├── Compile / test
  │   │   ├── Build container image
  │   │   ├── Scan image (Trivy)
  │   │   └── Generate SBOM (Syft)
  │   │
  │   └── QUALITY GATE
  │       ├── No critical/high SAST findings
  │       ├── No critical CVEs in dependencies
  │       ├── No secrets detected
  │       ├── All IaC checks pass
  │       └── Code coverage >= 80%
  │
  ▼
PR Approved + Merged to main
  │
  ├── Release Pipeline (triggers on main)
  │   ├── Stage: Deploy to Staging
  │   │   ├── Terraform plan → apply
  │   │   ├── Push image to ACR
  │   │   ├── Deploy to AKS (staging)
  │   │   ├── DAST scan (OWASP ZAP)
  │   │   └── Integration tests
  │   │
  │   ├── APPROVAL GATE (manual)
  │   │   └── Security + Release Manager approve
  │   │
  │   └── Stage: Deploy to Production
  │       ├── Terraform plan → apply
  │       ├── Deploy to AKS (prod)
  │       ├── Smoke tests
  │       ├── Canary rollout
  │       └── Generate compliance report
  │
  ▼
Production
  │
  └── Continuous Monitoring
      ├── Falco (runtime security)
      ├── Defender (threat detection)
      ├── Prometheus/Grafana (metrics)
      └── Sentinel (SIEM)
```

---

# 17. Security Gates & Quality Gates

### Gate Types

| Gate | Stage | Type | Blocks? |
|---|---|---|---|
| SAST — no critical findings | PR | Automated | Yes |
| Secret scan — no secrets | PR | Automated | Yes |
| SCA — no critical CVEs | Build | Automated | Yes |
| Container scan — no critical CVEs | Build | Automated | Yes |
| IaC scan — no high findings | Build | Automated | Yes |
| Code coverage >= 80% | Build | Automated | Yes |
| DAST — no critical findings | Staging | Automated | Yes |
| Security team approval | Pre-prod | Manual | Yes |
| Compliance report generated | Prod | Automated | No (artifact) |

### Implementing Gates in Azure DevOps

```yaml
# Quality gate using pipeline conditions
- stage: Deploy_Production
  condition: |
    and(
      succeeded('SecurityScan'),
      succeeded('Build'),
      succeeded('Deploy_Staging'),
      eq(variables['SAST_PASSED'], 'true'),
      eq(variables['IMAGE_SCAN_PASSED'], 'true'),
      eq(variables['IAC_SCAN_PASSED'], 'true')
    )
  jobs:
    - deployment: Production
      environment: 'production'   # Has approval checks configured
      strategy:
        runOnce:
          deploy:
            steps:
              - script: echo "Deploying to production"
```

### Environment Approvals

Configure in Azure DevOps → Environments → production → Approvals and checks:

```
Environment: production
├── Approvals:
│   ├── Required: Security Team (group)
│   ├── Required: Release Manager (individual)
│   └── Timeout: 72 hours
├── Branch control:
│   └── Only allow from: refs/heads/main
├── Business hours:
│   └── Mon-Thu, 9 AM - 4 PM EST (no Friday deploys)
└── Exclusive lock:
    └── Only one deployment at a time
```

---

# 18. Maturity Model

### Level 1: Basic (most orgs start here)

```
✅ Source code in Git
✅ CI/CD pipeline exists
✅ Basic branch policies (PR required)
✅ Secrets not in source code
❌ No automated security scanning
❌ No container scanning
❌ No IaC scanning
❌ Manual compliance
```

### Level 2: Developing

```
✅ Everything in Level 1
✅ SAST in PR pipeline
✅ Secret scanning (automated)
✅ Dependency scanning (SCA)
✅ Container image scanning
✅ Azure Key Vault for secrets
❌ No runtime security
❌ No admission control
❌ Manual compliance reports
```

### Level 3: Defined

```
✅ Everything in Level 2
✅ IaC scanning (tfsec/Checkov)
✅ DAST in staging pipeline
✅ OPA Gatekeeper / Kyverno admission control
✅ NetworkPolicies enforced
✅ Pod Security Standards enforced
✅ RBAC with Azure AD groups
✅ Managed identities (no service principal keys)
❌ No SIEM correlation
❌ No automated incident response
```

### Level 4: Managed

```
✅ Everything in Level 3
✅ Azure Sentinel (SIEM) with correlation rules
✅ Falco runtime security
✅ Automated compliance reports
✅ SBOM generation for all images
✅ Image signing and verification
✅ Secret rotation automated
✅ Security metrics dashboard
✅ Incident response playbooks
❌ No chaos engineering
❌ No threat intelligence feeds
```

### Level 5: Optimizing

```
✅ Everything in Level 4
✅ Threat intelligence integration
✅ Automated incident response (SOAR)
✅ Chaos engineering / game days
✅ Red team exercises
✅ Bug bounty program
✅ Supply chain security (SLSA framework)
✅ Zero-trust network model
✅ Continuous improvement based on metrics
```

---

# 19. Common Mistakes & Anti-Patterns

### Mistake 1: Security Theater

```
BAD:  Running security scans but ignoring all findings
BAD:  "We'll fix it later" (tech debt becomes security debt)
GOOD: Set quality gates that actually block deployments
GOOD: Track MTTR (mean time to remediate) as a KPI
```

### Mistake 2: Over-Reliance on Tools

```
BAD:  "We installed SonarQube, we're secure now"
GOOD: Tools are one layer — combine with training, code review,
      architecture review, threat modeling
```

### Mistake 3: Not Securing the Pipeline Itself

```
BAD:  Anyone can modify the pipeline YAML
BAD:  Pipeline service connections have admin access to everything
BAD:  No audit log of pipeline changes

GOOD: Pipeline YAML in protected branches (requires PR)
GOOD: Service connections follow least privilege
GOOD: Variable groups with limited access
GOOD: Audit logs enabled for all pipeline changes
```

### Mistake 4: Secrets in Wrong Places

```
BAD:  Secrets in pipeline variables (not marked as secret)
BAD:  Secrets in ConfigMaps
BAD:  Secrets in Docker build args (visible in image layers)
BAD:  Secrets in git history (even if removed from current code)

GOOD: Secrets in Azure Key Vault
GOOD: Mounted via CSI driver (not env vars)
GOOD: Rotated automatically
GOOD: Audited (who accessed what, when)
```

### Mistake 5: Ignoring Supply Chain

```
BAD:  Using random Docker Hub images in production
BAD:  No pinned versions in Dockerfile (FROM node:latest)
BAD:  No SBOM, no visibility into transitive dependencies

GOOD: Use private ACR, mirror approved base images
GOOD: Pin ALL versions (FROM node:20.11.1-alpine3.19)
GOOD: Generate SBOM for every build
GOOD: Use image signing (Notary/cosign)
```

### Mistake 6: "Set and Forget" Infrastructure

```
BAD:  Deploy AKS once, never patch
BAD:  No node image upgrades
BAD:  Kubernetes version 3+ releases behind

GOOD: Auto node image upgrades (weekly)
GOOD: Kubernetes version auto-upgrade (patch)
GOOD: Regular full upgrade cadence (quarterly minor versions)
```

---

# 20. Checklist

### Pre-Deployment Checklist

```
PIPELINE SECURITY
□ Branch policies configured (require PR, reviewers)
□ Secret scanning enabled (GitLeaks/credential scanner)
□ SAST enabled in PR pipeline
□ SCA/dependency scanning enabled
□ Container image scanning before push
□ IaC scanning (tfsec/Checkov) in plan stage
□ Quality gates configured to block on critical findings
□ Pipeline service connections use least privilege
□ Variable groups secured (limited access)

INFRASTRUCTURE (TERRAFORM)
□ Remote state encrypted and locked
□ State access via Azure AD (not storage keys)
□ All resources tagged (owner, environment, cost-center)
□ AKS private cluster or authorized IP ranges
□ AKS Azure AD RBAC enabled
□ AKS network policy enabled (Calico)
□ AKS Defender enabled
□ AKS Azure Policy enabled
□ Disk encryption enabled
□ Managed identity (not service principal)

KUBERNETES (AKS)
□ Pod Security Standards enforced (restricted)
□ NetworkPolicies: default deny + explicit allow
□ OPA Gatekeeper or Kyverno deployed
□ No privileged containers
□ No root containers
□ Resource limits on all pods
□ Images from private registry only
□ No :latest tags
□ Service account tokens not auto-mounted
□ Secrets via CSI Secret Store driver

MONITORING & RESPONSE
□ Azure Sentinel configured
□ Falco deployed for runtime detection
□ kube-audit-admin logs forwarded
□ Alert rules for critical security events
□ Incident response playbook documented
□ On-call rotation defined
□ Regular security review cadence (monthly)

COMPLIANCE
□ Compliance framework mapped (SOC 2 / PCI / HIPAA)
□ Automated compliance reporting
□ SBOM generated for all images
□ Evidence collection automated
□ Regular penetration testing scheduled
```

---

# Appendix A: Quick Reference Commands

```bash
# AKS Security Check Commands

# Check pod security violations
kubectl get events --field-selector reason=FailedCreate -A | grep -i security

# List all privileged pods
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.name'

# Check network policies
kubectl get networkpolicy -A

# Check OPA Gatekeeper constraints
kubectl get constraints -A

# Check for pods running as root
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].securityContext.runAsUser==0) | .metadata.name'

# View AKS audit logs
az monitor log-analytics query -w <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'kube-audit-admin' | take 50"

# Check AKS Defender alerts
az security alert list --resource-group <rg-name>

# Verify Azure Policy compliance
az policy state list --resource-group <rg-name> --filter "complianceState eq 'NonCompliant'"
```

---

# Appendix B: Useful Links

- OWASP Top 10: https://owasp.org/www-project-top-ten/
- OWASP Kubernetes Security: https://owasp.org/www-project-kubernetes-top-ten/
- CIS AKS Benchmark: https://www.cisecurity.org/benchmark/kubernetes
- Azure AKS Security Best Practices: https://learn.microsoft.com/en-us/azure/aks/concepts-security
- NIST Cybersecurity Framework: https://www.nist.gov/cyberframework
- SLSA Supply Chain Framework: https://slsa.dev/
- Azure DevOps Security Best Practices: https://learn.microsoft.com/en-us/azure/devops/organizations/security/
- Terraform Security Best Practices: https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices

---

*Document Version: 1.0*
*Last Updated: March 2026*
*Scope: Azure AKS + Terraform + Azure DevOps Pipelines*
