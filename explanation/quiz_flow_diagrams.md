# Diagram Alur Kuis

Dokumen ini berisi diagram sequence dan activity untuk alur kuis. Istilah yang dipakai dibuat umum dan tidak menyebut nama fungsi.

## 1) Sequence Diagram

```plantuml
@startuml
actor Pengguna
participant "Layar Kuis" as UI
participant "Sumber Soal" as BankSoal
participant "Penyimpanan Per Sesi" as Storage
participant "Penyedia Status" as State

Pengguna -> UI : Membuka kuis
UI -> BankSoal : Meminta kumpulan soal acak
BankSoal --> UI : Mengirim daftar soal
UI -> UI : Menampilkan soal pertama dan progres awal

loop Untuk setiap soal
  Pengguna -> UI : Memilih salah satu jawaban
  UI -> UI : Mengevaluasi jawaban
  alt Jawaban benar
    UI -> UI : Menambah skor dan rangkaian benar
  else Jawaban salah
    UI -> UI : Menghentikan rangkaian benar
  end
  UI -> UI : Menampilkan umpan balik dan penjelasan
  UI -> UI : Menyiapkan soal berikutnya
end

UI -> Storage : Menyimpan hasil akhir permainan
UI -> State : Memperbarui nilai skor dan total sesi
UI --> Pengguna : Menampilkan ringkasan hasil

opt Memulai ulang kuis
  Pengguna -> UI : Meminta sesi baru
  UI -> BankSoal : Meminta kumpulan soal baru
  BankSoal --> UI : Mengirim daftar soal baru
  UI -> UI : Mereset status permainan
end
@enduml
```

## 2) Activity Diagram

```plantuml
@startuml
start
:Pengguna membuka kuis;
:Layar kuis meminta kumpulan soal acak;
:Soal pertama ditampilkan;

while (Masih ada soal?) is (Ya)
  :Pengguna memilih jawaban;
  :Sistem memeriksa jawaban;

  if (Jawaban benar?) then (Ya)
    :Skor bertambah;
    :Rangkaian benar meningkat;
  else (Tidak)
    :Rangkaian benar direset;
  endif

  :Umpan balik dan penjelasan ditampilkan;
  :Progres berpindah ke soal berikutnya;
endwhile (Tidak)

:Hasil akhir disimpan;
:Nilai skor dan jumlah sesi diperbarui;
:Ringkasan hasil ditampilkan;

if (Pengguna ingin mengulang?) then (Ya)
  :Ambil kumpulan soal baru;
  :Reset status permainan;
  :Kembali ke awal sesi;
else (Tidak)
  :Kembali ke layar sebelumnya;
endif

stop
@enduml
```
