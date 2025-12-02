import 'package:flutter/material.dart';
import '../../models/timeline_models.dart';

class TaskEditorDialog extends StatefulWidget {
  final DateTime initialStart;
  final Duration initialDuration;
  final String initialTitle;
  final String initialDesc;
  final TaskGrade initialGrade;
  final Color? initialColor;

  const TaskEditorDialog({
    Key? key,
    required this.initialStart,
    required this.initialDuration,
    this.initialTitle = 'New Task',
    this.initialDesc = '',
    this.initialGrade = TaskGrade.B,
    this.initialColor,
  }) : super(key: key);

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TaskGrade _grade;
  Color? _color;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDesc);
    _startDate = widget.initialStart;
    _endDate = widget.initialStart.add(widget.initialDuration);
    _grade = widget.initialGrade;
    _color = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(widget.initialTitle == 'New Task' ? 'Create Task' : 'Edit Task', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.grey)),
                  validator: (v) => v!.isEmpty ? 'Enter title' : null,
                ),
                TextFormField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.grey)),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildDateTimePicker('Start', _startDate, (dt) => setState(() => _startDate = dt)),
                _buildDateTimePicker('Finish', _endDate, (dt) => setState(() => _endDate = dt)),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskGrade>(
                  value: _grade,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Grade', labelStyle: TextStyle(color: Colors.grey)),
                  items: TaskGrade.values.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                  onChanged: (v) => setState(() => _grade = v!),
                ),
                // Color Picker (Simple)
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Color: ', style: TextStyle(color: Colors.grey)),
                    _colorCircle(Colors.redAccent),
                    _colorCircle(Colors.blueAccent),
                    _colorCircle(Colors.greenAccent),
                    _colorCircle(Colors.orangeAccent),
                    _colorCircle(null), // Default
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'desc': _descController.text,
                'start': _startDate,
                'duration': _endDate.difference(_startDate),
                'grade': _grade,
                'color': _color,
              });
            }
          },
          child: Text(widget.initialTitle == 'New Task' ? 'Create' : 'Save'),
        )
      ],
    );
  }

  Widget _colorCircle(Color? color) {
    return GestureDetector(
      onTap: () => setState(() => _color = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 24, height: 24,
        decoration: BoxDecoration(
            color: color ?? Colors.grey,
            shape: BoxShape.circle,
            border: _color == color ? Border.all(color: Colors.white, width: 2) : null
        ),
        child: color == null ? const Icon(Icons.close, size: 16) : null,
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime val, Function(DateTime) onPick) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text('$label:', style: const TextStyle(color: Colors.white70))),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: val, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (context, child) => Theme(data: ThemeData.dark(), child: child!));
            if(d!=null) {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(val), builder: (context, child) => Theme(data: ThemeData.dark(), child: child!));
              if(t!=null) onPick(DateTime(d.year, d.month, d.day, t.hour, t.minute));
            }
          },
          child: Text("${val.month}/${val.day} ${val.hour}:${val.minute.toString().padLeft(2,'0')}", style: const TextStyle(color: Colors.blueAccent)),
        )
      ],
    );
  }
}