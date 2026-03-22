# Azure AD App Registration for ECK SSO

## Prerequisites
- Azure AD Global Administrator or Application Administrator role
- Access to Azure Portal (https://portal.azure.com)

## Step 1: Register Application in Azure AD

1. Go to **Azure Active Directory** > **App registrations** > **New registration**
2. Configure:
   - **Name**: `ECK-Elasticsearch-SSO`
   - **Supported account types**: Accounts in this organizational directory only (PwC only - Single tenant)
   - **Redirect URI**:
     - Type: Web
     - URI: `https://<KIBANA_URL>/api/security/oidc/callback`
     - (Add additional for each environment)

3. Note the following values after registration:
   - **Application (client) ID**: `<CLIENT_ID>`
   - **Directory (tenant) ID**: `<TENANT_ID>`

## Step 2: Create Client Secret

1. Go to **Certificates & secrets** > **New client secret**
2. Description: `ECK SSO Secret`
3. Expiry: 24 months (set calendar reminder to rotate)
4. **Copy the secret value immediately** - it won't be shown again

## Step 3: Configure Token Claims

1. Go to **Token configuration** > **Add optional claim**
2. Token type: **ID**
3. Add claims:
   - `email`
   - `preferred_username`
   - `given_name`
   - `family_name`
   - `groups` (select "Security groups")

4. Go to **Token configuration** > **Add groups claim**
   - Select: Security groups
   - ID token: Group ID
   - Access token: Group ID

## Step 4: API Permissions

1. Go to **API permissions** > **Add a permission**
2. Select **Microsoft Graph** > **Delegated permissions**
3. Add:
   - `openid`
   - `profile`
   - `email`
   - `User.Read`
4. Click **Grant admin consent for PwC**

## Step 5: Create Security Groups

Create these groups in Azure AD for role mapping:

| Azure AD Group Name        | Purpose                              |
|----------------------------|--------------------------------------|
| `ECK-Admins`               | Full admin access to ES and Kibana   |
| `ECK-Editors`              | Read/write access to indices/Kibana  |
| `ECK-Viewers`              | Read-only access to Kibana dashboards|

Assign team members to groups based on their role in `team-members.yaml`.

## Step 6: Note OIDC Endpoints

Your Azure AD OIDC endpoints follow this pattern:
```
Issuer:        https://login.microsoftonline.com/<TENANT_ID>/v2.0
Authorization: https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/authorize
Token:         https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token
Userinfo:      https://graph.microsoft.com/oidc/userinfo
JWKS:          https://login.microsoftonline.com/<TENANT_ID>/discovery/v2.0/keys
Logout:        https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/logout
```

## Step 7: Store Secrets in GCP Secret Manager

```bash
# Store client secret in GCP Secret Manager
echo -n "<CLIENT_SECRET>" | gcloud secrets create eck-oidc-client-secret \
  --data-file=- \
  --project=<PROJECT_ID>

# Store client ID
echo -n "<CLIENT_ID>" | gcloud secrets create eck-oidc-client-id \
  --data-file=- \
  --project=<PROJECT_ID>

# Store tenant ID
echo -n "<TENANT_ID>" | gcloud secrets create eck-oidc-tenant-id \
  --data-file=- \
  --project=<PROJECT_ID>
```
