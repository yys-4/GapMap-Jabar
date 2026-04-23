#!/usr/bin/env bash
set -uo pipefail

# Comprehensive validation script for GapMap-Jabar Azure infrastructure.

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-gapmap-jabar-dev}"
EXPECTED_CONTAINERS=(raw-data processed-data models web-assets)
FUNCTION_APP_NAME="${FUNCTION_APP_NAME:-func-gapmap-api}"
KEYVAULT_NAME="${KEYVAULT_NAME:-kv-gapmap-jabar}"
AML_WORKSPACE_NAME="${AML_WORKSPACE_NAME:-aml-gapmap-jabar}"
AML_COMPUTE_NAME="${AML_COMPUTE_NAME:-cpu-cluster-dev}"
MAPS_ACCOUNT_NAME="${MAPS_ACCOUNT_NAME:-maps-gapmap-jabar}"

PASSED=0
FAILED=0
declare -a FAILED_ITEMS=()

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

print_ok() {
  local name="$1"
  local detail="$2"
  echo "[OK]  ${name} - ${detail}"
}

print_fail() {
  local name="$1"
  local detail="$2"
  local fix="$3"
  echo "[FAIL] ${name} - ${detail} | Fix: ${fix}"
}

record_pass() {
  PASSED=$((PASSED + 1))
}

record_fail() {
  local item="$1"
  FAILED=$((FAILED + 1))
  FAILED_ITEMS+=("${item}")
}

ensure_az() {
  if ! command -v az >/dev/null 2>&1; then
    echo "Azure CLI tidak ditemukan. Install dulu: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl tidak ditemukan. Install curl lalu jalankan ulang."
    exit 1
  fi

  if ! command -v zip >/dev/null 2>&1; then
    echo "zip tidak ditemukan. Install zip lalu jalankan ulang."
    exit 1
  fi

  if ! az account show >/dev/null 2>&1; then
    echo "Belum login Azure. Jalankan 'az login' dulu."
    exit 1
  fi
}

discover_resource_name() {
  local type="$1"
  local fallback="$2"
  local discovered=""

  discovered="$(az resource list -g "${RESOURCE_GROUP}" --resource-type "${type}" --query "[0].name" -o tsv 2>/dev/null || true)"
  if [[ -n "${discovered}" ]]; then
    echo "${discovered}"
  else
    echo "${fallback}"
  fi
}

check_resource_group() {
  local check_name="Resource Group"
  local state
  state="$(az group show --name "${RESOURCE_GROUP}" --query properties.provisioningState -o tsv 2>/dev/null || true)"

  if [[ "${state}" == "Succeeded" ]]; then
    print_ok "${check_name}" "${RESOURCE_GROUP} provisioningState=${state}"
    record_pass
  else
    print_fail "${check_name}" "provisioningState='${state:-not-found}'" "Pastikan RG ada dan deployment selesai: az group create --name ${RESOURCE_GROUP} --location <region>"
    record_fail "${check_name}"
  fi
}

