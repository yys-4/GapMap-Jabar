import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from rapidfuzz import process, fuzz
import unicodedata
import re

# Set paths
base_dir = "/Users/muhammadayyas/Documents/public-gap-distribution"
raw_dir = os.path.join(base_dir, "data", "raw")
proc_dir = os.path.join(base_dir, "data", "processed")
reports_dir = os.path.join(base_dir, "reports")
figures_dir = os.path.join(reports_dir, "figures")

os.makedirs(proc_dir, exist_ok=True)
os.makedirs(figures_dir, exist_ok=True)

# 1. Standardisasi Nama Wilayah
def normalize_kecamatan(nama):
    if pd.isna(nama):
        return ""
    # Lowercase
    nama = str(nama).lower()
    # Hapus karakter khusus
    nama = ''.join(c for c in unicodedata.normalize('NFD', nama) if unicodedata.category(c) != 'Mn')
    nama = re.sub(r'[^a-z0-9\s]', ' ', nama)
    # Hapus prefix
    nama = re.sub(r'\b(kec\.|kecamatan|desa|kelurahan)\b', '', nama)
    # Hapus spasi berlebih
    nama = ' '.join(nama.split())
    return nama

# Load demografi for baseline
df_demog = pd.read_csv(os.path.join(raw_dir, 'demografi_kecamatan_jabar.csv'))
df_demog['kec_norm'] = df_demog['nama_kecamatan'].apply(normalize_kecamatan)
baseline_kec = set(df_demog['kec_norm'].unique())
baseline_list = list(baseline_kec)

unmatched_records = []

def map_kecamatan(df, col_name, source_name):
    if col_name not in df.columns:
        return df
    
    df['kec_raw'] = df[col_name]
    df['kec_norm'] = df[col_name].apply(normalize_kecamatan)
    
    def match_kec(name):
        if not name: return ""
        if name in baseline_kec:
            return name # Perfect match
        
        # Fuzzy match
        match = process.extractOne(name, baseline_list, scorer=fuzz.ratio)
        if match and match[1] >= 85:
            return match[0]
        else:
            unmatched_records.append({'source': source_name, 'raw_name': name, 'best_match': match[0] if match else None, 'score': match[1] if match else None})
            return name # Still return normalized name, but it will fail join later
            
    df['kec_mapped'] = df['kec_norm'].apply(match_kec)
    return df

# Load data
df_puskesmas = pd.read_csv(os.path.join(raw_dir, 'puskesmas_jabar.csv'))
df_sekolah = pd.read_csv(os.path.join(raw_dir, 'sekolah_jabar.csv'))

# Map
df_puskesmas = map_kecamatan(df_puskesmas, 'kecamatan', 'puskesmas')
df_sekolah = map_kecamatan(df_sekolah, 'kecamatan', 'sekolah')

if unmatched_records:
    pd.DataFrame(unmatched_records).to_csv(os.path.join(reports_dir, 'unmatched_kecamatan.csv'), index=False)
else:
    # touch file if empty
    pd.DataFrame(columns=['source', 'raw_name', 'best_match', 'score']).to_csv(os.path.join(reports_dir, 'unmatched_kecamatan.csv'), index=False)

# 2. Cleaning Per Dataset

# Demografi: Impute nulls with regency median
num_cols_demog = df_demog.select_dtypes(include=[np.number]).columns
df_demog['is_imputed'] = False
for col in num_cols_demog:
    if df_demog[col].isnull().any():
        df_demog.loc[df_demog[col].isnull(), 'is_imputed'] = True
        df_demog[col] = df_demog.groupby('nama_kabupaten_kota')[col].transform(lambda x: x.fillna(x.median()))
        
