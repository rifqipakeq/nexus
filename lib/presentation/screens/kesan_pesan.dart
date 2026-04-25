import 'package:flutter/material.dart';

class KesanPesanScreen extends StatelessWidget {
  const KesanPesanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kesan & Saran TPM"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [

            Text(
              "Kesan",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            Text(
              "Mata kuliah TPM sangat menarik karena mengajarkan pembuatan aplikasi mobile dari dasar hingga implementasi fitur modern.",
              style: TextStyle(fontSize: 16),
            ),

            SizedBox(height: 24),

            Text(
              "Saran",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            Text(
              "Semoga ke depannya lebih banyak praktik project nyata dan pembahasan deployment aplikasi.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}