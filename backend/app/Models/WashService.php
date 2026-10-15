<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Un servicio del catálogo ofrecido para un tipo de vehículo, con su precio
 * (una celda de la matriz de precios). Los lavados apuntan a esta fila.
 */
class WashService extends Model
{
    use Auditable;

    protected $fillable = [
        'wash_service_type_id',
        'vehicle_type_id',
        'name',
        'kind',
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

    protected static function booted(): void
    {
        // Todo precio pertenece a un servicio del catálogo, aunque se cree sin indicarlo.
        static::creating(function (WashService $service) {
            if ($service->wash_service_type_id === null && $service->name) {
                $service->wash_service_type_id = WashServiceType::findOrCreateByName($service->name, (bool) $service->is_custom)->id;
            }

            // El tipo (lavado o extra) siempre es el del servicio del catálogo.
            if ($type = WashServiceType::find($service->wash_service_type_id)) {
                $service->kind = $type->kind;
            }
        });
    }

    public function isExtra(): bool
    {
        return $this->kind === 'extra';
    }

    public function serviceType(): BelongsTo
    {
        return $this->belongsTo(WashServiceType::class, 'wash_service_type_id');
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
