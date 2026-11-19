import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/patient_model.dart';
import '../models/patient_registration.dart';
import '../providers/profile_provider.dart';

class PatientProfileEditor extends StatefulWidget {
  final PatientModel patient;
  final ProfileProvider provider;
  final bool identityLocked;
  const PatientProfileEditor({
    super.key,
    required this.patient,
    required this.provider,
    required this.identityLocked,
  });
  @override
  State<PatientProfileEditor> createState() => _PatientProfileEditorState();
}

class _PatientProfileEditorState extends State<PatientProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.patient.fullName);
  late final _gender = TextEditingController(text: widget.patient.gender ?? '');
  late final _address = TextEditingController(
    text: widget.patient.address ?? '',
  );
  late String? _dob = widget.patient.dob;
  @override
  void dispose() {
    _name.dispose();
    _gender.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final patient = widget.patient;
    final name = _name.text.trim(),
        gender = _gender.text.trim(),
        address = _address.text.trim();
    final nameChanged = name != patient.fullName,
        dobChanged = _dob != patient.dob;
    final genderChanged = gender != (patient.gender ?? ''),
        addressChanged = address != (patient.address ?? '');
    if (!nameChanged && !dobChanged && !genderChanged && !addressChanged) {
      Navigator.of(context).pop(false);
      return;
    }
    final saved = await widget.provider.saveProfile(
      fullName: nameChanged ? name : null,
      dob: dobChanged ? _dob : null,
      gender: genderChanged ? gender : null,
      address: addressChanged ? address : null,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else if (widget.provider.identityLocked) {
      _name.text = patient.fullName;
      _gender.text = patient.gender ?? '';
      setState(() => _dob = patient.dob);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final busy = widget.provider.isSaving,
          locked = widget.identityLocked || widget.provider.identityLocked;
      return PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: const Text('Cập nhật hồ sơ'),
          content: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SĐT: ${widget.patient.phone}'),
                  if (locked)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Danh tính đã được xác nhận tại quầy. Bạn có thể sửa địa chỉ; liên hệ quầy để đổi họ tên, ngày sinh hoặc giới tính.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-full-name'),
                    controller: _name,
                    enabled: !busy && !locked,
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: PatientRegistration.nameError,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy || locked
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.tryParse(_dob ?? '') ??
                                  DateTime(2000),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (mounted && date != null) {
                              setState(
                                () =>
                                    _dob = DateFormat('yyyy-MM-dd')
                                        .format(date),
                              );
                            }
                          },
                    child: Text('Ngày sinh: ${_dob ?? 'Chưa cập nhật'}'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-gender'),
                    controller: _gender,
                    enabled: !busy && !locked,
                    maxLength: 10,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile-address'),
                    controller: _address,
                    enabled: !busy,
                    maxLength: 255,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      helperText:
                          'Xóa nội dung địa chỉ rồi lưu để bỏ địa chỉ cũ.',
                    ),
                  ),
                  if (widget.provider.errorMessage != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.provider.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: busy ? null : _save,
              child: Text(busy ? 'Đang lưu…' : 'Lưu hồ sơ'),
            ),
          ],
        ),
      );
    },
  );
}
