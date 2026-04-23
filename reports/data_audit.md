# Data Quality Audit Report

## Dataset: `puskesmas_jabar.csv`

### A. STRUKTUR
- **Jumlah baris dan kolom**: 128 baris, 12 kolom
- **Nama kolom**: osm_id, lat, lon, nama, amenity, healthcare, operator, alamat, kecamatan, kabupaten, provinsi, is_puskesmas
- **Kolom koordinat**: Ya (lat, lon)
- **Kolom wilayah**: Ya (kecamatan, kabupaten)

### B. KELENGKAPAN WILAYAH
- **Kecamatan unik tercakup**: 3 dari 627 (Jabar)
- **Kecamatan TIDAK ada (Top 10)**: BOGORTENGAH, CIMERAK, PURWAKARTA, KABANDUNGAN, SUMEDANGSELATAN, CIKIJING, JONGGOL, DUKUPUNTANG, CISEWU, LEBAKWANGI
- **Inkonsistensi nama**: Ya (contoh: ['Desa Ciberes', 'Tonjong', 'Cikadu'])
### C. KUALITAS DATA
- **Baris null per kolom**: healthcare: 46, operator: 97, alamat: 76, kecamatan: 125, kabupaten: 71, provinsi: 126
- **Duplikat (kolom nama)**: 28 duplikat
- **Koordinat valid**: 100.0%
### D. KEGUNAAN UNTUK ANALISIS
- Bisa buat kalkulasi rasio faskes per 1000 penduduk? Bisa, tinggal join ke data demografi via `kecamatan`/`nama_kecamatan`.
- Kolom kunci JOIN: `kecamatan`

---

## Dataset: `sekolah_jabar.csv`

### A. STRUKTUR
- **Jumlah baris dan kolom**: 6110 baris, 11 kolom
- **Nama kolom**: osm_id, nama_sekolah, jenjang, amenity, lat, lon, kecamatan, kabupaten, provinsi, operator, website
- **Kolom koordinat**: Ya (lat, lon)
- **Kolom wilayah**: Ya (kecamatan, kabupaten)

### B. KELENGKAPAN WILAYAH
- **Kecamatan unik tercakup**: 469 dari 627 (Jabar)
- **Kecamatan TIDAK ada (Top 10)**: BOGORTENGAH, CIMERAK, PURWAKARTA, SUMEDANGSELATAN, KABANDUNGAN, CIKIJING, DUKUPUNTANG, CISEWU, LEBAKWANGI, PAKENJENG
- **Inkonsistensi nama**: Ya (contoh: ['Sagaranten', 'Kotakaler', 'Kayuringin Jaya'])
### C. KUALITAS DATA
- **Baris null per kolom**: nama_sekolah: 975, kecamatan: 2380, kabupaten: 2096, provinsi: 6050, operator: 2241, website: 5999
- **Duplikat (kolom nama_sekolah)**: 1105 duplikat
- **Koordinat valid**: 100.0%
### D. KEGUNAAN UNTUK ANALISIS
- Bisa buat kalkulasi rasio faskes per 1000 penduduk? Bisa, tinggal join ke data demografi via `kecamatan`/`nama_kecamatan`.
- Kolom kunci JOIN: `kecamatan`

---

## Dataset: `pasar_jabar.csv`

### A. STRUKTUR
- **Jumlah baris dan kolom**: 135 baris, 8 kolom
- **Nama kolom**: osm_id, nama_pasar, tipe, lat, lon, alamat, kecamatan, kabupaten
- **Kolom koordinat**: Ya (lat, lon)
- **Kolom wilayah**: Ya (kecamatan, kabupaten)

### B. KELENGKAPAN WILAYAH
- **Kecamatan unik tercakup**: 0 dari 627 (Jabar)
- **Kecamatan TIDAK ada (Top 10)**: BOGORTENGAH, CIMERAK, PURWAKARTA, KABANDUNGAN, SUMEDANGSELATAN, CIKIJING, JONGGOL, DUKUPUNTANG, CISEWU, LEBAKWANGI
- **Inkonsistensi nama**: Tidak ditemukan (berdasarkan sample)

### C. KUALITAS DATA
- **Baris null per kolom**: nama_pasar: 7, alamat: 106, kecamatan: 135, kabupaten: 111
- **Duplikat (kolom nama_pasar)**: 7 duplikat
- **Koordinat valid**: 100.0%
### D. KEGUNAAN UNTUK ANALISIS
- Bisa buat kalkulasi rasio faskes per 1000 penduduk? Nggak bisa, nama kecamatan banyak yang null/nggak ada mapping populasi.
- Kolom kunci JOIN: `kecamatan`

