# Azure ML Notebook — EDA & Validation di Cloud

## 📝 Overview

Notebook `01_eda_azure.ipynb` ini starter notebook buat:
- 🔌 Koneksi ke Azure Blob Storage
- 📥 Load data (CSV + GeoJSON) langsung ke memory
- 🔀 Merge tabular + geospasial data
- ✅ Validasi consistency
- 📊 Visualisasi gap score distribution

## 🚀 Quick Start

### Setup di Azure ML Studio

1. Open Azure ML workspace
2. Create new notebook
3. Copy content dari `./notebooks/01_eda_azure.ipynb`
4. OR upload file langsung

### Set Environment Variable

Sebelum nge-run, pastiin Compute Instance udah ke-set environment variable-nya:

```bash
# Di Azure ML terminal
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointProtocol=https;..."
```

Atau set di Compute Instance "Environment Variables" section.

## 📓 Cells Breakdown

### Cell 1: Setup Koneksi
```python
from azure.storage.blob import BlobServiceClient
import os

blob_client = BlobServiceClient.from_connection_string(
    os.environ["AZURE_STORAGE_CONNECTION_STRING"]
)
```
**Output:** `✅ Connected to Azure Blob Storage`

### Cell 2: Helper Function
Setup `read_blob_csv()` buat load CSV dari blob langsung ke memory (ngehindari disk I/O)

### Cell 3: Load Master Data
```python
df = read_blob_csv("processed-data", "master_kecamatan.csv")
print(f"✅ Loaded {len(df)} kecamatan")
df.head()
```
**Shows:** Columns, data types, first 5 rows

### Cell 4: Load GeoJSON
```python
gdf = gpd.read_file(io.BytesIO(geo_data))
print(f"✅ Loaded {len(gdf)} features (kecamatan boundaries)")
```
**Shows:** CRS, geometry type, feature count

### Cell 5: Merge Data
Joins geospatial + tabular data using `kecamatan_std` key
**Shows:** Match rate, unmatched kecamatan

### Cell 6: Sanity Check Gap Score
```python
print(f"Matched: {matched} / {total} kecamatan")
merged[["gap_score_composite", "gap_demografi", "gap_kesehatan"]].describe()
```
**Shows:** Statistics, top gaps, missing data

### Cell 7: Visualisasi Map
```python
merged.plot(column="gap_score_composite", cmap="RdYlGn_r", ...)
plt.savefig("./outputs/gap_score_map.png", dpi=150)
```
**Output:** Choropleth map saved as PNG

## 📊 Expected Output

```
✅ Connected to Azure Blob Storage
✅ Helper function ready
✅ Loaded 627 kecamatan
✅ Loaded 627 features (kecamatan boundaries)
✅ Merge selesai
Matched: 627 / 627 kecamatan (100.0%)
✅ Map saved to ./outputs/gap_score_map.png
```

## 🔄 Data Flow

```
Blob Storage (raw-data)
    └─ batas_kecamatan_jabar.geojson
    
Blob Storage (processed-data)
    └─ master_kecamatan.csv
    
Download to Memory
    ├─ GeoDataFrame (gdf)
    └─ DataFrame (df)
    
Merge & Validate
    └─ merged = gdf.merge(df, ...)
    
Visualize & Save
    └─ ./outputs/gap_score_map.png
```

## 🛠️ Customization

### Change Colormap
Replace `cmap="RdYlGn_r"` dengan:
- `"viridis"` — blue→yellow
- `"plasma"` — purple→yellow
- `"coolwarm"` — blue→red

### Change Sort Column
Ubah `sort_values(by="gap_score_composite")` ke:
- `"gap_demografi"`
- `"gap_kesehatan"`
- Any column dari df

### Add More Data
Load file lain dari blob:
```python
demografi_df = read_blob_csv("raw-data", "demografi_kecamatan_jabar.csv")
merged = merged.merge(demografi_df, on="kecamatan_std", how="left")
```

## ⚙️ Requirements

```
pandas==2.0.3
geopandas==0.12.1
matplotlib==3.7.1
shapely==2.0.1
azure-storage-blob==12.14.1
azure-identity==1.13.0
```

Install di Azure ML:
```bash
pip install -r notebooks/requirements.txt
```

## 🛑 Troubleshooting

**ImportError: No module named 'geopandas'**
```bash
pip install geopandas
```

**AZURE_STORAGE_CONNECTION_STRING not found**
- Set env var: `export AZURE_STORAGE_CONNECTION_STRING="..."`
- Or paste directly: `os.environ["AZURE_STORAGE_CONNECTION_STRING"] = "..."`

**Timeout saat download geojson**
- File lumayan gede, jadi butuh waktu. Pastiin koneksi stabil.

**Merge result 0 rows**
- Cek key kolom buat join: `print(gdf.columns)`, `print(df.columns)`
- Kolom `kecamatan_std` mesti exact match (termasuk case-sensitive).

---

**Next Steps:** Deploy functions atau share output map dengan team
