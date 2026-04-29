<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoreEmployeeRequest;
use App\Http\Requests\Api\StoreSalaryRequest;
use App\Models\Employee;
use App\Services\EmployeeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmployeeController extends Controller
{
    public function __construct(private EmployeeService $employeeService) {}

    public function index(): JsonResponse
    {
        $employees = Employee::with('currentSalary')
            ->orderBy('first_name')
            ->get()
            ->map(fn ($e) => $this->formatEmployee($e));

        return response()->json($employees);
    }

    public function store(StoreEmployeeRequest $request): JsonResponse
    {
        $employee = $this->employeeService->create($request->validated(), $request->user()->id);

        return response()->json($this->formatEmployee($employee), 201);
    }

    public function show(Employee $employee): JsonResponse
    {
        $employee->load(['currentSalary', 'salaryHistories' => function ($q) {
            $q->orderByDesc('effective_from');
        }, 'user:id,name,email']);

        return response()->json($this->formatEmployee($employee));
    }

    public function update(Request $request, Employee $employee): JsonResponse
    {
        $data = $request->validate([
            'first_name' => 'sometimes|string|max:100',
            'last_name'  => 'sometimes|string|max:100',
            'phone'      => 'sometimes|nullable|string|max:20',
            'hire_date'  => 'sometimes|date',
            'user_id'    => 'sometimes|nullable|integer|exists:users,id',
        ]);

        $employee->update($data);

        return response()->json($this->formatEmployee($employee->load('currentSalary')));
    }

    public function toggle(Employee $employee): JsonResponse
    {
        $employee->update(['is_active' => ! $employee->is_active]);

        return response()->json($this->formatEmployee($employee->load('currentSalary')));
    }

    public function deactivate(Employee $employee): JsonResponse
    {
        $employee->update(['is_active' => false]);

        return response()->json($this->formatEmployee($employee->load('currentSalary')));
    }

    public function activate(Employee $employee): JsonResponse
    {
        $employee->update(['is_active' => true]);

        return response()->json($this->formatEmployee($employee->load('currentSalary')));
    }

    public function salaryHistory(Employee $employee): JsonResponse
    {
        $history = $employee->salaryHistories()
            ->orderByDesc('effective_from')
            ->get();

        return response()->json($history);
    }

    public function payrollPayments(Employee $employee): JsonResponse
    {
        $payments = $employee->payrollPayments()
            ->with([
                'period',
                'salaryHistory',
                'processor:id,name',
                'advancePayments.advance',
            ])
            ->orderByDesc('payment_date')
            ->orderByDesc('id')
            ->get();

        return response()->json($payments);
    }

    public function storeSalary(StoreSalaryRequest $request, Employee $employee): JsonResponse
    {
        $salary = $this->employeeService->changeSalary($employee, $request->validated(), $request->user()->id);

        return response()->json($salary, 201);
    }

    private function formatEmployee(Employee $employee): array
    {
        return [
            'id'             => $employee->id,
            'full_name'      => $employee->fullName(),
            'first_name'     => $employee->first_name,
            'last_name'      => $employee->last_name,
            'phone'          => $employee->phone,
            'hire_date'      => $employee->hire_date,
            'is_active'      => $employee->is_active,
            'user'           => $employee->relationLoaded('user') ? $employee->user : null,
            'current_salary' => $employee->currentSalary,
            'salary_history' => $employee->relationLoaded('salaryHistories') ? $employee->salaryHistories : null,
        ];
    }
}
