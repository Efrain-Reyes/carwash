<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class VehicleType extends Model
{
    use Auditable;

    /**
     * Iconos disponibles. La clave se guarda en la base de datos; la app la traduce a
     * un icono de Material y el panel muestra el emoji.
     */
    public const ICONS = [
        'car'        => ['label' => 'Carro', 'emoji' => '🚗'],
        'pickup'     => ['label' => 'Pick-up / camioneta', 'emoji' => '🛻'],
        'van'        => ['label' => 'Microbús / van', 'emoji' => '🚐'],
        'motorcycle' => ['label' => 'Moto', 'emoji' => '🏍️'],
        'mototaxi'   => ['label' => 'Mototaxi', 'emoji' => '🛺'],
        'truck'      => ['label' => 'Camión', 'emoji' => '🚚'],
        'bus'        => ['label' => 'Bus', 'emoji' => '🚌'],
        'tractor'    => ['label' => 'Tractor / maquinaria', 'emoji' => '🚜'],
        'bike'       => ['label' => 'Bicicleta', 'emoji' => '🚲'],
    ];

    protected $fillable = [
        'name',
        'icon',
        'sort_order',
        'is_active',
    ];

    protected $attributes = [
        'icon'       => 'car',
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'is_active'  => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function scopeOrdered(Builder $query): Builder
    {
        return $query->orderBy('sort_order')->orderBy('id');
    }

    public function emoji(): string
    {
        return self::ICONS[$this->icon]['emoji'] ?? self::ICONS['car']['emoji'];
    }

    public function washServices(): HasMany
    {
        return $this->hasMany(WashService::class);
    }

    public function washes(): HasMany
    {
        return $this->hasMany(Wash::class);
    }
}
