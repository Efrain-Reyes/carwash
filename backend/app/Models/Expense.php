<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Expense extends Model
{
    protected $fillable = [
        'user_id',
        'cash_session_id',
        'supplier_id',
        'invoice_number',
        'is_internal_invoice',
        'internal_correlative',
        'subtotal',
        'tax_amount',
        'total',
        'expense_date',
        'notes',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'is_internal_invoice' => 'boolean',
            'subtotal'            => 'decimal:2',
            'tax_amount'          => 'decimal:2',
            'total'               => 'decimal:2',
            'expense_date'        => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(ExpenseSupplier::class, 'supplier_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(ExpenseItem::class);
    }

    public function cashSession(): BelongsTo
    {
        return $this->belongsTo(CashSession::class);
    }
}
