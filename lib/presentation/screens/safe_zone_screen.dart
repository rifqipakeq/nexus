import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class SafeZoneScreen extends ConsumerStatefulWidget {
  const SafeZoneScreen({super.key});

  @override
  ConsumerState<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends ConsumerState<SafeZoneScreen> {
  bool _isCapturing = false;

  /// Buka dialog untuk menambah zona baru dengan nama dan radius
  Future<void> _addZone() async {
    final locationService = ref.read(locationServiceProvider);
    final storage = ref.read(userScopedStorageProvider);

    setState(() => _isCapturing = true);
    Map<String, double> coords;
    try {
      coords = await locationService.getCurrentCoordinates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendapatkan lokasi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _isCapturing = false);
      return;
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }

    if (!mounted) return;

    // Dialog untuk nama & radius
    final nameController = TextEditingController(text: 'Zona Saya');
    double selectedRadius = 200;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tambah Zona Aman',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Koordinat info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF6C63FF),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${coords['lat']!.toStringAsFixed(5)}, '
                        '${coords['lng']!.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nama zona
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nama Zona',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'Contoh: Rumah, Kantor',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F3460),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.label_outline,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Radius slider
              Text(
                'Radius: ${selectedRadius.toInt()} meter',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: const Color(0xFF6C63FF),
                  inactiveTrackColor: const Color(0xFF0F3460),
                  thumbColor: const Color(0xFF6C63FF),
                  overlayColor: const Color(0x226C63FF),
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                child: Slider(
                  value: selectedRadius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${selectedRadius.toInt()} m',
                  onChanged: (v) {
                    setDialogState(() => selectedRadius = v);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final name =
        nameController.text.trim().isEmpty ? 'Zona Saya' : nameController.text.trim();
    final newZone = {
      'name': name,
      'lat': coords['lat']!,
      'lng': coords['lng']!,
      'radius': selectedRadius,
    };

    final currentZones = List<Map<String, dynamic>>.from(
      ref.read(userSafeZonesProvider),
    );
    currentZones.add(newZone);

    await storage.saveSafeZones(currentZones);
    ref.read(userSafeZonesProvider.notifier).state = List.from(currentZones);
    // Mark that user has now configured zones (affects isInsideAnyZone logic)
    ref.read(userHasConfiguredZonesProvider.notifier).state = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" ditambahkan sebagai zona aman!'),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteZone(int index) async {
    final storage = ref.read(userScopedStorageProvider);
    final zones = List<Map<String, dynamic>>.from(
      ref.read(userSafeZonesProvider),
    );
    final zoneName = zones[index]['name'] ?? 'Zona';
    zones.removeAt(index);
    await storage.saveSafeZones(zones);
    ref.read(userSafeZonesProvider.notifier).state = List.from(zones);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$zoneName" dihapus.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = ref.watch(userSafeZonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zona Aman Saya'),
        actions: [
          if (_isCapturing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCapturing ? null : _addZone,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: _isCapturing
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_location_alt),
        label: Text(_isCapturing ? 'Mengambil lokasi...' : 'Lokasi Saat Ini'),
      ),
      body: zones.isEmpty ? _buildEmptyState() : _buildZoneList(zones),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 56,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Belum Ada Zona Aman',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan zona aman agar transaksi hanya\nbisa dilakukan di lokasi terpercaya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk menangkap\nlokasi GPS saat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildZoneList(List<Map<String, dynamic>> zones) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: zones.length,
      itemBuilder: (context, index) {
        final zone = zones[index];
        final name = zone['name'] ?? 'Zona ${index + 1}';
        final lat = (zone['lat'] as num).toDouble();
        final lng = (zone['lng'] as num).toDouble();
        final radius = (zone['radius'] as num).toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withAlpha(60),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF6C63FF),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      size: 12,
                      color: Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Radius ${radius.toInt()} meter',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDelete(index, name),
              tooltip: 'Hapus zona',
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(int index, String name) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Zona Aman?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Zona "$name" akan dihapus permanen.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteZone(index);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
