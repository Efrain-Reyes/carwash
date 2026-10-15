<?php

namespace App\Models;

use App\Models\Concerns\Auditable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ExpenseCatalogItem extends Model
{
    use Auditable;

    protected $fillable = [
        'name',
        'type',
        'base_price',
        'tax_rate',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'base_price' => 'decimal:2',
            'tax_rate'   => 'decimal:2',
            'is_active'  => 'boolean',
        ];
    }

    public function expenseItems(): HasMany
    {
        return $this->hasMany(ExpenseItem::class, 'catalog_item_id');
    }
}
