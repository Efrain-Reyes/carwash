<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ExpenseSupplier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    public function index(): JsonResponse
    {
        $suppliers = ExpenseSupplier::orderBy('name')->get();

        return response()->json($suppliers);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'    => 'required|string|max:150',
            'contact' => 'nullable|string|max:150',
        ]);

        $supplier = ExpenseSupplier::create($data);

        return response()->json($supplier, 201);
    }

    public function update(Request $request, ExpenseSupplier $supplier): JsonResponse
    {
        $data = $request->validate([
            'name'    => 'sometimes|string|max:150',
            'contact' => 'sometimes|nullable|string|max:150',
        ]);

        $supplier->update($data);

        return response()->json($supplier);
    }

    public function toggle(ExpenseSupplier $supplier): JsonResponse
    {
        $supplier->update(['is_active' => ! $supplier->is_active]);

        return response()->json($supplier);
    }
}
