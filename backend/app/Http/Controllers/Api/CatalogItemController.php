<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ExpenseCatalogItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CatalogItemController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = ExpenseCatalogItem::with('category:id,name')
            ->orderBy('expense_category_id')
            ->orderBy('name');

        if ($request->filled('expense_category_id')) {
            $query->where('expense_category_id', $request->expense_category_id);
        }

        if ($request->filled('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json($query->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'                => 'required|string|max:150',
            'expense_category_id' => 'required|integer|exists:expense_categories,id',
            'base_price'          => 'nullable|numeric|min:0',
            'tax_rate'            => 'nullable|numeric|min:0|max:100',
        ]);

        $item = ExpenseCatalogItem::create($data);

        return response()->json($item->load('category:id,name'), 201);
    }

    public function update(Request $request, ExpenseCatalogItem $catalogItem): JsonResponse
    {
        $data = $request->validate([
            'name'                => 'sometimes|string|max:150',
            'expense_category_id' => 'sometimes|integer|exists:expense_categories,id',
            'base_price'          => 'sometimes|nullable|numeric|min:0',
            'tax_rate'            => 'sometimes|nullable|numeric|min:0|max:100',
        ]);

        $catalogItem->update($data);

        return response()->json($catalogItem->load('category:id,name'));
    }

    public function toggle(ExpenseCatalogItem $catalogItem): JsonResponse
    {
        $catalogItem->update(['is_active' => ! $catalogItem->is_active]);

        return response()->json($catalogItem);
    }
}
