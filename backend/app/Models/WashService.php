<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WashService extends Model
{
    use Auditable;

    protected $fillable = [
        'vehicle_type_id',
        'name',
        'base_price',
        'is_custom',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'base_price' => 'decimal:2',
            'is_custom'  => 'boolean',
            'is_active'  => 'boolean',
        ];
    }

    public function vehicleType(): BelongsTo
    {
        return $this->belongsTo(VehicleType::class);
    }

    public function washes(): HasMany
    {
        return $this->hasMany(Wash::class);
    }
}