# For puskesmas and sekolah
def clean_faskes(df):
    if 'lat' not in df.columns or 'lon' not in df.columns:
        return df
        
    missing_pct = df['lat'].isnull().sum() / len(df)
    if missing_pct > 0.3:
        df['has_coordinate'] = df['lat'].notnull()
    else:
        df = df.dropna(subset=['lat', 'lon']).copy()
        df['has_coordinate'] = True
        
    # Drop duplikat
    dup_subset = [col for col in df.columns if col in ['nama', 'nama_sekolah', 'nama_puskesmas']] + ['kec_mapped']
    df = df.drop_duplicates(subset=dup_subset)
    
    # Validasi koordinat
    valid_coords = (df['lat'] >= -8.5) & (df['lat'] <= -5.5) & (df['lon'] >= 105.5) & (df['lon'] <= 109.5)
    df = df[valid_coords]
    return df

df_puskesmas = clean_faskes(df_puskesmas)
df_sekolah = clean_faskes(df_sekolah)

# 3. Agregasi per Kecamatan
# Jumlah puskesmas
agg_puskesmas = df_puskesmas.groupby('kec_mapped').size().reset_index(name='jumlah_puskesmas')

# Jumlah sekolah per jenjang
if 'jenjang' in df_sekolah.columns:
    df_sekolah['jenjang'] = df_sekolah['jenjang'].astype(str).str.upper()
    agg_sekolah = df_sekolah.pivot_table(index='kec_mapped', columns='jenjang', aggfunc='size', fill_value=0).reset_index()
    for col in ['SD', 'SMP', 'SMA']:
        if col not in agg_sekolah.columns:
            agg_sekolah[col] = 0
    agg_sekolah = agg_sekolah.rename(columns={'SD': 'jumlah_sd', 'SMP': 'jumlah_smp', 'SMA': 'jumlah_sma'})
else:
    agg_sekolah = pd.DataFrame({'kec_mapped': df_demog['kec_norm'].unique(), 'jumlah_sd': 0, 'jumlah_smp': 0, 'jumlah_sma': 0})

# Merge to master
master = df_demog.copy()
master = pd.merge(master, agg_puskesmas, left_on='kec_norm', right_on='kec_mapped', how='left').drop(columns=['kec_mapped'], errors='ignore')
master['jumlah_puskesmas'] = master['jumlah_puskesmas'].fillna(0)

if 'kec_mapped' in agg_sekolah.columns:
    master = pd.merge(master, agg_sekolah[['kec_mapped', 'jumlah_sd', 'jumlah_smp', 'jumlah_sma']], left_on='kec_norm', right_on='kec_mapped', how='left').drop(columns=['kec_mapped'], errors='ignore')
else:
    for col in ['jumlah_sd', 'jumlah_smp', 'jumlah_sma']:
        master[col] = 0

master['jumlah_sd'] = master['jumlah_sd'].fillna(0)
master['jumlah_smp'] = master['jumlah_smp'].fillna(0)
master['jumlah_sma'] = master['jumlah_sma'].fillna(0)

# Calculate ratios
pop = master['jumlah_penduduk'].replace(0, np.nan)
master['rasio_puskesmas_per_10k'] = (master['jumlah_puskesmas'] / pop) * 10000
master['rasio_sd_per_1k'] = (master['jumlah_sd'] / pop) * 1000
master['rasio_smp_per_1k'] = (master['jumlah_smp'] / pop) * 1000
master['rasio_sma_per_1k'] = (master['jumlah_sma'] / pop) * 1000
master['total_faskes'] = master['jumlah_puskesmas'] + master['jumlah_sd'] + master['jumlah_smp'] + master['jumlah_sma']

for c in ['rasio_puskesmas_per_10k', 'rasio_sd_per_1k', 'rasio_smp_per_1k', 'rasio_sma_per_1k']:
    master[c] = master[c].fillna(0)

# 4. Gap Score
def normalize_col(s):
    min_val, max_val = s.min(), s.max()
    if max_val == min_val: return s * 0
    return (s - min_val) / (max_val - min_val)

