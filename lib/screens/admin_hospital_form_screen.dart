import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/admin_service.dart';
import '../theme/app_colors.dart';

class AdminHospitalFormScreen extends StatefulWidget {
  final AdminHospitalEntry? hospital;

  const AdminHospitalFormScreen({super.key, this.hospital});

  @override
  State<AdminHospitalFormScreen> createState() => _AdminHospitalFormScreenState();
}

class _AdminHospitalFormScreenState extends State<AdminHospitalFormScreen> {
  late final TextEditingController _nameController = TextEditingController(text: widget.hospital?.name ?? '');
  late final TextEditingController _addressController = TextEditingController(text: widget.hospital?.address ?? '');
  String? _nameError;

  bool get _isEditing => widget.hospital != null;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    setState(() => _nameError = name.isEmpty ? 'Hospital name is required' : null);
    if (name.isEmpty) return;

    final service = AdminService.instance;
    if (_isEditing) {
      service.updateHospital(widget.hospital!.id, name, address);
    } else {
      service.addHospital(name, address);
    }
    Navigator.pop(context);
  }

  void _delete() {
    AdminService.instance.deleteHospital(widget.hospital!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
        title: Text(_isEditing ? 'Edit hospital' : 'Add hospital', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryWarm)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Hospital name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'e.g. Sneha Hospital')),
              if (_nameError != null) ...[
                const SizedBox(height: 6),
                Text(_nameError!, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
              const SizedBox(height: 20),
              const Text('Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(controller: _addressController, decoration: const InputDecoration(hintText: 'e.g. Koramangala, Bengaluru')),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: Text(_isEditing ? 'Save changes' : 'Add hospital')),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _delete, child: const Text('Delete hospital')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
