#!/usr/bin/env bash
set -euo pipefail

# GapMap-Jabar Azure bootstrap script
# Usage:
#   bash infra/deploy.sh
# Optional env overrides:
#   LOCATION=southeastasia
#   RESOURCE_GROUP=rg-gapmap-jabar-dev
#   PROJECT_SUFFIX=abc123
#   STORAGE_ACCOUNT_NAME=stgapmapjabarabc123
#   MAPS_ACCOUNT_NAME=maps-gapmap-jabar
#   FUNCTION_APP_NAME=func-gapmap-api
#   STATIC_WEB_APP_NAME=stapp-gapmap-dashboard
#   KEYVAULT_NAME=kv-gapmap-jabar
#   AML_WORKSPACE_NAME=aml-gapmap-jabar
#   AML_COMPUTE_NAME=cpu-cluster-dev
#   GITHUB_REPO_URL=https://github.com/org/repo
#   GITHUB_BRANCH=main
#   GITHUB_TOKEN=<optional token for static web app create>

LOCATION="${LOCATION:-southeastasia}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-gapmap-jabar-dev}"
PROJECT_SUFFIX="${PROJECT_SUFFIX:-$(openssl rand -hex 3)}"

TAGS="project=gapmap env=dev team=datathon2026"

STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME:-stgapmapjabar${PROJECT_SUFFIX}}"
AML_WORKSPACE_NAME="${AML_WORKSPACE_NAME:-aml-gapmap-jabar}"
AML_COMPUTE_NAME="${AML_COMPUTE_NAME:-cpu-cluster-dev}"
MAPS_ACCOUNT_NAME="${MAPS_ACCOUNT_NAME:-maps-gapmap-jabar}"
FUNCTION_PLAN_NAME="${FUNCTION_PLAN_NAME:-plan-gapmap-func-dev}"
FUNCTION_APP_NAME="${FUNCTION_APP_NAME:-func-gapmap-api}"
APPINSIGHTS_NAME="${APPINSIGHTS_NAME:-appi-gapmap-jabar}"
STATIC_WEB_APP_NAME="${STATIC_WEB_APP_NAME:-stapp-gapmap-dashboard}"
KEYVAULT_NAME="${KEYVAULT_NAME:-kv-gapmap-jabar}"

if ! command -v az >/dev/null 2>&1; then
  echo "[ERROR] Azure CLI belum terinstall. Install dulu: https://learn.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi

echo "[INFO] Validasi login Azure..."
if ! az account show >/dev/null 2>&1; then
  echo "[INFO] Belum login. Menjalankan az login..."
  az login >/dev/null
fi

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "[INFO] Subscription aktif: ${SUBSCRIPTION_ID}"
echo "[INFO] Region: ${LOCATION}"

echo "[STEP 1] Membuat Resource Group ${RESOURCE_GROUP}"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags ${TAGS} \
  --output none

echo "[STEP 2] Membuat Storage Account ${STORAGE_ACCOUNT_NAME}"
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access true \
  --min-tls-version TLS1_2 \
  --tags ${TAGS} \
  --output none

STORAGE_ACCOUNT_KEY="$(az storage account keys list \
  --resource-group "${RESOURCE_GROUP}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --query "[0].value" -o tsv)"

echo "[STEP 2] Membuat container blob"
az storage container create --name raw-data --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${STORAGE_ACCOUNT_KEY}" --public-access off --output none
az storage container create --name processed-data --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${STORAGE_ACCOUNT_KEY}" --public-access off --output none
az storage container create --name models --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${STORAGE_ACCOUNT_KEY}" --public-access off --output none
az storage container create --name web-assets --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${STORAGE_ACCOUNT_KEY}" --public-access blob --output none

echo "[STEP 2] Set lifecycle policy: hapus blob raw-data > 90 hari"
POLICY_JSON=$(cat <<'EOF'
{
  "rules": [
    {
      "enabled": true,
      "name": "delete-raw-data-after-90-days",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "delete": {
              "daysAfterModificationGreaterThan": 90
            }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["raw-data/"]
        }
      }
    }
  ]
}
EOF
)

az storage account management-policy create \
  --resource-group "${RESOURCE_GROUP}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --policy "${POLICY_JSON}" \
  --output none

echo "[STEP 3] Menyiapkan Azure ML extension"
az extension add --name ml --upgrade --yes --output none

echo "[STEP 3] Membuat AML Workspace ${AML_WORKSPACE_NAME}"
STORAGE_ACCOUNT_ID="$(az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)"
az ml workspace create \
  --name "${AML_WORKSPACE_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --storage-account "${STORAGE_ACCOUNT_ID}" \
  --tags ${TAGS} \
  --output none

