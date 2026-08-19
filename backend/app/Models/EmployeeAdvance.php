<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class EmployeeAdvance extends Model
{
    protected $fillable = [
        'cash_session_id',
        'excluded_from_cash_session',
        'employee_id',
        'user_id',
        'amount',
        'balance',
        'advance_date',
        'status',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'amount'       => 'decimal:2',
            'excluded_from_cash_session' => 'boolean',
            'balance'      => 'decimal:2',
            'advance_date' => 'date',
        ];
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function registeredBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(EmployeeAdvancePayment::class, 'advance_id');
    }

    public function cashSession(): BelongsTo
    {
        return $this->belongsTo(CashSession::class);
    }
}
