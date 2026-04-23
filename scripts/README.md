# Upload Script — Transfer Data ke Azure Blob Storage

## 📝 Overview

Script `upload_data.py` handle transfer data dari lokal ke Azure Blob Storage. Fitur:
- ✅ Progress tracking per-file
- ✅ Verification (download size check)
- ✅ Manifest generation (metadata upload)
- ✅ Connection string dari environment (secure)

## 🚀 Usage

```bash
# Set environment variable
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointProtocol=https;..."

# Run script
python scripts/upload_data.py

# Output
🚀 Mulai upload data ke Azure Blob Storage...

📦 Container: raw-data
  Uploading demografi_kecamatan_jabar.csv... done (245.3 KB)
  Uploading puskesmas_jabar.csv... done (89.2 KB)
  ...

✅ Upload selesai!
📄 Manifest tersimpan: ./infra/upload_manifest.json
📊 Total files: 6
💾 Total size: 1245.8 KB
```

## 📂 Files Uploaded

### raw-data container
- `demografi_kecamatan_jabar.csv` — Data demografi kecamatan
- `puskesmas_jabar.csv` — Data puskesmas
- `sekolah_jabar.csv` — Data sekolah
- `batas_kecamatan_jabar.geojson` — Boundary kecamatan (geospasial)

### processed-data container
- `master_kecamatan.csv` — Master data (sudah processed)
- `top_50_gap_kecamatan.csv` — Top 50 gap kecamatan

## 🔒 Security

Connection string diload dari **env var** buat security (jangan pernah hardcode!):

```python
connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
if not connection_string:
    raise ValueError("AZURE_STORAGE_CONNECTION_STRING env var tidak ditemukan")
```

Never commit connection strings ke repo!

## 📊 Manifest Output

Generate `./infra/upload_manifest.json` setelah upload kelar:

```json
{
  "uploaded_at": "2026-04-22T14:30:45.123456Z",
  "files": [
    {
      "name": "master_kecamatan.csv",
      "size_kb": 245.3,
      "blob_url": "https://gapmabjaber.blob.core.windows.net/processed-data/master_kecamatan.csv"
    },
    ...
  ]
}
```

Kegunaan manifest:
- Tracking timestamp upload
- Simpan actual file size (post-upload)
- Reference blob URL

## ⚙️ Requirements

```
azure-storage-blob==12.14.1
```

## 🛠️ Troubleshooting

**"AZURE_STORAGE_CONNECTION_STRING env var tidak ditemukan"**
- Belum set env var. Run: `export AZURE_STORAGE_CONNECTION_STRING="..."`

**"Upload verification failed: local X KB != remote Y KB"**
- Network error/file corrupt pas upload. Retry aja.

**"File tidak ditemukan: data/raw/..."**
- File lokal nggak exist. Double-check path pakai `ls data/raw/` atau `ls data/processed/`

---

**Next Steps:** Run notebook di Azure ML atau deploy functions
