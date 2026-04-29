<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class VehicleType extends Model
{
    protected $fillable = [
        'name',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
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
