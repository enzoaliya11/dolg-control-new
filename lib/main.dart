import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const DebtApp());

class DebtApp extends StatelessWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ДОЛГ КОНТРОЛ 2.0',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DebtHome(),
    );
  }
}

class DebtHome extends StatefulWidget {
  const DebtHome({super.key});

  @override
  State<DebtHome> createState() => _DebtHomeState();
}

class _DebtHomeState extends State<DebtHome> {
  List<Map<String, dynamic>> debts = [];
  bool loading = true;

  final currencies = ['KGS', 'USD', 'EUR', 'RUB'];

  @override
  void initState() {
    super.initState();
    loadDebts();
  }

  Future<void> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('debts_new');

    if (saved != null) {
      try {
        final data = jsonDecode(saved) as List;
        debts = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        debts = [];
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveDebts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debts_new', jsonEncode(debts));
  }

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';

  bool isOverdue(Map<String, dynamic> debt) {
    if (debt['dueDate'] == null) return false;
    final date = DateTime.tryParse(debt['dueDate'].toString());
    if (date == null) return false;

    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day).isBefore(
      DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> editDebt({int? index}) async {
    final editing = index != null;
    final old = editing ? debts[index] : <String, dynamic>{};

    final nameController =
        TextEditingController(text: old['name']?.toString() ?? '');
    final amountController =
        TextEditingController(text: old['amount']?.toString() ?? '');

    String type = old['type']?.toString() ?? 'Мне должны';
    String currency = old['currency']?.toString() ?? 'KGS';
    DateTime? dueDate = old['dueDate'] == null
        ? null
        : DateTime.tryParse(old['dueDate'].toString());

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing ? 'Редактировать долг' : 'Новый долг'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя или описание',
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Сумма'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Тип долга'),
                  items: ['Мне должны', 'Я должен']
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: const InputDecoration(labelText: 'Валюта'),
                  items: currencies
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => currency = v);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    dueDate == null
                        ? 'Выбрать срок возврата'
                        : formatDate(dueDate!),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                ),
                if (dueDate != null)
                  TextButton(
                    onPressed: () => setDialogState(() => dueDate = null),
                    child: const Text('Убрать дату'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final amount = double.tryParse(
                  amountController.text.trim().replaceAll(',', '.'),
                );

                if (name.isEmpty || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Проверь имя и сумму')),
                  );
                  return;
                }

                final debt = <String, dynamic>{
                  'name': name,
                  'amount': amount,
                  'type': type,
                  'currency': currency,
                  'dueDate': dueDate?.toIso8601String(),
                };

                setState(() {
                  if (editing) {
                    debts[index] = debt;
                  } else {
                    debts.add(debt);
                  }
                });

                await saveDebts();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    amountController.dispose();
  }

  Future<void> deleteDebt(int index) async {
    setState(() => debts.removeAt(index));
    await saveDebts();
  }

  double total(String type) => debts
      .where((d) => d['type'] == type)
      .fold(0.0, (sum, d) => sum + (d['amount'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ДОЛГ КОНТРОЛ 2.0',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editDebt(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить долг'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text('Мне должны'),
                              Text(
                                total('Мне должны').toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text('Я должен'),
                              Text(
                                total('Я должен').toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: debts.isEmpty
                      ? const Center(child: Text('Долгов пока нет'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: debts.length,
                          itemBuilder: (context, index) {
                            final debt = debts[index];
                            final overdue = isOverdue(debt);
                            final date = debt['dueDate'] == null
                                ? null
                                : DateTime.tryParse(
                                    debt['dueDate'].toString(),
                                  );

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: ListTile(
                                title: Text(
                                  debt['name'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(debt['type'].toString()),
                                    Text(
                                      '${debt['amount']} ${debt['currency']}',
                                    ),
                                    if (date != null)
                                      Text('Срок: ${formatDate(date)}'),
                                    if (overdue)
                                      const Text(
                                        'ПРОСРОЧЕНО',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      editDebt(index: index);
                                    } else if (value == 'delete') {
                                      deleteDebt(index);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Редактировать'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                ),
                                onTap: () => editDebt(index: index),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}