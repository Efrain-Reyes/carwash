<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Wash extends Model
{
    protected $fillable = [
        'user_id',
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
}
