<?php

namespace App\Services;

use App\Models\Employee;
use App\Models\EmployeeSalaryHistory;
use Illuminate\Support\Facades\DB;

class EmployeeService
{
    public function create(array $data, int $userId): Employee
    {
        return DB::transaction(function () use ($data, $userId) {
            $employee = Employee::create([
                'user_id'    => $data['user_id'] ?? null,
                'first_name' => $data['first_name'],
                'last_name'  => $data['last_name'],
                'phone'      => $data['phone'] ?? null,
                'hire_date'  => $data['hire_date'],
                'is_active'  => true,
            ]);

            $this->attachSalary($employee, $data, $userId);

            return $employee->load('currentSalary');
        });
    }

    public function changeSalary(Employee $employee, array $data, int $userId): EmployeeSalaryHistory
    {
        return DB::transaction(function () use ($employee, $data, $userId) {
            $employee->salaryHistories()
                ->where('is_active', true)
                ->update([
                    'is_active'    => false,
                    'effective_to' => $data['effective_from'],
                ]);

            return $this->attachSalary($employee, $data, $userId);
        });
    }

    private function attachSalary(Employee $employee, array $data, int $userId): EmployeeSalaryHistory
    {
        $dailyRate = round($data['salary'] / $data['work_days_per_period'], 2);

        return $employee->salaryHistories()->create([
            'created_by'           => $userId,
            'salary'               => $data['salary'],
            'payment_frequency'    => $data['payment_frequency'],
            'work_days_per_period' => $data['work_days_per_period'],
            'daily_rate'           => $dailyRate,
            'effective_from'       => $data['effective_from'],
            'effective_to'         => null,
            'is_active'            => true,
            'notes'                => $data['notes'] ?? null,
        ]);
    }
}
