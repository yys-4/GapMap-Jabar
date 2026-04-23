#!/usr/bin/env python3
"""
Script untuk mengkonversi file XLSX BPS Jabar → CSV standar untuk analisis.

Cara pakai:
1. Download XLSX dari: https://jabar.bps.go.id/id/statistics-table/2/MTAzIzI=/jumlah-penduduk-menurut-kecamatan-di-provinsi-jawa-barat.html
2. Simpan sebagai: data/raw/demografi_kecamatan_jabar_bps.xlsx
3. Jalankan: python3 scripts/convert_bps_xlsx.py
"""

import os
import sys

try:
    import openpyxl
except ImportError:
    os.system("pip3 install openpyxl --quiet")
    import openpyxl

import csv

XLSX_PATH = "data/raw/demografi_kecamatan_jabar_bps.xlsx"
CSV_PATH = "data/raw/demografi_kecamatan_jabar.csv"

if not os.path.exists(XLSX_PATH):
    print(f"❌ File tidak ditemukan: {XLSX_PATH}")
    print()
    print("Silakan download manual dari:")
    print("  https://jabar.bps.go.id/id/statistics-table/2/MTAzIzI=/jumlah-penduduk-menurut-kecamatan-di-provinsi-jawa-barat.html")
    print("  → Pilih tahun 2022/2023 → Klik XLSX → Simpan ke data/raw/demografi_kecamatan_jabar_bps.xlsx")
    sys.exit(1)

print(f"📂 Membuka {XLSX_PATH}...")
wb = openpyxl.load_workbook(XLSX_PATH, read_only=True, data_only=True)
ws = wb.active

rows = list(ws.iter_rows(values_only=True))
print(f"Total rows: {len(rows)}")
print(f"Header row (first 3 rows):")
for r in rows[:3]:
    print(f"  {r}")

# Find actual header row (usually row 2-4 in BPS format)
# BPS format typically: row 1 = title, row 2 = blank, row 3 = headers
header_row = None
data_rows = []

for i, row in enumerate(rows):
    non_empty = [v for v in row if v is not None]
    if len(non_empty) >= 3 and any(isinstance(v, str) and ('kecamatan' in str(v).lower() or 'kode' in str(v).lower() or 'jumlah' in str(v).lower() or 'penduduk' in str(v).lower()) for v in non_empty):
        header_row = i
        print(f"Found header at row {i+1}: {row}")
        break

if header_row is None:
    print("Tidak bisa auto-detect header. Menggunakan row ke-4 sebagai header.")
    header_row = 3

headers = [str(v).strip() if v else f"col_{j}" for j, v in enumerate(rows[header_row])]
print(f"\nHeaders: {headers}")

# Read data rows
output_rows = []
for row in rows[header_row + 1:]:
    if any(v is not None for v in row):
        rowdict = dict(zip(headers, [str(v).strip() if v is not None else '' for v in row]))
        # Skip rows that look like subtitles/footers
        first_val = str(list(rowdict.values())[0]).lower()
        if any(x in first_val for x in ['catatan', 'sumber', 'note', 'keterangan']):
            continue
        output_rows.append(rowdict)

print(f"\nData rows found: {len(output_rows)}")
print("Sample:")
for r in output_rows[:3]:
    print(f"  {r}")

with open(CSV_PATH, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    writer.writerows(output_rows)

print(f"\n✅ Berhasil disimpan ke {CSV_PATH} ({len(output_rows)} records)")
