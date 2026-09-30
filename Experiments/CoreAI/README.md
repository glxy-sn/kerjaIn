# Eksperimen Core AI untuk kerjaIn

Executable Swift terpisah untuk mencoba tahap ekstraksi requirement dari job description
dengan model Qwen melalui **Core AI**, memakai adapter `CoreAILanguageModel` dan
`LanguageModelSession`. Aplikasi utama tetap memakai MLX.

## Prasyarat

- Mac Apple Silicon, macOS 27+, Xcode 27+.
- Model hasil ekspor Core AI: folder resource lengkap, bukan hanya file `.aimodel`
  atau checkpoint MLX.
- Internet untuk unduhan awal dependensi dan model.

## Build

Jalankan dari folder ini:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift build -c release
```

Variabel ini hanya memilih Xcode untuk terminal tersebut; tidak mengubah `xcode-select`
global. Versi toolkit Apple dikunci ke revision di `Package.swift` dan dependensi
transitif dicatat di `Package.resolved`.

## Menyiapkan model

Gunakan [toolkit resmi Apple](https://github.com/apple/coreai-models) dengan `uv`:

```sh
git clone https://github.com/apple/coreai-models.git /tmp/kerjain-coreai-export
cd /tmp/kerjain-coreai-export
git checkout 3efa838ebf1a1e816ef4c17eb5022fe22cda2cb9
uv run --no-default-groups coreai.llm.export Qwen/Qwen3-4B --compression 4bit --output-dir /Users/shafatiara/Documents/Challenge3/kerjaIn/Experiments/CoreAI/models
```

Ekspor pertama mengunduh dependensi Python dan checkpoint model; sediakan beberapa GB
ruang disk. Gunakan **folder resource hasil ekspor** yang dilaporkan exporter sebagai
argumen pertama saat menjalankan eksperimen.

## Menjalankan

Dari folder eksperimen:

```sh
.build/release/coreai-experiment --help
.build/release/coreai-experiment models/qwen3_4b_4bit_dynamic sample-job.txt
```

Argumen kedua bisa diganti dengan file UTF-8 berisi lowonganmu. Output JSON mencatat
`mustHaveSkills`, `niceToHaveSkills`, `jobTitle`, waktu loading, waktu generasi, dan
apakah input terpotong. Output mentah model ditulis ke stderr untuk diagnosis.

Contoh ini membatasi input ke 2.000 karakter seperti extractor aplikasi, dengan
temperature 0,1 dan maksimum 700 token output. JSON yang tidak valid menghasilkan
exit code 1, bukan hasil sukses palsu. Waktu loading memisahkan pemuatan model dari
generasi; waktu generasi mencakup pemrosesan prompt. Cache sistem dapat memengaruhi
hasil, sehingga satu run bukan benchmark menyeluruh.

## Yang perlu diamati

Untuk `sample-job.txt`, hasil seharusnya mengenali judul `iOS Developer`, membedakan
Swift/SwiftUI/Git/komunikasi sebagai requirement, serta SwiftData/XCTest sebagai
preferensi. JSON valid saja belum membuktikan ketepatan semantik.

Model utama eksperimen sekarang adalah **Qwen3 4B dengan bobot 4-bit**, setara
dalam keluarga model dan jumlah parameter dengan `mlx-community/Qwen3-4B-4bit`
yang dipakai aplikasi. Ekspor Core AI berasal dari `Qwen/Qwen3-4B` menggunakan
preset `4bit`. Metode quantization kedua runtime tidak identik, sehingga hasil
bobot dan ukuran file dapat berbeda. Prompt eksperimen juga masih berbeda dari
extractor aplikasi; hasil ini belum merupakan benchmark langsung Core AI versus MLX.
Model 0.6B tetap disimpan sebagai smoke test awal.

Model, hasil lokal, dan output build diabaikan oleh Git. Belum ada integrasi ke UI,
perubahan penyimpanan, atau migrasi pipeline aplikasi utama.

## Hasil uji awal — 30 September 2026

- Build release berhasil menggunakan Xcode 27.0 (27A266a), macOS 27.0 (26A428).
- Qwen3 0.6B berhasil diekspor dengan preset default macOS 4-bit; folder resource
  sekitar 331 MB di disk.
- Inference pada `sample-job.txt` berhasil: load 5,84 detik, generasi 4,89 detik
  dalam satu run. Angka ini bukan perbandingan dengan MLX.
- JSON valid: judul `iOS Developer`, wajib `Swift`, `SwiftUI`, `Git`, dan opsional
  `SwiftData`, `XCTestCase`.
- Keterbatasan hasil: model melewatkan komunikasi tertulis yang diwajibkan dan
  mengganti istilah `XCTest` menjadi `XCTestCase`. Ini smoke test teknis yang sukses,
  tetapi ketepatan ekstraksinya belum memenuhi semua isi fixture.
- Help, argumen tidak lengkap, direktori model hilang, file input hilang, dan input
  kosong sudah diperiksa; input tidak valid keluar dengan kode 1.
- Runtime menulis ke `~/Library/Caches/coreai-cache`; eksekusi dalam sandbox agent
  memerlukan izin cache tambahan. Uji inference dilakukan setelah izin diberikan.

## Model setara MLX — Qwen3 4B, 4-bit

- Ekspor `Qwen/Qwen3-4B` dengan `--compression 4bit` berhasil pada 30 September 2026.
  Checkpoint sumber: `1cfa9a7208912126459214e8b04321603b3df60c`.
- Resource tersedia lokal di `models/qwen3_4b_4bit_dynamic`, sekitar 2,1 GB di disk.
  Metadata mencatat compression `4bit` dan maksimum konteks 40.960 token.
- Executable yang sama berhasil menjalankan `sample-job.txt`: loading 11,61 detik,
  generasi 1,72 detik pada satu run. Tidak ada perubahan prompt atau kode inference.
- JSON valid: judul `iOS Developer`; wajib `Swift`, `SwiftUI`, `Git`,
  `clear written communication`; opsional `SwiftData`, `automated testing using XCTest`.
  Semua requirement dalam fixture ini terwakili, termasuk komunikasi yang terlewat
  pada uji awal 0.6B.
- Hasil satu fixture belum membuktikan kualitas umum atau keunggulan performa atas MLX.

Model 4B dan 0.6B sudah tersedia lokal. Tidak perlu mengulang ekspor untuk mencoba
executable yang sudah dibangun pada mesin ini.

Referensi: [resep Qwen3 Apple](https://github.com/apple/coreai-models/tree/main/models/qwen3).
