# Diagram Aktivitas Per Fitur (Bahasa Indonesia) - Versi Swimlane

Dokumen ini berisi activity diagram per fitur menggunakan swimlane (partisi) agar peran aktor lebih jelas.

## 1) Registrasi dan Login

```plantuml
@startuml
|Pengguna|
start
:Buka halaman autentikasi;

if (Pilih registrasi?) then (Ya)
  :Isi username dan password;
  |Aplikasi Mobile|
  :Validasi format input;
  |Layanan Autentikasi|
  :Validasi kebijakan akun;
  if (Data valid?) then (Ya)
    :Buat identitas akun;
    :Hash password + salt;
    |Penyimpanan Lokal/Aman|
    :Simpan data akun;
    :Simpan sesi aktif;
    |Aplikasi Mobile|
    :Arahkan ke dashboard;
  else (Tidak)
    |Aplikasi Mobile|
    :Tampilkan pesan kesalahan registrasi;
    stop
  endif
else (Tidak)
  |Pengguna|
  :Isi kredensial login;
  |Aplikasi Mobile|
  :Kirim kredensial ke layanan;
  |Layanan Autentikasi|
  :Verifikasi kredensial;
  if (Kredensial benar?) then (Ya)
    if (Biometrik diwajibkan?) then (Ya)
      |Modul Biometrik|
      :Lakukan verifikasi biometrik;
      if (Biometrik berhasil?) then (Ya)
      else (Tidak)
        |Aplikasi Mobile|
        :Tampilkan login gagal;
        stop
      endif
    else (Tidak)
    endif
    |Penyimpanan Lokal/Aman|
    :Perbarui sesi aktif;
    |Aplikasi Mobile|
    :Arahkan ke dashboard;
  else (Tidak)
    |Aplikasi Mobile|
    :Tampilkan login gagal;
    stop
  endif
endif

|Pengguna|
stop
@enduml
```

## 2) Generate Wallet dan Enkripsi Private Key

```plantuml
@startuml
|Pengguna|
start
:Pilih aksi buat wallet;

|Aplikasi Mobile|
:Minta proses pembuatan wallet;

|Layanan Blockchain|
:Buat pasangan kunci;
:Turunkan alamat wallet dari kunci publik;

|Penyimpanan Aman|
:Ambil material kunci enkripsi;

|Layanan Keamanan|
:Enkripsi private key;

|Penyimpanan Aman|
:Simpan private key terenkripsi;

|Penyimpanan Lokal|
:Simpan alamat wallet;

|Aplikasi Mobile|
:Tampilkan alamat wallet di dashboard;

|Pengguna|
stop
@enduml
```

## 3) Kirim dan Terima ETH

```plantuml
@startuml
|Pengguna|
start

if (Pilih kirim ETH?) then (Ya)
  :Masukkan alamat tujuan dan nominal;
  |Aplikasi Mobile|
  :Validasi format alamat dan saldo awal;
  if (Valid?) then (Ya)
    |Penyimpanan Aman|
    :Ambil private key terenkripsi;
    |Layanan Keamanan|
    :Dekripsi private key sementara;
    |Layanan Blockchain|
    :Buat dan kirim transaksi;
    :Terima hash transaksi;
    |Penyimpanan Lokal|
    :Simpan riwayat transaksi keluar;
    :Perbarui cache saldo;
    |Aplikasi Mobile|
    :Tampilkan status transaksi;
  else (Tidak)
    |Aplikasi Mobile|
    :Tampilkan pesan gagal kirim;
    stop
  endif
else (Tidak)
  |Aplikasi Mobile|
  :Jalankan monitoring saldo/aktivitas;
  |Layanan Blockchain|
  :Ambil sinyal transaksi masuk;
  if (Transaksi masuk terdeteksi?) then (Ya)
    |Penyimpanan Lokal|
    :Simpan riwayat transaksi masuk;
    :Perbarui cache saldo;
    |Layanan Notifikasi|
    :Buat notifikasi penerimaan;
    |Aplikasi Mobile|
    :Tampilkan pembaruan saldo;
  else (Tidak)
    |Aplikasi Mobile|
    :Pertahankan tampilan saat ini;
  endif
endif

|Pengguna|
stop
@enduml
```

## 4) AI Chatbot

```plantuml
@startuml
|Pengguna|
start
:Buka fitur chatbot;
:Kirim pertanyaan;

|Aplikasi Mobile|
:Validasi format dan panjang pesan;
if (Pesan valid?) then (Ya)
  :Bangun konteks percakapan;
  |Layanan AI|
  :Proses prompt;
  :Kembalikan respons;
  |Penyimpanan Lokal|
  :Simpan riwayat tanya-jawab;
  |Aplikasi Mobile|
  :Render jawaban chatbot;
else (Tidak)
  :Tampilkan pesan input tidak valid;
endif

|Pengguna|
stop
@enduml
```

## 5) Hide Saldo

