# 🚀 Order Processing Service – AKS + APIM + Terraform + Helm

A production-ready deployment template for the **order-processing-service** Java Spring Boot microservice on **Azure Kubernetes Service (AKS)**, fronted by **Azure API Management (APIM)** with subscription keys and OAuth 2.0 (JWT validation), fully provisioned via **Terraform IaC** and deployed using **Helm** + **GitHub Actions CI/CD**.

> **Source:** [https://github.com/hkswamy/order-processing-service](https://github.com/hkswamy/order-processing-service)

---

## 📐 Architecture

```
┌──────────────┐      ┌──────────────────────────────────────────────────────┐
│   Client /   │      │                    Azure Cloud                       │
│   Consumer   │──────│─►  APIM Gateway (Subscription Key + JWT Validation)  │
│              │      │         │                                            │
└──────────────┘      │         ▼                                            │
                      │   ┌───────────┐    ┌──────────────────────────────┐  │
                      │   │  VNet     │    │  Azure AD / Entra ID         │  │
                      │   │ (10.0.0/16│    │  - API App Registration      │  │
                      │   │)          │    │  - Client App Registration   │  │
                      │   │           │    │  - OAuth 2.0 Token Endpoint  │  │
                      │   │  ┌snet-aks│    └──────────────────────────────┘  │
                      │   │  │(.1/24) │                                      │
                      │   │  │ ┌─────────────────────┐                      │
                      │   │  │ │   AKS Cluster        │                      │
                      │   │  │ │  ┌─────────────────┐ │   ┌──────────────┐  │
                      │   │  │ │  │ Helm Release:    │ │   │    ACR       │  │
                      │   │  │ │  │ order-processing │◄├───│ (Docker      │  │
                      │   │  │ │  │ -service (2 pods)│ │   │  images)     │  │
                      │   │  │ │  └─────────────────┘ │   └──────────────┘  │
                      │   │  │ │  HPA: 2→5 replicas   │                      │
                      │   │  │ └─────────────────────┘                      │
                      │   │  │                         │                      │
                      │   │  └snet-apim (.2/24)        │                      │
                      │   └───────────┘                                      │
                      └──────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
terraform-aks-apim/
├── .github/workflows/
│   └── deploy-aks.yml          # CI/CD: Build → Push → Deploy (Helm)
├── infra/terraform/
│   ├── main.tf                 # Providers, resource group
│   ├── variables.tf            # All configurable variables
│   ├── network.tf              # VNet, subnets, NSG
│   ├── acr.tf                  # Azure Container Registry
│   ├── aks.tf                  # AKS cluster + ACR integration
│   ├── azure_ad.tf             # Azure AD app registrations (OAuth)
│   ├── apim.tf                 # APIM + OAuth server + policies
│   ├── outputs.tf              # Terraform outputs
│   └── terraform.tfvars.example
├── helm/order-processing-service/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml
│       ├── serviceaccount.yaml
│       └── NOTES.txt
├── Dockerfile                  # Multi-stage Spring Boot build
├── .gitignore
└── README.md
```

---

## ✅ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------  |
| Azure CLI | >= 2.60 | Azure authentication & management |
| Terraform | >= 1.5 | Infrastructure provisioning |
| kubectl | >= 1.30 | Kubernetes cluster interaction |
| Helm | >= 3.15 | Kubernetes package manager |
| Docker | >= 26.x | Container image builds |
| Java (JDK) | 21 | Build the Spring Boot app |
| Maven | >= 3.9 | Java build tool |

---

## 🚀 Quick Start

### 1. Configure Azure OIDC for GitHub Actions (one-time)

```bash
# Create Azure AD app registration for GitHub Actions
az ad app create --display-name "github-actions-oidc"
APP_ID=$(az ad app list --display-name "github-actions-oidc" --query "[0].appId" -o tsv)
az ad sp create --id $APP_ID

# Assign Contributor role
az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Add federated credential for your repo
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<OWNER>/order-processing-service:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 2. Set GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | App registration Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

### 3. Configure Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit: add your tenant_id and subscription_id
```

### 4. Push to `main` to trigger the pipeline

```bash
git add .
git commit -m "Initial AKS + APIM deployment"
git push origin main
```

The GitHub Actions pipeline will automatically:
1. **Provision infrastructure** (Terraform)
2. **Build & test** the Spring Boot app (Maven)
3. **Build & push** Docker image to ACR
4. **Deploy** to AKS using Helm

### 5. Manual deployment (optional)

```bash
# Terraform
cd infra/terraform
terraform init && terraform apply

# Docker
ACR_SERVER=$(terraform output -raw acr_login_server)
az acr login --name $ACR_SERVER
docker build -t $ACR_SERVER/order-processing-service:v1 ../../
docker push $ACR_SERVER/order-processing-service:v1

# Connect to AKS
az aks get-credentials --resource-group rg-order-processing --name aks-order-processing

# Helm deploy
helm upgrade --install order-processing-service ../../helm/order-processing-service \
  --namespace order-processing --create-namespace \
  --set image.repository=$ACR_SERVER/order-processing-service \
  --set image.tag=v1 \
  --wait
```

---

## 🧪 Testing the API

```bash
# Get subscription key
SUB_KEY=$(terraform -chdir=infra/terraform output -raw subscription_key)

# Get OAuth token (client credentials flow)
CLIENT_ID=$(terraform -chdir=infra/terraform output -raw client_app_id)
API_APP_ID=$(terraform -chdir=infra/terraform output -raw api_app_id)
TENANT_ID="<YOUR_TENANT_ID>"

TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=<CLIENT_SECRET>" \
  -d "scope=api://${API_APP_ID}/api.access" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

APIM_URL=$(terraform -chdir=infra/terraform output -raw api_url)

# Create an order
curl -X POST "${APIM_URL}/api/v1/orders" \
  -H "Ocp-Apim-Subscription-Key: ${SUB_KEY}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"menuItemId":"1","name":"Burger","quantity":2,"unitPrice":9.99}]}'

# Get all orders
curl -X GET "${APIM_URL}/api/v1/orders" \
  -H "Ocp-Apim-Subscription-Key: ${SUB_KEY}" \
  -H "Authorization: Bearer ${TOKEN}"
```

---

## 🔐 Security Features

- ✅ **OIDC (Passwordless)** – GitHub Actions authenticates to Azure without stored secrets
- ✅ **Subscription Keys** – Every API call requires `Ocp-Apim-Subscription-Key`
- ✅ **OAuth 2.0 / JWT Validation** – Azure AD tokens validated at APIM gateway
- ✅ **Rate Limiting** – 100 calls/minute per subscription
- ✅ **Network Isolation** – AKS and APIM in separate VNet subnets
- ✅ **Managed Identity** – AKS pulls images from ACR without credentials
- ✅ **Non-root Docker** – Container runs as non-root user
- ✅ **Health Checks** – Readiness & liveness probes via Spring Boot Actuator
- ✅ **HPA Autoscaling** – 2→5 pods based on CPU utilization

---

## 🧹 Cleanup

```bash
# Remove Helm release
helm uninstall order-processing-service -n order-processing

# Destroy all Azure resources
cd infra/terraform
terraform destroy
```

---

## 📝 License

MIT
