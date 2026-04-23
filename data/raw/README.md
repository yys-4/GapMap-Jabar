# Data Raw - Distribusi Fasilitas Publik Gap Analysis Jawa Barat

**Tanggal pengunduhan:** 20 April 2026  
**Disiapkan untuk:** Kompetisi Datathon - Gap Analysis Fasilitas Publik Jawa Barat

## Daftar Dataset

| File | Records | Ukuran | Sumber | Catatan |
|------|---------|--------|--------|---------|
| `demografi_kecamatan_jabar.csv` | 628 kecamatan | 136 KB | BPS Jabar + GADM | Lihat catatan |
| `puskesmas_jabar.csv` | 128 titik | 16 KB | OpenStreetMap Overpass | Koordinat lengkap |
| `sekolah_jabar.csv` | 6.110 sekolah | 496 KB | OpenStreetMap Overpass | SD/SMP/SMA/SMK |
| `batas_kecamatan_jabar.geojson` | 628 poligon | 1,05 MB | GADM 4.1 | ADM3 kecamatan |
| `pasar_jabar.csv` | 135 titik | 10 KB | OpenStreetMap Overpass | Pasar tradisional |

---

## Detail Dataset

### 1. demografi_kecamatan_jabar.csv
**Kolom:**
- `kode_kecamatan` – Kode BPS kecamatan (7 digit)
- `nama_kecamatan` – Nama kecamatan
- `nama_kabupaten_kota` – Nama kabupaten/kota
- `nama_provinsi` – "Jawa Barat"
- `kode_provinsi` – "32"
- `tahun` – 2022
- `jumlah_penduduk` – Total penduduk
- `penduduk_laki_laki` – Penduduk laki-laki
- `penduduk_perempuan` – Penduduk perempuan
- `luas_wilayah_km2` – Luas wilayah dalam km²
- `kepadatan_penduduk_per_km2` – Kepadatan penduduk
- `pct_usia_0_14` – % usia 0-14 tahun
- `pct_usia_15_64` – % usia produktif
- `pct_usia_65_plus` – % usia lansia

> ⚠️ **Methodology Note:** Base data populasi per kabupaten diambil dari BPS Jabar Dalam Angka 2023. Buat breakdown per kecamatan kita pakai estimasi proporsional soalnya API BPS kecamatan kena blok Cloudflare. Kalau butuh yang bener-bener presisi, mending pull manual/scraping dari BPS kabupaten masing-masing.

### 2. puskesmas_jabar.csv
**Sumber:** OpenStreetMap via Overpass API  
**Kolom:** osm_id, lat, lon, nama, amenity, healthcare, operator, alamat, kecamatan, kabupaten, provinsi

> ⚠️ **Heads up:** Data puskesmas dari OSM ini cuma parsial (cuma dapet 128 titik). Total puskesmas di Jabar itu ada 1000+. Kalau mau data valid/lengkap, mending narik langsung dari API Kemenkes atau Open Data Jabar.

### 3. sekolah_jabar.csv
**Sumber:** OpenStreetMap via Overpass API  
**Jenjang dideteksi:** SD (2.312), SMP (1.138), SMA/SMK (993), PT (97)  
**Kolom:** osm_id, nama_sekolah, jenjang, amenity, lat, lon, kecamatan, kabupaten, provinsi, operator

### 4. batas_kecamatan_jabar.geojson
**Sumber:** GADM 4.1 (Global Administrative Areas, UC Davis, CC BY 4.0)  
**Cakupan:** 628 kecamatan, 27 kabupaten/kota  
**Format:** GeoJSON, CRS WGS84  
**Kolom properties:** kode_kecamatan, nama_kecamatan, nama_kabupaten, nama_provinsi, GID_3, tipe

### 5. pasar_jabar.csv
**Sumber:** OpenStreetMap via Overpass API  
**Kolom:** osm_id, nama_pasar, tipe, lat, lon, alamat, kecamatan, kabupaten

---

## Sumber Data

| Dataset | URL Sumber | Lisensi |
|---------|------------|---------|
| Batas Kecamatan | https://geodata.ucdavis.edu/gadm/gadm4.1/ | CC BY 4.0 |
| Puskesmas & Sekolah & Pasar | https://overpass-api.de (OpenStreetMap) | ODbL |
| Demografi (referensi) | https://jabar.bps.go.id | © BPS |

## File Pendukung (Tidak di-include karena ukuran besar)
- `gadm41_IDN_3.json` – GeoJSON seluruh Indonesia ADM3 (13 MB)
- `idn_health_facilities.zip` – SHP fasilitas kesehatan RT Indonesia (HDX, 2019)
