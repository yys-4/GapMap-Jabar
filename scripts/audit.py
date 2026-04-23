import pandas as pd
import glob
import os
import re

files = [
    '/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/puskesmas_jabar.csv',
    '/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/sekolah_jabar.csv',
    '/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/pasar_jabar.csv',
    '/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/demografi_kecamatan_jabar.csv',
    '/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/puskesmas_jabar_osm_raw.csv'
]

baseline_df = pd.read_csv('/Users/muhammadayyas/Documents/public-gap-distribution/data/raw/demografi_kecamatan_jabar.csv')
all_kec_baseline = set(baseline_df['nama_kecamatan'].astype(str).str.strip().str.upper())

report_lines = ["# Data Quality Audit Report\n"]

summary_data = []
critical_issues = set()

def clean_name(s):
    if pd.isna(s): return ""
    return str(s).strip().upper()

for f in files:
    df = pd.read_csv(f)
    fname = os.path.basename(f)
    report_lines.append(f"## Dataset: `{fname}`\n")
    
    # A. STRUKTUR
    rows, cols = df.shape
    col_names = list(df.columns)
    
    coord_cols = [c for c in ['lat', 'lon', 'latitude', 'longitude'] if c in col_names]
    has_coord = len(coord_cols) > 0
    
    reg_cols = [c for c in ['kecamatan', 'nama_kecamatan', 'kode_kecamatan', 'kabupaten', 'kode_bps'] if c in col_names]
    has_reg = len(reg_cols) > 0
    
    report_lines.append("### A. STRUKTUR")
    report_lines.append(f"- **Jumlah baris dan kolom**: {rows} baris, {cols} kolom")
    report_lines.append(f"- **Nama kolom**: {', '.join(col_names)}")
    report_lines.append(f"- **Kolom koordinat**: {'Ya (' + ', '.join(coord_cols) + ')' if has_coord else 'Tidak ada'}")
    report_lines.append(f"- **Kolom wilayah**: {'Ya (' + ', '.join(reg_cols) + ')' if has_reg else 'Tidak ada'}\n")
    
    # B. KELENGKAPAN WILAYAH
    kec_col = None
    for c in ['kecamatan', 'nama_kecamatan']:
        if c in col_names:
            kec_col = c
            break
            
    coverage_kec = 0
    missing_10 = []
    inconsistencies = []
    if kec_col:
        unique_kec = df[kec_col].dropna().apply(clean_name).unique()
        coverage_kec = len(unique_kec)
        
        # Missing
        missing = list(all_kec_baseline - set(unique_kec))
        missing_10 = missing[:10]
        
        # Inconsistent names (contain prefix etc)
        for k in df[kec_col].dropna().unique():
            if str(k).startswith("Kec.") or str(k).lower() != str(k):
                inconsistencies.append(k)
    else:
        critical_issues.add(f"Dataset {fname} tidak memiliki kolom kecamatan yang bisa digunakan untuk join.")
                
    report_lines.append("### B. KELENGKAPAN WILAYAH")
    report_lines.append(f"- **Kecamatan unik tercakup**: {coverage_kec} dari 627 (Jabar)")
    report_lines.append(f"- **Kecamatan TIDAK ada (Top 10)**: {', '.join(missing_10) if missing_10 else 'N/A'}")
    if len(inconsistencies) > 0:
        report_lines.append(f"- **Inkonsistensi nama**: Ya (contoh: {inconsistencies[:3]})")
        critical_issues.add(f"Dataset {fname} memiliki inkonsistensi nama kecamatan.")
    else:
        report_lines.append("- **Inkonsistensi nama**: Tidak ditemukan (berdasarkan sample)\n")
        
    # C. KUALITAS DATA
    null_counts = df.isnull().sum()
    nulls = [f"{k}: {v}" for k, v in null_counts.items() if v > 0]
    
    dup_col = None
    for c in ['nama', 'nama_sekolah', 'nama_pasar', 'nama_puskesmas']:
        if c in col_names:
            dup_col = c
            break
            
    dups = 0
    if dup_col:
        dups = df.duplicated(subset=[dup_col]).sum()
        if dups > 0:
            critical_issues.add(f"Dataset {fname} memiliki {dups} duplikat nama {dup_col}.")
            
    valid_coord_pct = 0
    if has_coord and 'lat' in col_names and 'lon' in col_names:
        valid_coords = df[(df['lat'] >= -8) & (df['lat'] <= -5) & (df['lon'] >= 106) & (df['lon'] <= 109)]
        valid_coord_pct = len(valid_coords) / rows * 100 if rows > 0 else 0
        if valid_coord_pct < 50 and fname != 'demografi_kecamatan_jabar.csv':
            critical_issues.add(f"Dataset {fname} persentase koordinat valid sangat rendah ({valid_coord_pct:.1f}%).")
            
    crit_null_pct = 0
    if 'lat' in col_names:
        crit_null_pct = df['lat'].isnull().sum() / rows * 100
        
    report_lines.append("### C. KUALITAS DATA")
    report_lines.append(f"- **Baris null per kolom**: {', '.join(nulls) if nulls else 'Tidak ada'}")
    report_lines.append(f"- **Duplikat (kolom {dup_col})**: {dups} duplikat")
    if has_coord:
        report_lines.append(f"- **Koordinat valid**: {valid_coord_pct:.1f}%")
    else:
        report_lines.append("- **Koordinat valid**: N/A\n")
        
    # D. KEGUNAAN UNTUK ANALISIS
    report_lines.append("### D. KEGUNAAN UNTUK ANALISIS")
    if fname == 'demografi_kecamatan_jabar.csv':
        report_lines.append("- Cukup untuk dasar rasio? Ya, ini adalah data demografi.")
        report_lines.append("- Kolom kunci: `kode_kecamatan`, `nama_kecamatan`")
        decision = "PAKAI"
    else:
        # Faskes?
        if 'puskesmas' in fname.lower() or 'sekolah' in fname.lower() or 'pasar' in fname.lower():
            if coverage_kec > 0 and 'jumlah_penduduk' not in col_names: # Needs demografi
                report_lines.append("- Cukup untuk rasio faskes per 1000 penduduk? Ya, jika di-join dengan demografi menggunakan kolom `kecamatan`/`nama_kecamatan`.")
            else:
                report_lines.append("- Cukup untuk rasio faskes per 1000 penduduk? Tidak, nama kecamatan hilang atau tidak ada data populasi.")
        
        report_lines.append(f"- Kolom kunci JOIN: `{kec_col}`" if kec_col else "TIDAK ADA KOLOM JOIN!")
        
        # Decision logic
        if crit_null_pct > 80 or valid_coord_pct < 10 or coverage_kec < 10:
            decision = "CARI ALTERNATIF"
        elif crit_null_pct > 0 or valid_coord_pct < 90 or len(inconsistencies) > 0 or dups > 0:
            decision = "PAKAI DENGAN CLEANING"
        else:
            decision = "PAKAI"
            
    summary_data.append(f"| {fname} | {rows} | {coverage_kec} | {crit_null_pct:.1f}% | {valid_coord_pct:.1f}% | {decision} |")
    report_lines.append("\n---\n")

report_lines.append("## 2. Tabel Ringkasan Keputusan\n")
report_lines.append("| Dataset | Baris | Kec. tercakup | % null kritis | Koordinat valid | Keputusan |")
report_lines.append("|---------|-------|---------------|---------------|-----------------|-----------|")
for s in summary_data:
    report_lines.append(s)

report_lines.append("\n## 3. Daftar Masalah Kritis\n")
if critical_issues:
    for i, issue in enumerate(critical_issues, 1):
        report_lines.append(f"{i}. {issue}")
else:
    report_lines.append("- Tidak ada masalah kritis yang mencegah analisis lanjut.")

with open('/Users/muhammadayyas/Documents/public-gap-distribution/reports/data_audit.md', 'w') as f:
    f.write('\n'.join(report_lines))
