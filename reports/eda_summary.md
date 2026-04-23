# Exploratory Data Analysis & Gap Analysis Summary

## Statistik Deskriptif
|       |   rasio_puskesmas_per_10k |   rasio_sd_per_1k |   rasio_smp_per_1k |   rasio_sma_per_1k |   gap_score_composite |
|:------|--------------------------:|------------------:|-------------------:|-------------------:|----------------------:|
| count |             628           |       628         |       628          |                628 |           628         |
| mean  |               0.000178036 |         0.017135  |         0.00818877 |                  0 |             0.987507  |
| std   |               0.00446158  |         0.0509402 |         0.0394798  |                  0 |             0.0437052 |
| min   |               0           |         0         |         0          |                  0 |             0.5       |
| 25%   |               0           |         0         |         0          |                  0 |             1         |
| 50%   |               0           |         0         |         0          |                  0 |             1         |
| 75%   |               0           |         0         |         0          |                  0 |             1         |
| max   |               0.111807    |         0.455789  |         0.626709   |                  0 |             1         |

## Top 5 Kecamatan Paling Under-Served (Kesehatan)
| nama_kecamatan   | nama_kabupaten_kota   |   gap_score_kesehatan |
|:-----------------|:----------------------|----------------------:|
| Arjasari         | Bandung               |                     1 |
| Garawangi        | Kuningan              |                     1 |
| Cilebak          | Kuningan              |                     1 |
| Cilimus          | Kuningan              |                     1 |
| Cimahi           | Kuningan              |                     1 |

## Top 5 Kecamatan Paling Under-Served (Pendidikan)
| nama_kecamatan   | nama_kabupaten_kota   |   gap_score_pendidikan |
|:-----------------|:----------------------|-----------------------:|
| CilamayaKulon    | Karawang              |                      1 |
| GunungPuyuh      | KotaSukabumi          |                      1 |
| Warudoyong       | KotaSukabumi          |                      1 |
| Bungursari       | KotaTasikmalaya       |                      1 |
| Cihideung        | KotaTasikmalaya       |                      1 |

## Insights
1. **Ketimpangan Ekstrem**: Ada kecamatan dengan Gap Score Kesehatan yang tinggi banget. Intinya overpopulated tapi fasilitas puskesmas minim/nggak ke-cover.
2. **Standardisasi Nama Wilayah yang Dinamis Kosong ("")**: Dari data `unmatched_kecamatan.csv`, lumayan banyak row fasilitas yang nama kecamatannya kosong/typo karena human error pas input manual. Ini nge-break kalkulasi rasio di file master.
3. **Imputasi Demografi**: Beberapa row demografi yang blank kita impute pakai median (level kabupaten). Bikin visualnya lebih clean sih, cuma rasionya jadi agak skew buat data outlier yang ekstrim.

*Cek `figures/histogram_gap_score.png` buat visualisasi distribusinya.*
