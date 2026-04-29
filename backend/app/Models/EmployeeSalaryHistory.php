<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EmployeeSalaryHistory extends Model
{
    protected $fillable = [
        'employee_id',
        'created_by',
        'salary',
        'payment_frequency',
        'work_days_per_period',
        'daily_rate',
        'effective_from',
        'effective_to',
        'is_active',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'salary'         => 'decimal:2',
            'daily_rate'     => 'decimal:2',
            'effective_from' => 'date',
            'effective_to'   => 'date',
            'is_active'      => 'boolean',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function payrollPayments(): HasMany
    {
        return $this->hasMany(PayrollPayment::class, 'salary_history_id');
    }
}