```plantuml
@startuml
|Pengguna|
start
:Tekan tombol tampilkan/sembunyikan saldo;

|Aplikasi Mobile|
if (Saldo sedang terlihat?) then (Ya)
  :Ubah status menjadi tersembunyi;
  :Render placeholder saldo;
else (Tidak)
  :Ubah status menjadi terlihat;
  :Render nilai saldo aktual;
endif

|Penyimpanan Lokal|
:Simpan preferensi visibilitas saldo;

|Pengguna|
stop
@enduml
```

## 6) Mini Game

```plantuml
@startuml
|Pengguna|
start
:Buka mini game;

|Aplikasi Mobile|
:Muat state permainan terakhir;
:Mulai sesi permainan;

while (Permainan selesai?) is (Belum)
  |Pengguna|
  :Berikan input permainan;
  |Aplikasi Mobile|
  :Hitung skor dan progres;
  :Perbarui tampilan permainan;
endwhile (Selesai)

|Penyimpanan Lokal|
:Simpan skor akhir dan metadata sesi;
if (Skor terbaik baru?) then (Ya)
  :Perbarui leaderboard lokal;
else (Tidak)
endif

|Aplikasi Mobile|
:Tampilkan ringkasan hasil permainan;

|Pengguna|
stop
@enduml
```

## 7) Fetch Price

```plantuml
@startuml
|Aplikasi Mobile|
start
:Trigger refresh otomatis/manual;

|Layanan Market Data|
:Ambil data harga terbaru;
if (Respons sukses?) then (Ya)
  :Normalisasi data;
  |Penyimpanan Lokal|
  :Simpan cache harga terbaru;
  |Aplikasi Mobile|
  :Perbarui tampilan harga;
else (Tidak)
  |Penyimpanan Lokal|
  :Ambil cache terakhir (jika ada);
  |Aplikasi Mobile|
  :Tampilkan status gagal ambil data;
endif

stop
@enduml
```

## 8) Konversi Mata Uang

```plantuml
@startuml
|Pengguna|
start
:Pilih mata uang asal dan tujuan;
:Masukkan nominal;

|Aplikasi Mobile|
:Minta kurs terbaru;

|Layanan Kurs/Pricing|
:Sediakan nilai kurs;

|Aplikasi Mobile|
if (Kurs tersedia?) then (Ya)
  :Hitung nilai konversi;
  :Format hasil sesuai locale;
  :Tampilkan hasil konversi;
else (Tidak)
  :Tampilkan pesan kurs tidak tersedia;
endif

|Pengguna|
stop
@enduml
```

## 9) Konversi Waktu

```plantuml
@startuml
|Pengguna|
start
:Pilih zona waktu asal dan tujuan;
:Pilih tanggal dan jam;

|Aplikasi Mobile|
:Validasi input waktu;
if (Input valid?) then (Ya)
  |Layanan Zona Waktu|
  :Sediakan aturan offset dan DST;
  |Aplikasi Mobile|
  :Hitung hasil konversi waktu;
  :Format waktu lokal;
  :Tampilkan hasil konversi;
else (Tidak)
  :Tampilkan pesan input tidak valid;
endif

|Pengguna|
stop
@enduml
```

## 10) LBS (Location-Based Service / Safe Zone)

```plantuml
@startuml
|Pengguna|
start
:Pilih fitur yang membutuhkan validasi lokasi;

|Aplikasi Mobile|
:Minta akses lokasi perangkat;

|Layanan Lokasi OS|
if (Layanan lokasi aktif?) then (Ya)
  :Cek status izin lokasi;
  if (Izin sudah diberikan?) then (Ya)
  else (Tidak)
    :Minta izin lokasi ke pengguna;
    if (Izin diberikan?) then (Ya)
    else (Tidak)
      |Aplikasi Mobile|
      :Tampilkan pesan izin lokasi ditolak;
      |Pengguna|
      stop
    endif
  endif
  :Ambil koordinat terkini;
else (Tidak)
  |Aplikasi Mobile|
  :Tampilkan pesan GPS belum aktif;
  |Pengguna|
  stop
endif

|Aplikasi Mobile|
:Muat konfigurasi zona aman pengguna;

if (Zona pengguna tersedia?) then (Ya)
  |Layanan LBS|
  :Hitung jarak ke setiap zona pengguna;
  if (Berada di salah satu zona?) then (Ya)
    |Aplikasi Mobile|
    :Tandai status lokasi valid;
  else (Tidak)
    |Aplikasi Mobile|
    :Tandai status lokasi tidak valid;
  endif
else (Tidak)
  if (Pengguna pernah konfigurasi zona?) then (Ya)
    :Tandai status lokasi tidak valid;
  else (Tidak)
    |Layanan LBS|
    :Hitung jarak ke zona default sistem;
    if (Berada di zona default?) then (Ya)
      |Aplikasi Mobile|
      :Tandai status lokasi valid;
    else (Tidak)
      |Aplikasi Mobile|
      :Tandai status lokasi tidak valid;
    endif
  endif
endif

|Aplikasi Mobile|
:Tampilkan hasil validasi lokasi ke pengguna;

|Pengguna|
stop
@enduml
```
