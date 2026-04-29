<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PayrollPayment extends Model
{
    protected $fillable = [
        'payroll_period_id',
        'employee_id',
        'salary_history_id',
        'processed_by',
        'base_salary',
        'daily_rate',
        'work_days_per_period',
        'days_worked',
        'gross_amount',
        'extra_payments',
        'advance_discount',
        'other_deductions',
        'net_amount',
        'payment_date',
        'status',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'base_salary'       => 'decimal:2',
            'daily_rate'        => 'decimal:2',
            'days_worked'       => 'decimal:2',
            'gross_amount'      => 'decimal:2',
            'extra_payments'    => 'decimal:2',
            'advance_discount'  => 'decimal:2',
            'other_deductions'  => 'decimal:2',
            'net_amount'        => 'decimal:2',
            'payment_date'      => 'date',
        ];
    }

    public function period(): BelongsTo
    {
        return $this->belongsTo(PayrollPeriod::class, 'payroll_period_id');
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function salaryHistory(): BelongsTo
    {
        return $this->belongsTo(EmployeeSalaryHistory::class, 'salary_history_id');
    }

    public function processor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'processed_by');
    }

    public function advancePayments(): HasMany
    {
        return $this->hasMany(EmployeeAdvancePayment::class, 'payroll_payment_id');
    }
}
