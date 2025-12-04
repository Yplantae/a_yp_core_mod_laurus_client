import 'package:flutter/material.dart';
import '../../domain/permission_models.dart';

/// [PermissionEditDialog]
/// 그룹 생성/편집 및 '삭제' 진입점.
class PermissionEditDialog extends StatefulWidget {
  final PermissionModel? permission; // null이면 생성 모드
  final String? parentTitle;

  const PermissionEditDialog({Key? key, this.permission, this.parentTitle}) : super(key: key);

  @override
  State<PermissionEditDialog> createState() => _PermissionEditDialogState();
}

class _PermissionEditDialogState extends State<PermissionEditDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _permLevelCtrl;

  // Values
  late PermissionType _selectedType;
  late PermissionStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final g = widget.permission;
    _titleCtrl = TextEditingController(text: g?.title ?? '');
    _descCtrl = TextEditingController(text: g?.description ?? '');
    _permLevelCtrl = TextEditingController(text: g?.permissionLevel.toString() ?? '1000');

    _selectedType = g?.type ?? PermissionType.general;
    _selectedStatus = g?.status ?? PermissionStatus.active;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _permLevelCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final permLevel = int.tryParse(_permLevelCtrl.text) ?? 1000;

    // Save Action Return
    final result = {
      'action': 'save',
      'data': {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'type': _selectedType,
        'status': _selectedStatus,
        'permissionLevel': permLevel,
      }
    };
    Navigator.of(context).pop(result);
  }

  Future<void> _onDelete() async {
    // 삭제 안전장치 (Confirmation)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permission'),
        content: Text("Are you sure you want to delete '${widget.permission?.title}'?\nThis action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Delete Action Return
      Navigator.of(context).pop({'action': 'delete'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.permission != null;
    final title = isEditing ? 'Edit Permission' : 'New Permission';
    final subtitle = widget.parentTitle != null ? 'Under: ${widget.parentTitle}' : 'Root Node';

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Members'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween, // 버튼 양끝 배치
      actions: [
        // 1. 좌측: 삭제 버튼 (편집 모드일 때만)
        if (isEditing)
          TextButton.icon(
            onPressed: _onDelete,
            icon: const Icon(Icons.delete, size: 20),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          )
        else
          const SizedBox(), // 공간 채우기용

        // 2. 우측: 취소 / 저장 버튼
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _onSave,
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PermissionType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: PermissionType.values.map((e) {
                return DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()));
              }).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PermissionStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: PermissionStatus.values.map((e) {
                return DropdownMenuItem(value: e, child: Text(e.name));
              }).toList(),
              onChanged: (v) => setState(() => _selectedStatus = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _permLevelCtrl,
              decoration: const InputDecoration(labelText: 'Permission Level'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final members = widget.permission?.memberIds ?? [];
    if (members.isEmpty) {
      return const Center(child: Text('No members assigned.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text('Member ID: ${members[index]}'),
        );
      },
    );
  }
}