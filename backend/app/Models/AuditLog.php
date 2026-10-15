<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AuditLog extends Model
{
    // La bitácora nunca se edita: solo tiene fecha de creación.
    const UPDATED_AT = null;

    protected $fillable = [
        'user_id',
        'event',
        'auditable_type',
        'auditable_id',
        'old_values',
        'new_values',
        'source',
        'ip_address',
    ];

    protected function casts(): array
    {
        return [
            'old_values' => 'array',
            'new_values' => 'array',
            'created_at' => 'datetime',
        ];
    }

    /** Nombre legible de cada módulo auditado, usado en filtros y listados del panel. */
    public const MODULES = [
        Wash::class                   => 'Lavados',
        VehicleType::class            => 'Tipos de vehículo',
        WashServiceType::class        => 'Servicios',
        WashService::class            => 'Precios de servicios',
        Expense::class                => 'Gastos',
        ExpenseCategory::class        => 'Categorías de gastos',
        ExpenseCatalogItem::class     => 'Artículos de gastos',
        ExpenseSupplier::class        => 'Proveedores',
        CashSession::class            => 'Caja',
        CashSessionAdjustment::class  => 'Ajustes de caja',
        Employee::class               => 'Trabajadores',
        EmployeeSalaryHistory::class  => 'Sueldos',
        EmployeeAdvance::class        => 'Adelantos',
        EmployeeAdvancePayment::class => 'Abonos de adelantos',
        PayrollPeriod::class          => 'Periodos de nómina',
        PayrollPayment::class         => 'Pagos de nómina',
        User::class                   => 'Usuarios',
    ];

    /** Nombre en singular para frases como "editó lavado #12". */
    public const SUBJECTS = [
        Wash::class                   => 'lavado',
        VehicleType::class            => 'tipo de vehículo',
        WashServiceType::class        => 'servicio',
        WashService::class            => 'precio de servicio',
        Expense::class                => 'gasto',
        ExpenseCategory::class        => 'categoría de gastos',
        ExpenseCatalogItem::class     => 'artículo de gastos',
        ExpenseSupplier::class        => 'proveedor',
        CashSession::class            => 'caja',
        CashSessionAdjustment::class  => 'ajuste de caja',
        Employee::class               => 'trabajador',
        EmployeeSalaryHistory::class  => 'sueldo',
        EmployeeAdvance::class        => 'adelanto',
        EmployeeAdvancePayment::class => 'abono de adelanto',
        PayrollPeriod::class          => 'periodo de nómina',
        PayrollPayment::class         => 'pago de nómina',
        User::class                   => 'usuario',
    ];

    public const EVENTS = [
        'created' => 'Creó',
        'updated' => 'Editó',
        'deleted' => 'Eliminó',
        'login'   => 'Inició sesión',
    ];

    public const SOURCES = [
        'app'     => 'App',
        'web'     => 'Panel web',
        'sistema' => 'Sistema',
    ];

    /** Nombre en español de los campos más comunes; los demás se muestran tal cual. */
    public const FIELD_LABELS = [
        'name'                       => 'Nombre',
        'email'                      => 'Correo',
        'password'                   => 'Contraseña',
        'rol'                        => 'Rol',
        'is_active'                  => 'Activo',
        'icon'                       => 'Icono',
        'sort_order'                 => 'Orden',
        'wash_service_type_id'       => 'Servicio',
        'expense_category_id'        => 'Categoría',
        'status'                     => 'Estado',
        'notes'                      => 'Notas',
        'user_id'                    => 'Usuario',
        'price'                      => 'Precio',
        'base_price'                 => 'Precio base',
        'is_custom'                  => 'Servicio personalizado',
        'custom_description'         => 'Descripción',
        'vehicle_type_id'            => 'Tipo de vehículo',
        'wash_service_id'            => 'Servicio',
        'registered_at'              => 'Fecha del lavado',
        'cash_session_id'            => 'Caja',
        'excluded_from_cash_session' => 'Excluido de caja',
        'opening_amount'             => 'Monto de apertura',
        'expected_closing_amount'    => 'Cierre esperado',
        'counted_closing_amount'     => 'Efectivo contado',
        'difference'                 => 'Diferencia',
        'opened_at'                  => 'Apertura',
        'closed_at'                  => 'Cierre',
        'opened_by'                  => 'Abierta por',
        'closed_by'                  => 'Cerrada por',
        'reason'                     => 'Motivo',
        'supplier_id'                => 'Proveedor',
        'invoice_number'             => 'N.º de factura',
        'expense_date'               => 'Fecha del gasto',
        'subtotal'                   => 'Subtotal',
        'tax_rate'                   => 'Tasa de impuesto',
        'tax_amount'                 => 'Impuesto',
        'total'                      => 'Total',
        'type'                       => 'Tipo',
        'contact'                    => 'Contacto',
        'first_name'                 => 'Nombre',
        'last_name'                  => 'Apellido',
        'phone'                      => 'Teléfono',
        'hire_date'                  => 'Fecha de ingreso',
        'employee_id'                => 'Trabajador',
        'salary'                     => 'Sueldo',
        'payment_frequency'          => 'Frecuencia de pago',
        'amount'                     => 'Monto',
        'balance'                    => 'Saldo',
        'advance_date'               => 'Fecha del adelanto',
        'payment_type'               => 'Tipo de pago',
    ];

    public static function fieldLabel(string $field): string
    {
        return self::FIELD_LABELS[$field] ?? str_replace('_', ' ', ucfirst($field));
    }

    public static function formatValue(string $field, mixed $value): string
    {
        if ($value === null || $value === '') {
            return '—';
        }

        $isFlag = str_starts_with($field, 'is_') || str_starts_with($field, 'excluded_');

        if (is_bool($value) || ($isFlag && in_array($value, [0, 1, '0', '1'], true))) {
            return $value ? 'Sí' : 'No';
        }

        if (is_array($value)) {
            return json_encode($value, JSON_UNESCAPED_UNICODE);
        }

        return (string) $value;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function moduleLabel(): string
    {
        return self::MODULES[$this->auditable_type] ?? ($this->auditable_type ? class_basename($this->auditable_type) : '—');
    }

    public function subjectLabel(): string
    {
        return self::SUBJECTS[$this->auditable_type] ?? mb_strtolower($this->moduleLabel());
    }

    public function eventLabel(): string
    {
        return self::EVENTS[$this->event] ?? $this->event;
    }

    public function sourceLabel(): string
    {
        return self::SOURCES[$this->source] ?? $this->source;
    }

    /**
     * Lista de cambios campo por campo: [['field' => 'price', 'old' => '100.00', 'new' => '120.00'], ...].
     */
    public function changes(): array
    {
        $old = $this->old_values ?? [];
        $new = $this->new_values ?? [];

        return collect(array_unique([...array_keys($old), ...array_keys($new)]))
            ->map(fn (string $field) => [
                'field' => $field,
                'old'   => $old[$field] ?? null,
                'new'   => $new[$field] ?? null,
            ])
            ->values()
            ->all();
    }
}
