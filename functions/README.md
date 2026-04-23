# Azure Functions — Kecamatan API

## 📝 Overview

Function `get_kecamatan` ini nge-expose REST endpoint buat query data master kecamatan:

```
GET /api/kecamatan?sort=gap_score_composite&limit=50&order=desc
```

Features:
- ✅ Direct load dari Blob Storage (no database)
- ✅ Flexible sorting & limiting
- ✅ Key Vault integration (secure credentials)
- ✅ CORS enabled (Static Web App compatible)
- ✅ Stateless & scalable

## 🚀 Deployment

### Local Testing

```bash
# Install Azure Functions CLI
brew install azure-cli
az login

# Set local environment
export AZURE_STORAGE_CONNECTION_STRING="..."
export KEY_VAULT_URL="https://<vault>.vault.azure.net/"

# Start local runtime
cd functions/
func start

# Test endpoint
curl "http://localhost:7071/api/kecamatan?sort=gap_score_composite&limit=5"
```

### Deploy to Azure

```bash
# Create function app (if not exists)
az functionapp create \
  --resource-group <rg> \
  --consumption-plan-name <plan> \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name <function-app-name>

# Deploy
func azure functionapp publish <function-app-name>

# Test
curl "https://<function-app-name>.azurewebsites.net/api/kecamatan"
```

## 📋 API Reference

### Endpoint
```
GET /api/kecamatan
```

### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sort` | string | `gap_score_composite` | Column to sort by |
| `limit` | int | `50` | Number of results |
| `order` | string | `desc` | `asc` or `desc` |

### Valid Sort Columns
- `gap_score_composite` — Overall gap score
- `gap_demografi` — Demographic gap
- `gap_kesehatan` — Health facility gap
- `kecamatan_std` — Kecamatan name (alphabetic)

### Response

**200 OK**
```json
[
  {
    "kecamatan_std": "Aceh Barat",
    "gap_score_composite": 0.78,
    "gap_demografi": 0.82,
    "gap_kesehatan": 0.75,
    ...
  },
  ...
]
```

**400 Bad Request**
```json
{
  "error": "Invalid sort column. Valid: gap_score_composite, gap_demografi, gap_kesehatan, kecamatan_std"
}
```

**500 Server Error**
```json
{
  "error": "Error description"
}
```

## 📚 Examples

### Top 10 by Gap Score
```
GET /api/kecamatan?sort=gap_score_composite&limit=10&order=desc
```

### Bottom 10 (least gap)
```
GET /api/kecamatan?sort=gap_score_composite&limit=10&order=asc
```

### Top 5 Health Facility Gaps
```
GET /api/kecamatan?sort=gap_kesehatan&limit=5
```

### Kecamatan List (alphabetic)
```
GET /api/kecamatan?sort=kecamatan_std&limit=100&order=asc
```

## 🔒 Security

### Key Vault Integration
Function reads `StorageConnectionString` from Key Vault (not environment):

```python
credential = DefaultAzureCredential()
secret_client = SecretClient(vault_url=key_vault_url, credential=credential)
connection_string = secret_client.get_secret("StorageConnectionString").value
```

### Setup Key Vault Access
1. Create Key Vault
2. Add secret `StorageConnectionString`
3. Assign function app managed identity:
   ```bash
   az functionapp identity assign -g <rg> -n <function-app-name>
   
   az keyvault set-policy -n <vault-name> \
     --secret-permissions get \
     --object-id <managed-identity-id>
   ```

### CORS Headers
Response includes CORS headers untuk Static Web App:
```
Access-Control-Allow-Origin: *
```

## 🛠️ Architecture

```
HTTP Request
    ↓
get_kecamatan (function handler)
    ├─ Parse query params
    ├─ Validate sort column
    ├─ Get blob client (from Key Vault)
    ├─ Load master_kecamatan.csv
    ├─ Sort & limit
    └─ Return JSON + CORS headers
    
Response (JSON array)
```

## 📊 Performance Notes

- **First request:** ~1-2s (blob download + CSV parse)
- **Subsequent requests:** Similar (stateless, no caching)
- **Optimization:** Kalau traffic mulai tinggi, consider pasang Azure Cache for Redis.

## ⚙️ Requirements

```
azure-functions==1.15.0
pandas==2.0.3
azure-storage-blob==12.14.1
azure-keyvault-secrets==4.4.0
azure-identity==1.13.0
```

## 🛑 Troubleshooting

**"KEY_VAULT_URL environment variable tidak ditemukan"**
- Set di Azure function app configuration:
  ```bash
  az functionapp config appsettings set -n <app> -g <rg> \
    --settings KEY_VAULT_URL=https://<vault>.vault.azure.net/
  ```

**"ClientAuthenticationError: Azure CLI not found"**
- Function app managed identity tidak configured
- Run setup Key Vault Access steps above

**"BlobNotFound: The specified blob does not exist"**
- Container atau blob name salah
- Check: `az storage blob list -c processed-data --connection-string "..."`

**Endpoint return 500**
- Check logs: `az functionapp logs tail -n <app> -g <rg>`
- Verify Key Vault permissions

---

**Next Steps:** Integrate dengan Static Web App frontend
