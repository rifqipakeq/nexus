import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review TPM'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'bang udah bang',
            style: AppTheme.darkTheme.textTheme.bodyMedium,
            textAlign: TextAlign.justify,
          ),
        ),
      ),
    );
  }
}