check_storage_and_containers() {
  local check_name="Storage Account & Blob Containers"
  local account_name
  local account_key
  local missing=()
  local c
  local test_file="${TEMP_DIR}/test.txt"
  local downloaded_file="${TEMP_DIR}/test_downloaded.txt"
  local blob_name="validation/test-$(date +%s).txt"

  account_name="$(discover_resource_name "Microsoft.Storage/storageAccounts" "")"
  if [[ -z "${account_name}" ]]; then
    print_fail "${check_name}" "Storage account tidak ditemukan di RG ${RESOURCE_GROUP}" "Buat storage account via infra/deploy.sh atau az storage account create"
    record_fail "${check_name}"
    return
  fi

  account_key="$(az storage account keys list --resource-group "${RESOURCE_GROUP}" --account-name "${account_name}" --query "[0].value" -o tsv 2>/dev/null || true)"
  if [[ -z "${account_key}" ]]; then
    print_fail "${check_name}" "Gagal ambil storage account key" "Pastikan permission cukup (Storage Account Key Operator/Contributor)"
    record_fail "${check_name}"
    return
  fi

  for c in "${EXPECTED_CONTAINERS[@]}"; do
    if ! az storage container exists --name "${c}" --account-name "${account_name}" --account-key "${account_key}" --query exists -o tsv 2>/dev/null | grep -qi '^true$'; then
      missing+=("${c}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    print_fail "${check_name}" "Container tidak ditemukan: ${missing[*]}" "Buat container yang kurang: az storage container create --name <container> --account-name ${account_name} --account-key <key>"
    record_fail "${check_name}"
    return
  fi

  echo "gapmap-test" > "${test_file}"

  if ! az storage blob upload --account-name "${account_name}" --account-key "${account_key}" --container-name raw-data --name "${blob_name}" --file "${test_file}" --overwrite --output none 2>/dev/null; then
    print_fail "${check_name}" "Upload test blob ke raw-data gagal" "Pastikan akun storage bisa write ke container raw-data"
    record_fail "${check_name}"
    return
  fi

  if ! az storage blob download --account-name "${account_name}" --account-key "${account_key}" --container-name raw-data --name "${blob_name}" --file "${downloaded_file}" --output none 2>/dev/null; then
    print_fail "${check_name}" "Download test blob dari raw-data gagal" "Cek network rule storage account dan permission data plane"
    az storage blob delete --account-name "${account_name}" --account-key "${account_key}" --container-name raw-data --name "${blob_name}" --output none >/dev/null 2>&1 || true
    record_fail "${check_name}"
    return
  fi

  local content
  content="$(cat "${downloaded_file}" 2>/dev/null || true)"
  az storage blob delete --account-name "${account_name}" --account-key "${account_key}" --container-name raw-data --name "${blob_name}" --output none >/dev/null 2>&1 || true

  if [[ "${content}" == "gapmap-test" ]]; then
    print_ok "${check_name}" "storage=${account_name}, 4 container ada, upload/download/delete blob sukses"
    record_pass
  else
    print_fail "${check_name}" "Konten file hasil download tidak sesuai" "Cek integritas upload/download dan enkripsi/transit storage"
    record_fail "${check_name}"
  fi
}

check_aml_workspace() {
  local check_name="Azure ML Workspace"
  local ws_name compute_name ws_status compute_status notebook_file data_name

  ws_name="$(discover_resource_name "Microsoft.MachineLearningServices/workspaces" "${AML_WORKSPACE_NAME}")"
  if [[ -z "${ws_name}" ]]; then
    print_fail "${check_name}" "Workspace AML tidak ditemukan" "Buat workspace: az ml workspace create ..."
    record_fail "${check_name}"
    return
  fi

  az extension add --name ml --upgrade --yes --output none >/dev/null 2>&1 || true

  ws_id="$(az ml workspace show --name "${ws_name}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv 2>/dev/null || true)"
  if [[ -z "${ws_id}" ]]; then
    print_fail "${check_name}" "az ml workspace show gagal" "Pastikan extension 'ml' terinstall dan user punya akses ke AML workspace"
    record_fail "${check_name}"
    return
  fi
  ws_status="Succeeded"

  compute_name="$(az ml compute list --resource-group "${RESOURCE_GROUP}" --workspace-name "${ws_name}" --query "[0].name" -o tsv 2>/dev/null || true)"
  if [[ -z "${compute_name}" ]]; then
    compute_name="${AML_COMPUTE_NAME}"
  fi

  compute_status="$(az ml compute show --name "${compute_name}" --resource-group "${RESOURCE_GROUP}" --workspace-name "${ws_name}" --query provisioning_state -o tsv 2>/dev/null || true)"

  if [[ "${ws_status}" != "Succeeded" || "${compute_status}" != "Succeeded" ]]; then
    print_fail "${check_name}" "workspace=${ws_name}(${ws_status:-unknown}), compute=${compute_name}(${compute_status:-unknown})" "Pastikan AML workspace dan compute cluster provisioned selesai"
    record_fail "${check_name}"
    return
  fi

  notebook_file="${TEMP_DIR}/validation_notebook.ipynb"
  cat > "${notebook_file}" <<'EOF'
{
  "cells": [
    {
      "cell_type": "markdown",
      "metadata": {},
      "source": [
        "# GapMap Validation Notebook\\n",
        "Notebook test upload dari infra/validate.sh"
      ]
    }
  ],
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    },
    "language_info": {
      "name": "python"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
EOF

  data_name="validation-notebook-$(date +%s)"
  if az ml data create \
    --name "${data_name}" \
    --version 1 \
    --type uri_file \
    --path "${notebook_file}" \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${ws_name}" \
    --description "Validation notebook upload test" \
    --output none >/dev/null 2>&1; then
    print_ok "${check_name}" "workspace=${ws_name}, compute=${compute_name}, upload notebook test sukses"
    record_pass
  else
    print_fail "${check_name}" "Upload notebook test ke AML gagal" "Cek quota/storage workspace, role assignment AML, dan coba ulang az ml data create"
    record_fail "${check_name}"
  fi
}

check_azure_maps() {
  local check_name="Azure Maps"
  local maps_name key status_code body_file result_count

  maps_name="$(discover_resource_name "Microsoft.Maps/accounts" "${MAPS_ACCOUNT_NAME}")"
  if [[ -z "${maps_name}" ]]; then
    print_fail "${check_name}" "Maps account tidak ditemukan" "Buat maps account: az maps account create ..."
    record_fail "${check_name}"
    return
  fi

  key="$(az maps account keys list --name "${maps_name}" --resource-group "${RESOURCE_GROUP}" --query primaryKey -o tsv 2>/dev/null || true)"
  if [[ -z "${key}" ]]; then
    print_fail "${check_name}" "Gagal ambil AZURE_MAPS_KEY" "Pastikan user punya permission read keys pada Maps account"
    record_fail "${check_name}"
    return
  fi

  body_file="${TEMP_DIR}/maps_response.json"
  status_code="$(curl -sS -o "${body_file}" -w "%{http_code}" "https://atlas.microsoft.com/search/address/json?api-version=1.0&query=Bandung&subscription-key=${key}" || true)"

  if [[ "${status_code}" != "200" ]]; then
    print_fail "${check_name}" "HTTP status ${status_code}" "Cek key Maps, SKU account, dan outbound internet connectivity"
    record_fail "${check_name}"
    return
  fi

  result_count="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("results", [])))' "${body_file}" 2>/dev/null || echo 0)"

  if [[ "${result_count}" =~ ^[0-9]+$ ]] && (( result_count > 0 )); then
    print_ok "${check_name}" "HTTP 200, jumlah hasil geocoding=${result_count}"
    record_pass
  else
    print_fail "${check_name}" "response results kosong" "Cek query geocoding, key validity, dan limit/kuota Maps"
    record_fail "${check_name}"
  fi
}

check_azure_functions() {
  local check_name="Azure Functions"
  local function_name="health"
  local build_dir="${TEMP_DIR}/funcapp"
  local zip_file="${TEMP_DIR}/funcapp.zip"
  local endpoint status_code body_file response

  if ! az functionapp show --name "${FUNCTION_APP_NAME}" --resource-group "${RESOURCE_GROUP}" --query name -o tsv >/dev/null 2>&1; then
    print_fail "${check_name}" "Function app ${FUNCTION_APP_NAME} tidak ditemukan" "Buat function app dulu via infra/deploy.sh"
    record_fail "${check_name}"
    return
  fi

  mkdir -p "${build_dir}/${function_name}"

  cat > "${build_dir}/requirements.txt" <<'EOF'
azure-functions
EOF

  cat > "${build_dir}/host.json" <<'EOF'
{
  "version": "2.0"
}
EOF

  cat > "${build_dir}/${function_name}/function.json" <<'EOF'
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get"],
      "route": "health"
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
EOF

  cat > "${build_dir}/${function_name}/__init__.py" <<'EOF'
import azure.functions as func


def main(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse('{"status": "ok"}', mimetype="application/json", status_code=200)
EOF

  (
    cd "${build_dir}"
    zip -qr "${zip_file}" .
  )

  if ! az functionapp deployment source config-zip --resource-group "${RESOURCE_GROUP}" --name "${FUNCTION_APP_NAME}" --src "${zip_file}" --output none >/dev/null 2>&1; then
    print_fail "${check_name}" "Deploy function health-check gagal" "Cek kudu/scm availability dan permission deploy ke Function App"
    record_fail "${check_name}"
    return
  fi

  echo "Menunggu Function App up (30 detik)..."
  sleep 30

  endpoint="https://${FUNCTION_APP_NAME}.azurewebsites.net/api/health"
  body_file="${TEMP_DIR}/function_response.json"
  status_code="$(curl -sS -o "${body_file}" -w "%{http_code}" "${endpoint}" || true)"
  response="$(cat "${body_file}" 2>/dev/null || true)"

  if [[ "${status_code}" == "200" && "${response}" == '{"status": "ok"}' ]]; then
    print_ok "${check_name}" "deploy + hit endpoint sukses (${endpoint})"
    record_pass
  else
    print_fail "${check_name}" "Endpoint check gagal: status=${status_code}, body=${response}" "Cek log functionapp (az functionapp log tail), authLevel route, dan restart app"
    record_fail "${check_name}"
  fi
}

check_key_vault() {
  local check_name="Key Vault"
  local kv_name secret_value

  kv_name="${KEYVAULT_NAME}"
  if [[ -z "${kv_name}" ]]; then
    print_fail "${check_name}" "Key Vault tidak ditemukan" "Buat key vault via infra/deploy.sh"
    record_fail "${check_name}"
    return
  fi

  secret_value="$(az keyvault secret show --vault-name "${kv_name}" --name "AZURE-MAPS-KEY" --query value -o tsv 2>/dev/null || true)"

  if [[ -n "${secret_value}" ]]; then
    print_ok "${check_name}" "Secret AZURE-MAPS-KEY terbaca dan tidak kosong"
    record_pass
  else
    print_fail "${check_name}" "Secret AZURE-MAPS-KEY kosong/tidak bisa dibaca" "Set secret: az keyvault secret set --vault-name ${kv_name} --name AZURE-MAPS-KEY --value <maps-key>"
    record_fail "${check_name}"
  fi
}

print_summary() {
  echo ""
  echo "=== VALIDATION SUMMARY ==="
  echo "Passed: ${PASSED}/6"
  echo "Failed: ${FAILED}/6"
  if (( FAILED > 0 )); then
    local item
    for item in "${FAILED_ITEMS[@]}"; do
      echo "- ${item}"
    done
  fi
}

main() {
  ensure_az

  check_resource_group
  check_storage_and_containers
  check_aml_workspace
  check_azure_maps
  check_azure_functions
  check_key_vault
  print_summary

  if (( FAILED > 0 )); then
    exit 1
  fi
}

main "$@"