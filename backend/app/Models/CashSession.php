<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CashSession extends Model
{
    protected $fillable = [
        'opening_amount',
        'expected_closing_amount',
        'counted_closing_amount',
        'difference',
        'opened_at',
        'closed_at',
        'status',
        'opened_by',
        'closed_by',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'opening_amount' => 'decimal:2',
            'expected_closing_amount' => 'decimal:2',
            'counted_closing_amount' => 'decimal:2',
            'difference' => 'decimal:2',
            'opened_at' => 'datetime',
            'closed_at' => 'datetime',
        ];
    }

    public function openedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'opened_by');
    }

    public function closedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'closed_by');
    }

    public function adjustments(): HasMany
    {
        return $this->hasMany(CashSessionAdjustment::class);
    }

    public function washes(): HasMany
    {
        return $this->hasMany(Wash::class);
    }

    /**
     * Id de la sesión de caja abierta, bloqueando la fila (debe llamarse dentro
     * de una transacción). Serializa contra CashSessionController::close() para
     * que ningún movimiento de efectivo se registre a mitad de un cierre sin
     * quedar contabilizado ni reclamado.
     */
    public static function openSessionIdForUpdate(): ?int
    {
        return static::where('status', 'abierta')->lockForUpdate()->value('id');
    }
}
