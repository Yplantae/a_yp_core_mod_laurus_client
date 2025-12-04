import 'package:flutter/material.dart';
import '../../member_manager.dart'; // FilterCondition 참조

class MemberFilterDialog extends StatefulWidget {
  const MemberFilterDialog({Key? key}) : super(key: key);

  @override
  State<MemberFilterDialog> createState() => _MemberFilterDialogState();
}

class _MemberFilterDialogState extends State<MemberFilterDialog> {
  String _selectedType = 'nickname';
  final TextEditingController _valueController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _onApply() {
    final value = _valueController.text.trim();
    if (value.isEmpty) return;

    dynamic parsedValue = value;
    if (_selectedType == 'level_min' || _selectedType == 'level_max') {
      parsedValue = int.tryParse(value) ?? 1000;
    }

    Navigator.of(context).pop(FilterCondition(_selectedType, parsedValue));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Filter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Filter Type'),
            items: const [
              DropdownMenuItem(value: 'nickname', child: Text('Nickname Contains')),
              DropdownMenuItem(value: 'level_min', child: Text('Min Level')),
              DropdownMenuItem(value: 'level_max', child: Text('Max Level')),
              DropdownMenuItem(value: 'group_id', child: Text('In Group ID')),
            ],
            onChanged: (val) => setState(() => _selectedType = val ?? 'nickname'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: 'Value',
              hintText: _selectedType.contains('level') ? 'e.g. 5000' : 'text...',
            ),
            keyboardType: _selectedType.contains('level')
                ? TextInputType.number
                : TextInputType.text,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onApply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}