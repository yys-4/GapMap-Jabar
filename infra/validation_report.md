# Validation Report - GapMap Jabar Azure Infrastructure

- Timestamp (UTC): 2026-04-22T03:15:14Z
- Subscription ID (masked): ********-****-****-****-****7c76
- Validation Script: `infra/validate.sh`

## Actual Output

```text
[FAIL] Resource Group - provisioningState='not-found' | Fix: Pastikan RG ada dan deployment selesai: az group create --name rg-gapmap-jabar-dev --location <region>
[FAIL] Storage Account & Blob Containers - Storage account tidak ditemukan di RG rg-gapmap-jabar-dev | Fix: Buat storage account via infra/deploy.sh atau az storage account create
[FAIL] Azure ML Workspace - az ml workspace show gagal | Fix: Pastikan extension 'ml' terinstall dan user punya akses ke AML workspace
[FAIL] Azure Maps - Gagal ambil AZURE_MAPS_KEY | Fix: Pastikan user punya permission read keys pada Maps account
[FAIL] Azure Functions - Function app func-gapmap-api tidak ditemukan | Fix: Buat function app dulu via infra/deploy.sh
[FAIL] Key Vault - Secret AZURE-MAPS-KEY kosong/tidak bisa dibaca | Fix: Set secret: az keyvault secret set --vault-name kv-gapmap-jabar --name AZURE-MAPS-KEY --value <maps-key>

=== VALIDATION SUMMARY ===
Passed: 0/6
Failed: 6/6
- Resource Group
- Storage Account & Blob Containers
- Azure ML Workspace
- Azure Maps
- Azure Functions
- Key Vault
```

## Notes

**Note:** Semua validasi fail karena base resource di `rg-gapmap-jabar-dev` emang belum diprovision atau belum ke-detect di subscription yang lagi aktif.
