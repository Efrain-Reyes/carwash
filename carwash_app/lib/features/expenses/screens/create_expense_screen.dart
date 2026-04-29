import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_header.dart';
import '../models/supplier_model.dart';
import '../services/expense_service.dart';

// ─── Item draft (local form state per row) ────────────────────────────────────

class _ItemDraft {
  final TextEditingController descController  = TextEditingController();
  final TextEditingController qtyController   = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController taxController   = TextEditingController(text: '15');

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    taxController.dispose();
  }

  double get qty     => double.tryParse(qtyController.text)   ?? 0;
  double get price   => double.tryParse(priceController.text) ?? 0;
  double get taxRate => double.tryParse(taxController.text)   ?? 0;

  double get subtotal  => qty * price;
  double get taxAmount => subtotal * (taxRate / 100);
  double get total     => subtotal + taxAmount;

  bool get isValid =>
      descController.text.trim().isNotEmpty && qty > 0 && price >= 0;

  Map<String, dynamic> toPayload() => {
    'description': descController.text.trim(),
    'quantity':    qty,
    'unit_price':  price,
    'tax_rate':    taxRate,
  };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({super.key});

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  List<Supplier> _suppliers = [];
  bool _loadingSuppliers = false;
  Supplier? _selectedSupplier;

  bool _isInternalInvoice = true;
  final _invoiceController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  final _notesController = TextEditingController();

  final List<_ItemDraft> _items = [];
  bool _saving = false;

  // ── derived ──────────────────────────────────────────────────────────────────

  double get _subtotal  => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get _taxAmount => _items.fold(0.0, (s, i) => s + i.taxAmount);
  double get _total     => _subtotal + _taxAmount;

  bool get _canSave {
    if (_selectedSupplier == null) return false;
    if (!_isInternalInvoice && _invoiceController.text.trim().isEmpty) return false;
    if (_items.isEmpty) return false;
    return _items.every((i) => i.isValid);
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _addItem();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ── actions ──────────────────────────────────────────────────────────────────

  Future<void> _loadSuppliers() async {
    setState(() => _loadingSuppliers = true);
    try {
      final list = await ExpenseService.getSuppliers();
      if (mounted) setState(() { _suppliers = list; _loadingSuppliers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  void _addItem() {
    final draft = _ItemDraft();
    // Rebuild on every keystroke so totals update
    for (final c in [draft.descController, draft.qtyController, draft.priceController, draft.taxController]) {
      c.addListener(() => setState(() {}));
    }
    setState(() => _items.add(draft));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _openSupplierPicker() async {
    if (_loadingSuppliers) return;
    final result = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierPickerSheet(suppliers: _suppliers),
    );
    if (result != null && mounted) {
      setState(() {
        if (!_suppliers.any((s) => s.id == result.id)) {
          _suppliers = [..._suppliers, result];
        }
        _selectedSupplier = result;
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      await ExpenseService.createExpense(
        supplierId:        _selectedSupplier!.id,
        isInternalInvoice: _isInternalInvoice,
        invoiceNumber:     _isInternalInvoice ? null : _invoiceController.text.trim(),
        expenseDate:       Fmt.dateApi(_expenseDate),
        notes:             _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        items:             _items.map((i) => i.toPayload()).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Gasto registrado exitosamente!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.successFg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = _extractError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.errorFg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'No se pudo registrar el gasto. Intenta de nuevo.';
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSupplierSection(),
                  const SizedBox(height: 20),
                  _buildInvoiceSection(),
                  const SizedBox(height: 20),
                  _buildDateSection(),
                  const SizedBox(height: 20),
                  _buildNotesSection(),
                  const SizedBox(height: 20),
                  _buildItemsSection(),
                  const SizedBox(height: 20),
                  _buildSummaryCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar gasto',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Completa los datos del gasto',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── supplier section ──────────────────────────────────────────────────────────

  Widget _buildSupplierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Proveedor'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openSupplierPicker,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selectedSupplier != null
                        ? AppColors.accent.withAlpha(20)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    size: 18,
                    color: _selectedSupplier != null ? AppColors.accent : AppColors.textMuted2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _loadingSuppliers
                      ? Text(
                          'Cargando proveedores...',
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                        )
                      : Text(
                          _selectedSupplier?.name ?? 'Seleccionar proveedor',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: _selectedSupplier != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selectedSupplier != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted2,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── invoice section ───────────────────────────────────────────────────────────

  Widget _buildInvoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Factura'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Tiene número de factura?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ToggleChip(
                    label: 'No',
                    active: _isInternalInvoice,
                    onTap: () => setState(() {
                      _isInternalInvoice = true;
                      _invoiceController.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Sí',
                    active: !_isInternalInvoice,
                    onTap: () => setState(() => _isInternalInvoice = false),
                  ),
                ],
              ),
              if (!_isInternalInvoice) ...[
                const SizedBox(height: 14),
                AppTextField(
                  controller: _invoiceController,
                  label: 'Número de factura',
                  hint: 'FAC-001',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── date section ──────────────────────────────────────────────────────────────

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Fecha del gasto'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, size: 17, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Fmt.dateFull(_expenseDate),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted2, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── notes section ─────────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Notas'),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: AppTextField(
            controller: _notesController,
            hint: 'Notas adicionales (opcional)',
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  // ── items section ─────────────────────────────────────────────────────────────

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Ítems',
          action: GestureDetector(
            onTap: _addItem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Agregar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Agrega al menos un ítem',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          )
        else
          for (int i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ItemCard(
              index: i,
              draft: _items[i],
              onRemove: _items.length > 1 ? () => _removeItem(i) : null,
            ),
          ],
      ],
    );
  }

  // ── summary card ──────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: _subtotal),
          const SizedBox(height: 8),
          _SummaryRow(label: 'ISV',      value: _taxAmount),
          const Divider(color: AppColors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                Fmt.lempira(_total),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: AppButton(
            label: 'Guardar gasto',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: (_canSave && !_saving) ? _save : null,
          ),
        ),
      ),
    );
  }
}

// ─── Item card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _ItemDraft draft;
  final VoidCallback? onRemove;

  static final _numFmt = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // label + remove
          Row(
            children: [
              Text(
                'ÍTEM ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // description
          AppTextField(
            controller: draft.descController,
            hint: 'Descripción del ítem',
          ),
          const SizedBox(height: 10),
          // qty / price / tax row
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: draft.qtyController,
                  label: 'Cant.',
                  hint: '1',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_numFmt],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: draft.priceController,
                  label: 'P. Unitario',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_numFmt],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: draft.taxController,
                  label: 'ISV %',
                  hint: '15',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_numFmt],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // item total
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${Fmt.lempira(draft.total)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          Fmt.lempira(value),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Toggle chip ──────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Supplier picker sheet ────────────────────────────────────────────────────

class _SupplierPickerSheet extends StatefulWidget {
  const _SupplierPickerSheet({required this.suppliers});
  final List<Supplier> suppliers;

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final _searchController = TextEditingController();
  String _search = '';
  bool _creating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Supplier> get _filtered => widget.suppliers
      .where((s) => s.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  Future<void> _createNew() async {
    String name = '';
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Nuevo proveedor',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: TextField(
          controller: nameController,
          onChanged: (v) => name = v,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nombre del proveedor',
            hintStyle: GoogleFonts.inter(color: AppColors.textMuted2, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Crear',
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    nameController.dispose();
    if (confirmed != true || name.trim().isEmpty || !mounted) return;

    setState(() => _creating = true);
    try {
      final supplier = await ExpenseService.createSupplier(name.trim());
      if (mounted) Navigator.of(context).pop(supplier);
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo crear el proveedor.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.errorFg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seleccionar proveedor',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_creating)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // search
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar proveedor...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textMuted2, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No hay resultados',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withAlpha(15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.store_rounded, size: 16, color: AppColors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // create new button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: AppButtonSecondary(
              label: 'Crear nuevo proveedor',
              icon: Icons.add_rounded,
              onPressed: _creating ? null : _createNew,
            ),
          ),
        ],
      ),
    );
  }
}
