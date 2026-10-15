<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Wash extends Model
{
    use Auditable;

    protected $fillable = [
        'group_uuid',
        'user_id',
        'cash_session_id',
        'excluded_from_cash_session',
        'vehicle_type_id',
        'wash_service_id',
        'custom_description',
        'price',
        'status',
        'notes',
        'registered_at',
    ];

    protected function casts(): array
    {
        return [
            'price'         => 'decimal:2',
            'excluded_from_cash_session' => 'boolean',
            'registered_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function vehicleType(): BelongsTo
    {
        return $this->belongsTo(VehicleType::class);
    }

    public function washService(): BelongsTo
    {
        return $this->belongsTo(WashService::class);
    }

    public function cashSession(): BelongsTo
    {
        return $this->belongsTo(CashSession::class);
    }
}
