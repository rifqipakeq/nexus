import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review TPM')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '''Kesan:
Menjalani mata kuliah ini memberikan banyak pengalaman baru yang sangat berkesan bagi kami. Proses pengerjaan proyek akhir NexusNode benar-benar memberikan gambaran nyata tentang bagaimana rasanya membangun sebuah aplikasi. Meskipun prosesnya cukup menantang dan banyak menyita waktu serta pikiran.

Pesan: 
Terima kasih kepada Bapak Bagus Muhammad Akbar atas bimbingan dan standar tinggi yang diberikan. Hal tersebut memotivasi kami untuk menghasilkan proyek NexusNode yang melampaui ekspektasi kami sendiri.

Saran:

Saran pertama yang ingin kami sampaikan untuk ke depannya adalah mengenai ketersediaan modul atau materi pembelajaran tambahan. Kami merasa bahwa akan sangat membantu sekali bagi mahasiswa jika modul-modul panduan yang diberikan bisa lebih diperbanyak lagi, terutama untuk bagian-bagian yang membahas konsep-konsep yang tingkat kesulitannya cukup tinggi. Kami sering kali merasa butuh referensi yang lebih detail dan mudah diikuti supaya kami tidak terlalu lama terjebak dalam kebingungan saat mencoba memahami materi yang baru. Dengan adanya tambahan contoh-contoh praktis atau panduan langkah demi langkah yang lebih banyak, proses belajar kami tentu akan menjadi jauh lebih efektif dan kami bisa lebih fokus pada pengembangan kualitas hasil kerja kami tanpa harus menghabiskan terlalu banyak waktu hanya untuk mencoba-coba hal yang belum kami pahami sepenuhnya. Kami yakin hal ini akan sangat bermanfaat bagi kelancaran proses belajar mahasiswa di angkatan-angkatan selanjutnya.

Saran kedua yang juga tidak kalah penting bagi kami adalah mengenai pertimbangan durasi waktu dalam penyelesaian proyek akhir. Melihat banyaknya fitur dan kriteria yang harus dipenuhi dalam satu proyek, kami merasa alangkah baiknya jika waktu pengerjaannya bisa dibuat lebih fleksibel atau dibuat lebih seimbang dengan beban kerja yang diminta. Mengingat pada akhir semester jadwal tugas-tugas dari mata kuliah lain juga sangat padat dan ujian-ujian susulan sering kali datang bersamaan, pembagian waktu yang lebih proporsional akan sangat membantu kami dalam menjaga kualitas pekerjaan agar tetap maksimal. Selain itu, hal ini juga sangat penting agar kami sebagai mahasiswa masih bisa memiliki waktu istirahat yang cukup dan tetap bisa menjaga kesehatan fisik maupun mental kami. Dengan pembagian beban tugas dan waktu yang lebih pas, kami yakin mahasiswa akan tetap bisa produktif tanpa harus merasa terlalu tertekan atau kelelahan akibat jadwal yang terlalu menumpuk di saat-saat kritis seperti akhir semester ini.

Saran ketiga ini berkaitan dengan proses awal pembentukan kelompok dan penentuan tema proyek melalui spreadsheet yang kemarin dibagikan secara mendadak. Jujur saja, waktu link tersebut tiba-tiba muncul tanpa ada aba-aba sebelumnya, kami merasa sangat kaget dan kurang siap karena belum sempat berdiskusi sama sekali dengan teman-teman lainnya. Padahal, memilih rekan satu kelompok dan menentukan tema apa yang akan digarap adalah keputusan yang sangat besar dan krusial, karena hal ini akan sangat berpengaruh pada kekompakan serta kelancaran pengerjaan tugas besar kami selama satu semester penuh. Kalau sistem pembagiannya dilakukan secara mendadak seperti kemarin, kami jadi terkesan terburu-buru dan hanya asal pilih supaya tidak kehabisan tema atau ketinggalan mendaftar, yang pada akhirnya bisa membuat pemilihan kelompok atau tema menjadi kurang matang karena tidak dipikirkan dengan tenang.

Kami rasa akan jauh lebih efektif, adil, dan teratur bagi seluruh mahasiswa jika ke depannya ada semacam pengumuman atau pemberitahuan awal mengenai kapan tepatnya link spreadsheet tersebut akan dibuka atau dibagikan. Misalnya, minimal diberitahu satu hari sebelumnya atau beberapa jam sebelum link tersebut benar-benar live. Dengan adanya kepastian jadwal seperti itu, kami bisa memiliki waktu yang cukup untuk saling mengobrol dulu dengan teman-teman, saling mencocokkan ide, mencari anggota yang satu visi, atau setidaknya melakukan riset kecil mengenai tema apa yang sekiranya paling pas dan seru untuk digarap bersama-sama secara maksimal.

Persiapan di awal ini sangat penting supaya setiap kelompok memiliki landasan yang kuat dan motivasi yang tinggi sejak hari pertama proyek dimulai, bukannya baru mulai berdiskusi setelah nama-nama sudah terdaftar di spreadsheet. Selain itu, dengan adanya jadwal yang jelas, beban pikiran kami juga jadi sedikit berkurang karena tidak perlu terus-menerus memantau grup koordinasi setiap saat hanya karena takut link-nya dibagikan secara tiba-tiba tanpa pemberitahuan. Kejelasan jadwal ini akan sangat membantu kami dalam memulai langkah pertama pengerjaan tugas besar dengan cara yang jauh lebih terencana, tenang, dan profesional.''',
            style: AppTheme.darkTheme.textTheme.bodyMedium,
            textAlign: TextAlign.justify,
          ),
        ),
      ),
      // ),
    );
  }
}
