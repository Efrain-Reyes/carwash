<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CashSessionAdjustment extends Model
{
    protected $fillable = [
        'cash_session_id',
        'user_id',
        'old_counted_closing_amount',
        'new_counted_closing_amount',
        'old_difference',
        'new_difference',
        'old_notes',
        'new_notes',
        'reason',
    ];

    protected function casts(): array
    {
        return [
            'old_counted_closing_amount' => 'decimal:2',
            'new_counted_closing_amount' => 'decimal:2',
            'old_difference' => 'decimal:2',
            'new_difference' => 'decimal:2',
        ];
    }

    public function cashSession(): BelongsTo
    {
        return $this->belongsTo(CashSession::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
