import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';

enum ExpenseDateFilter { today, all }

class ExpensesProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  ExpenseDateFilter _dateFilter = ExpenseDateFilter.today;
  String? _statusFilter;

  List<Expense>      get expenses     => List.unmodifiable(_expenses);
  int                get total        => _total;
  bool               get loading      => _loading;
  String?            get error        => _error;
  ExpenseDateFilter  get dateFilter   => _dateFilter;
  String?            get statusFilter => _statusFilter;

  double get totalAmount =>
      _expenses.where((e) => e.isActive).fold(0.0, (s, e) => s + e.total);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _doFetch();
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _doFetch();
    notifyListeners();
  }

  Future<void> _doFetch() async {
    try {
      final today = Fmt.dateApi(DateTime.now());
      final result = await ExpenseService.getExpenses(
        dateFrom: _dateFilter == ExpenseDateFilter.today ? today : null,
        dateTo:   _dateFilter == ExpenseDateFilter.today ? today : null,
        status:   _statusFilter,
      );
      _expenses = result['expenses'] as List<Expense>;
      _total    = result['total'] as int;
      _error    = null;
    } catch (_) {
      _error = 'No se pudo cargar la lista de gastos.\nVerifica tu red e intenta de nuevo.';
    }
  }

  void setDateFilter(ExpenseDateFilter f) {
    if (_dateFilter == f) return;
    _dateFilter = f;
    load();
  }

  void setStatusFilter(String? s) {
    if (_statusFilter == s) return;
    _statusFilter = s;
    load();
  }
}
