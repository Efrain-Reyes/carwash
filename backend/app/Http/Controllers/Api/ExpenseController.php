<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreExpenseRequest;
use App\Models\Expense;
use App\Services\ExpenseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ExpenseController extends Controller
{
    public function __construct(private ExpenseService $expenseService) {}

    public function index(Request $request): JsonResponse
    {
        $query = Expense::with(['supplier', 'items.catalogItem', 'user:id,name'])
            ->orderByDesc('expense_date')
            ->orderByDesc('id');

        if ($request->filled('date_from')) {
            $query->whereDate('expense_date', '>=', $request->date_from);
        }

        if ($request->filled('date_to')) {
            $query->whereDate('expense_date', '<=', $request->date_to);
        }

        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->supplier_id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        return response()->json($query->paginate(20));
    }

    public function store(StoreExpenseRequest $request): JsonResponse
    {
        $expense = $this->expenseService->create(
            $request->validated(),
            $request->user()->id
        );

        return response()->json($expense, 201);
    }

    public function show(Expense $expense): JsonResponse
    {
        $expense->load(['supplier', 'items.catalogItem', 'user:id,name']);

        return response()->json($expense);
    }

    public function cancel(Request $request, Expense $expense): JsonResponse
    {
        if ($expense->status === 'anulado') {
            return response()->json(
                ['message' => 'Este gasto ya está anulado.'],
                422
            );
        }

        $expense->update([
            'status' => 'anulado',
            'notes'  => $request->notes ?? $expense->notes,
        ]);

        return response()->json($expense->load(['supplier', 'items.catalogItem']));
    }
}