echo "[STEP 3] Membuat AML compute cluster ${AML_COMPUTE_NAME}"
az ml compute create \
  --name "${AML_COMPUTE_NAME}" \
  --type AmlCompute \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${AML_WORKSPACE_NAME}" \
  --size Standard_DS2_v2 \
  --min-instances 0 \
  --max-instances 2 \
  --output none

echo "[STEP 4] Membuat Azure Maps account ${MAPS_ACCOUNT_NAME}"
az maps account create \
  --name "${MAPS_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "global" \
  --sku G2 \
  --kind Gen2 \
  --accept-tos \
  --tags ${TAGS} \
  --output none

AZURE_MAPS_KEY="$(az maps account keys list \
  --name "${MAPS_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query primaryKey -o tsv)"

echo "[STEP 5] Membuat Application Insights ${APPINSIGHTS_NAME}"
az monitor app-insights component create \
  --app "${APPINSIGHTS_NAME}" \
  --location "${LOCATION}" \
  --resource-group "${RESOURCE_GROUP}" \
  --kind web \
  --application-type web \
  --tags ${TAGS} \
  --output none

APPINSIGHTS_CONNECTION_STRING="$(az monitor app-insights component show \
  --app "${APPINSIGHTS_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query connectionString -o tsv)"

echo "[STEP 5] Membuat Function App ${FUNCTION_APP_NAME} (Consumption/Linux)"
az functionapp create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${FUNCTION_APP_NAME}" \
  --storage-account "${STORAGE_ACCOUNT_NAME}" \
  --consumption-plan-location "${LOCATION}" \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --os-type Linux \
  --tags ${TAGS} \
  --output none

az functionapp config appsettings set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${FUNCTION_APP_NAME}" \
  --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=${APPINSIGHTS_CONNECTION_STRING}" \
  --output none

echo "[STEP 6] Menyiapkan extension staticwebapp"
az extension add --name staticwebapp --upgrade --yes --output none

echo "[STEP 6] Membuat Static Web App ${STATIC_WEB_APP_NAME}"
SWA_ARGS=(
  --name "${STATIC_WEB_APP_NAME}"
  --resource-group "${RESOURCE_GROUP}"
  --location "eastasia"
  --sku Free
  --tags ${TAGS}
)

if [[ -n "${GITHUB_TOKEN:-}" ]] && [[ -n "${GITHUB_REPO_URL:-}" ]]; then
  SWA_ARGS+=(
    --source "${GITHUB_REPO_URL}"
    --branch "${GITHUB_BRANCH:-main}"
    --token "${GITHUB_TOKEN}"
    --app-location "/frontend"
    --output-location ".next"
  )
else
  echo "[INFO] GITHUB_TOKEN tidak ditemukan. Static Web App akan dibuat tanpa integrasi GitHub otomatis."
fi

az staticwebapp create "${SWA_ARGS[@]}" --output none

echo "[STEP 7] Membuat Key Vault ${KEYVAULT_NAME}"
if az keyvault show --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "Key Vault ${KEYVAULT_NAME} sudah ada, melewati pembuatan."
else
  az keyvault create \
    --name "${KEYVAULT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku standard \
    --enable-rbac-authorization false \
    --tags ${TAGS} \
    --output none
fi

echo "[STEP 7] Memberi akses Key Vault ke user saat ini"
USER_OID=$(az ad signed-in-user show --query id -o tsv)
az keyvault set-policy --name "${KEYVAULT_NAME}" --object-id "$USER_OID" --secret-permissions all --output none

echo "[STEP 7] Menyimpan secrets ke Key Vault"
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name AZURE-MAPS-KEY --value "${AZURE_MAPS_KEY}" --output none
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name STORAGE-ACCOUNT-KEY --value "${STORAGE_ACCOUNT_KEY}" --output none
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name AML-SUBSCRIPTION-ID --value "${SUBSCRIPTION_ID}" --output none

STORAGE_CONNECTION_STRING="$(az storage account show-connection-string \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --query connectionString -o tsv)"

cat > infra/outputs.env <<EOF
AZURE_RESOURCE_GROUP="${RESOURCE_GROUP}"
AZURE_STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_NAME}"
AZURE_STORAGE_CONNECTION_STRING="${STORAGE_CONNECTION_STRING}"
AZURE_AML_WORKSPACE_NAME="${AML_WORKSPACE_NAME}"
AZURE_MAPS_KEY="${AZURE_MAPS_KEY}"
AZURE_FUNCTION_APP_NAME="${FUNCTION_APP_NAME}"
AZURE_STATIC_WEB_APP_NAME="${STATIC_WEB_APP_NAME}"
AZURE_KEY_VAULT_NAME="${KEYVAULT_NAME}"
AZURE_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"
EOF

echo ""
echo "[DONE] Provisioning selesai."
echo "[INFO] Ringkasan output tersimpan di infra/outputs.env"
echo "[INFO] Tambahkan nilai yang dibutuhkan ke file .env berdasarkan outputs.env"