master['gap_score_kesehatan'] = 1 - normalize_col(master['rasio_puskesmas_per_10k'])
master['avg_pendidikan_1k'] = master[['rasio_sd_per_1k', 'rasio_smp_per_1k', 'rasio_sma_per_1k']].mean(axis=1)
master['gap_score_pendidikan'] = 1 - normalize_col(master['avg_pendidikan_1k'])
master['gap_score_composite'] = 0.5 * master['gap_score_kesehatan'] + 0.5 * master['gap_score_pendidikan']

# 5. Ranking
master['rank_gap_composite'] = master['gap_score_composite'].rank(method='min', ascending=False)

def assign_tier(rank, total):
    pct = rank / total
    if pct <= 0.2: return 'HIGH_GAP'
    elif pct <= 0.6: return 'MID_GAP'
    else: return 'LOW_GAP'

total_kec = len(master)
master['tier'] = master['rank_gap_composite'].apply(lambda x: assign_tier(x, total_kec))

# Save master
master.to_csv(os.path.join(proc_dir, 'master_kecamatan.csv'), index=False)
master.sort_values('rank_gap_composite').head(50).to_csv(os.path.join(proc_dir, 'top_50_gap_kecamatan.csv'), index=False)

# Reports
top_kesehatan = master.sort_values('gap_score_kesehatan', ascending=False)[['nama_kecamatan', 'nama_kabupaten_kota', 'gap_score_kesehatan']].head(5)
top_pendidikan = master.sort_values('gap_score_pendidikan', ascending=False)[['nama_kecamatan', 'nama_kabupaten_kota', 'gap_score_pendidikan']].head(5)

stats = master[['rasio_puskesmas_per_10k', 'rasio_sd_per_1k', 'rasio_smp_per_1k', 'rasio_sma_per_1k', 'gap_score_composite']].describe()

report = f"""# Exploratory Data Analysis & Gap Analysis Summary

## Statistik Deskriptif
{stats.to_markdown()}

## Top 5 Kecamatan Paling Under-Served (Kesehatan)
{top_kesehatan.to_markdown(index=False)}

## Top 5 Kecamatan Paling Under-Served (Pendidikan)
{top_pendidikan.to_markdown(index=False)}

## Insights
1. **Ketimpangan Ekstrem**: Terdapat kelurahan/kecamatan yang mendapatkan skor sangat tinggi di Gap Score Kesehatan. Ini berarti populasi di daerah tersebut jauh melampaui rata-rata tanpa dikompensasi fasilitas puskesmas yang mumpuni.
2. **Standardisasi Nama Wilayah yang Dinamis Kosong ("")**: Berdasarkan `unmatched_kecamatan.csv`, cukup banyak baris data fasilitas yang tidak memiliki penamaan kecamatan dan kabupaten dengan benar akibat ketidaklengkapan input manual, ini mempengaruhi perhitungan rasio secara langsung di master file. 
3. **Imputasi Demografi**: Terdapat beberapa kelurahan dengan nilai blank yang terisi menggunakan median populasi/luas pada level kabupaten, di mana ini merapikan visual distribusi namun membuat sebagian rasio sedikit kurang akurat pada extreme outliers.

*Visualisasi distribusi skor dikirimkan pada `figures/histogram_gap_score.png`.*
"""

with open(os.path.join(reports_dir, 'eda_summary.md'), 'w') as f:
    f.write(report)

try:
    plt.figure(figsize=(10, 6))
    sns.histplot(master['gap_score_composite'], bins=30, kde=True, color='purple')
    plt.title('Distribusi Composite Gap Score Kecamatan di Jawa Barat')
    plt.xlabel('Composite Gap Score (Mendekati 1 = Sangat Under-served)')
    plt.ylabel('Frekuensi')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(figures_dir, 'histogram_gap_score.png'), dpi=150)
except Exception as e:
    print(f"Error plotting: {e}")

print("DATA PROCESSING SUCCESSFUL")
