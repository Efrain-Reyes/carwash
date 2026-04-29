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
        $query = ExpenseCatalogItem::orderBy('type')->orderBy('name');

        if ($request->filled('type')) {
            $query->where('type', $request->type);
        }

        if ($request->filled('active_only')) {
            $query->where('is_active', true);
        }

        return response()->json($query->get());
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'       => 'required|string|max:150',
            'type'       => 'required|in:producto,insumo,servicio',
            'base_price' => 'nullable|numeric|min:0',
            'tax_rate'   => 'nullable|numeric|min:0|max:100',
        ]);

        $item = ExpenseCatalogItem::create($data);

        return response()->json($item, 201);
    }

    public function update(Request $request, ExpenseCatalogItem $catalogItem): JsonResponse
    {
        $data = $request->validate([
            'name'       => 'sometimes|string|max:150',
            'type'       => 'sometimes|in:producto,insumo,servicio',
            'base_price' => 'sometimes|nullable|numeric|min:0',
            'tax_rate'   => 'sometimes|nullable|numeric|min:0|max:100',
        ]);

        $catalogItem->update($data);

        return response()->json($catalogItem);
    }

    public function toggle(ExpenseCatalogItem $catalogItem): JsonResponse
    {
        $catalogItem->update(['is_active' => ! $catalogItem->is_active]);

        return response()->json($catalogItem);
    }
}
