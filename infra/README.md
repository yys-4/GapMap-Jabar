# Setup Infrastruktur Azure - GapMap-Jabar

Panduan setup infrastruktur Azure dari nol sampai siap run buat project GapMap-Jabar.

## Arsitektur Resource

Resource yang diprovision (berurutan):

1. Resource Group: rg-gapmap-jabar-dev
2. Storage Account + Blob containers:
   - raw-data (private)
   - processed-data (private)
   - models (private)
   - web-assets (public blob)
   - lifecycle policy: delete raw-data > 90 hari
3. Azure Machine Learning Workspace + compute cluster
4. Azure Maps Account (G2)
5. Azure Functions App (Python 3.11, Consumption) + Application Insights
6. Azure Static Web Apps (Free)
7. Azure Key Vault + 3 secrets

## Prerequisite

- Azure CLI terinstall
- Sudah login ke Azure
- Subscription aktif
- Permission minimal Contributor pada subscription atau resource group target
- Untuk deploy Static Web App via GitHub, siapkan URL repo

Buat sanity check:

```bash
az version
az login
az account show --output table
```

## Naming Convention

Naming convention ngikutin guideline standard Azure (Cloud Adoption Framework):
https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming

**Notes:**
- Storage Account, Function App, Key Vault, & Static Web App butuh nama yang global-unique.
- Di script udah dikasih suffix random otomatis buat Storage Account.
- Kalau ada conflict pas create resource, tinggal override aja lewat env var.

## Opsi A - Deploy pakai Azure CLI Script (Direkomendasikan)

File: infra/deploy.sh

### 1) Jalankan script default

```bash
chmod +x infra/deploy.sh
./infra/deploy.sh
```

Saat step Static Web App, script akan minta input URL GitHub repo jika belum diisi.

### 2) Jalankan dengan override variabel

```bash
LOCATION=southeastasia \
RESOURCE_GROUP=rg-gapmap-jabar-dev \
PROJECT_SUFFIX=dev001 \
STORAGE_ACCOUNT_NAME=stgapmapjabardev001 \
FUNCTION_APP_NAME=func-gapmap-api-dev001 \
STATIC_WEB_APP_NAME=stapp-gapmap-dashboard-dev001 \
KEYVAULT_NAME=kv-gapmap-jabar-dev001 \
GITHUB_REPO_URL=https://github.com/ORG/REPO \
GITHUB_BRANCH=main \
./infra/deploy.sh
```

Opsional jika butuh token GitHub untuk provisioning SWA:

```bash
GITHUB_TOKEN=ghp_xxx ./infra/deploy.sh
```

### 3) Output hasil deploy

Setelah selesai, script membuat file:

- infra/outputs.env

Isi file ini bisa dipakai untuk mengisi variabel aplikasi.

## Opsi B - Deploy pakai Bicep

File: infra/main.bicep

### 1) Deploy ke resource group

```bash
az group create \
  --name rg-gapmap-jabar-dev \
  --location southeastasia \
  --tags project=gapmap env=dev team=datathon2026

az deployment group create \
  --resource-group rg-gapmap-jabar-dev \
  --template-file infra/main.bicep
```

### 2) Deploy dengan parameter override

```bash
az deployment group create \
  --resource-group rg-gapmap-jabar-dev \
  --template-file infra/main.bicep \
  --parameters \
      location=southeastasia \
      storageAccountName=stgapmapjabarabc123 \
      functionAppName=func-gapmap-api-abc123 \
      staticWebAppName=stapp-gapmap-dashboard-abc123 \
      keyVaultName=kv-gapmap-jabar-abc123
```

## Integrasi Environment Variable Project

Template env sudah disiapkan di file root:

- .env.example

Variabel yang perlu diisi:

- AZURE_STORAGE_CONNECTION_STRING
- AZURE_MAPS_KEY
- AZURE_AML_WORKSPACE_NAME
- AZURE_RESOURCE_GROUP
- NEXT_PUBLIC_AZURE_MAPS_KEY

Sumber value:
- AZURE_STORAGE_CONNECTION_STRING: dari infra/outputs.env
- AZURE_MAPS_KEY: dari infra/outputs.env atau Key Vault secret AZURE-MAPS-KEY
- AZURE_AML_WORKSPACE_NAME: aml-gapmap-jabar (atau override yang dipakai)
- AZURE_RESOURCE_GROUP: rg-gapmap-jabar-dev
- NEXT_PUBLIC_AZURE_MAPS_KEY: sama dengan AZURE_MAPS_KEY untuk kebutuhan frontend

## Verifikasi Setelah Deploy

Jalankan cek ini untuk memastikan semua komponen up:

```bash
az resource list --resource-group rg-gapmap-jabar-dev --output table
az ml workspace show -g rg-gapmap-jabar-dev -n aml-gapmap-jabar --output table
az ml compute show -g rg-gapmap-jabar-dev -w aml-gapmap-jabar -n cpu-cluster-dev --output table
az maps account show -g rg-gapmap-jabar-dev -n maps-gapmap-jabar --output table
az functionapp show -g rg-gapmap-jabar-dev -n func-gapmap-api --output table
az staticwebapp show -g rg-gapmap-jabar-dev -n stapp-gapmap-dashboard --output table
az keyvault secret show --vault-name kv-gapmap-jabar --name AZURE-MAPS-KEY --query id -o tsv
```

## Estimasi Biaya (Mode Hemat)

- Storage: Standard_LRS (murah)
- AML compute: min nodes 0, max 2 (scale-to-zero)
- Functions: Consumption plan
- Static Web App: Free SKU
- Azure Maps: G2 free-tier eligible

Pantau terus Cost Management ya, jaga-jaga kalau limit free tier-nya update/tembus.