---

## Dataset: `demografi_kecamatan_jabar.csv`

### A. STRUKTUR
- **Jumlah baris dan kolom**: 628 baris, 16 kolom
- **Nama kolom**: kode_kecamatan, nama_kecamatan, nama_kabupaten_kota, nama_provinsi, kode_provinsi, tahun, jumlah_penduduk, penduduk_laki_laki, penduduk_perempuan, luas_wilayah_km2, kepadatan_penduduk_per_km2, pct_usia_0_14, pct_usia_15_64, pct_usia_65_plus, sumber, catatan
- **Kolom koordinat**: Tidak ada
- **Kolom wilayah**: Ya (nama_kecamatan, kode_kecamatan)

### B. KELENGKAPAN WILAYAH
- **Kecamatan unik tercakup**: 581 dari 627 (Jabar)
- **Kecamatan TIDAK ada (Top 10)**: N/A
- **Inkonsistensi nama**: Ya (contoh: ['Arjasari', 'Baleendah', 'Banjaran'])
### C. KUALITAS DATA
- **Baris null per kolom**: Tidak ada
- **Duplikat (kolom None)**: 0 duplikat
- **Koordinat valid**: N/A

### D. KEGUNAAN UNTUK ANALISIS
- Bisa buat base kalkulasi rasio? Bisa, ini emang source of truth demografi.
- Kolom kunci: `kode_kecamatan`, `nama_kecamatan`

---

## Dataset: `puskesmas_jabar_osm_raw.csv`

### A. STRUKTUR
- **Jumlah baris dan kolom**: 128 baris, 11 kolom
- **Nama kolom**: osm_id, lat, lon, nama_puskesmas, amenity, healthcare, operator, alamat, kecamatan, kabupaten, provinsi
- **Kolom koordinat**: Ya (lat, lon)
- **Kolom wilayah**: Ya (kecamatan, kabupaten)

### B. KELENGKAPAN WILAYAH
- **Kecamatan unik tercakup**: 2 dari 627 (Jabar)
- **Kecamatan TIDAK ada (Top 10)**: BOGORTENGAH, CIMERAK, PURWAKARTA, KABANDUNGAN, SUMEDANGSELATAN, CIKIJING, JONGGOL, DUKUPUNTANG, CISEWU, LEBAKWANGI
- **Inkonsistensi nama**: Ya (contoh: ['Desa Ciberes', 'Citarik'])
### C. KUALITAS DATA
- **Baris null per kolom**: healthcare: 46, operator: 97, alamat: 76, kecamatan: 125, kabupaten: 71, provinsi: 126
- **Duplikat (kolom nama_puskesmas)**: 28 duplikat
- **Koordinat valid**: 100.0%
### D. KEGUNAAN UNTUK ANALISIS
- Bisa buat kalkulasi rasio faskes per 1000 penduduk? Bisa, tinggal join ke data demografi via `kecamatan`/`nama_kecamatan`.
- Kolom kunci JOIN: `kecamatan`

---

## 2. Tabel Ringkasan Keputusan

| Dataset | Baris | Kec. tercakup | % null kritis | Koordinat valid | Keputusan |
|---------|-------|---------------|---------------|-----------------|-----------|
| puskesmas_jabar.csv | 128 | 3 | 0.0% | 100.0% | CARI ALTERNATIF |
| sekolah_jabar.csv | 6110 | 469 | 0.0% | 100.0% | PAKAI DENGAN CLEANING |
| pasar_jabar.csv | 135 | 0 | 0.0% | 100.0% | CARI ALTERNATIF |
| demografi_kecamatan_jabar.csv | 628 | 581 | 0.0% | 0.0% | PAKAI |
| puskesmas_jabar_osm_raw.csv | 128 | 2 | 0.0% | 100.0% | CARI ALTERNATIF |

## 3. Daftar Masalah Kritis

1. Dataset demografi_kecamatan_jabar.csv memiliki inkonsistensi nama kecamatan.
2. Dataset pasar_jabar.csv memiliki 7 duplikat nama nama_pasar.
3. Dataset puskesmas_jabar.csv memiliki 28 duplikat nama nama.
4. Dataset sekolah_jabar.csv memiliki inkonsistensi nama kecamatan.
5. Dataset puskesmas_jabar.csv memiliki inkonsistensi nama kecamatan.
6. Dataset sekolah_jabar.csv memiliki 1105 duplikat nama nama_sekolah.
7. Dataset puskesmas_jabar_osm_raw.csv memiliki 28 duplikat nama nama_puskesmas.
8. Dataset puskesmas_jabar_osm_raw.csv memiliki inkonsistensi nama kecamatan.