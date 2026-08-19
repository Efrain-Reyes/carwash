<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmployeeAdvancePayment extends Model
{
    protected $fillable = [
        'cash_session_id',
        'excluded_from_cash_session',
        'advance_id',
        'payroll_payment_id',
        'user_id',
        'amount',
        'payment_type',
        'payment_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'amount'       => 'decimal:2',
            'excluded_from_cash_session' => 'boolean',
            'payment_date' => 'date',
        ];
    }

    public function advance(): BelongsTo
    {
        return $this->belongsTo(EmployeeAdvance::class, 'advance_id');
    }

    public function payrollPayment(): BelongsTo
    {
        return $this->belongsTo(PayrollPayment::class, 'payroll_payment_id');
    }

    public function registeredBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function cashSession(): BelongsTo
    {
        return $this->belongsTo(CashSession::class);
    }
}
