import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/wash_item.dart';
import '../services/washes_service.dart';

enum WashDateFilter { today, all }

class WashesProvider extends ChangeNotifier {
  List<WashItem> _washes = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  bool _cancelling = false;
  WashDateFilter _dateFilter = WashDateFilter.today;
  String? _statusFilter;

  List<WashItem>  get washes      => List.unmodifiable(_washes);
  int             get total       => _total;
  bool            get loading     => _loading;
  String?         get error       => _error;
  bool            get cancelling  => _cancelling;
  WashDateFilter  get dateFilter  => _dateFilter;
  String?         get statusFilter => _statusFilter;

  double get totalIngresos =>
      _washes.where((w) => w.isCompleted).fold(0.0, (s, w) => s + w.price);

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
      final result = await WashesService.getWashes(
        dateFrom: _dateFilter == WashDateFilter.today ? today : null,
        dateTo:   _dateFilter == WashDateFilter.today ? today : null,
        status:   _statusFilter,
      );
      _washes = result['washes'] as List<WashItem>;
      _total  = result['total']  as int;
      _error  = null;
    } catch (_) {
      _error = 'No se pudo cargar la lista de lavados.\nVerifica tu red e intenta de nuevo.';
    }
  }

  void setDateFilter(WashDateFilter f) {
    if (_dateFilter == f) return;
    _dateFilter = f;
    load();
  }

  void setStatusFilter(String? s) {
    if (_statusFilter == s) return;
    _statusFilter = s;
    load();
  }

  Future<bool> cancelWash(int id, {String? notes}) async {
    _cancelling = true;
    notifyListeners();
    try {
      await WashesService.cancelWash(id, notes: notes);
      _cancelling = false;
      await refresh();
      return true;
    } catch (_) {
      _cancelling = false;
      notifyListeners();
      return false;
    }
  }
}
