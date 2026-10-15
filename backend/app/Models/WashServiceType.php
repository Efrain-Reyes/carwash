<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Un servicio del catálogo, definido una sola vez (ej. "Lavado general").
 * Su precio para cada tipo de vehículo vive en WashService.
 */
class WashServiceType extends Model
{
    use Auditable;

    protected $fillable = [
        'name',
        'is_custom',
        'is_active',
        'sort_order',
    ];

    protected $attributes = [
        'is_custom'  => false,
        'is_active'  => true,
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'is_custom'  => 'boolean',
            'is_active'  => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        // Las filas de precio guardan una copia del nombre (la app y los reportes la leen de ahí).
        static::updated(function (WashServiceType $type) {
            if ($type->wasChanged('name')) {
                $type->prices->each->update(['name' => $type->name]);
            }
        });
    }

    /** Busca el servicio por nombre (sin importar mayúsculas) o lo crea al final de la lista. */
    public static function findOrCreateByName(string $name, bool $isCustom = false): self
    {
        $name = trim($name);

        return static::whereRaw('LOWER(name) = ?', [mb_strtolower($name)])->first()
            ?? static::create([
                'name'       => $name,
                'is_custom'  => $isCustom,
                'sort_order' => (int) static::max('sort_order') + 1,
            ]);
    }

    public function scopeOrdered(Builder $query): Builder
    {
        return $query->orderBy('sort_order')->orderBy('id');
    }

    /** Precio de este servicio para cada tipo de vehículo. */
    public function prices(): HasMany
    {
        return $this->hasMany(WashService::class);
    }
}
