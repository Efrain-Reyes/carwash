<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasRoles, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'is_active',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
            'is_active'         => 'boolean',
        ];
    }

    public function employee(): HasOne
    {
        return $this->hasOne(Employee::class);
    }

    public function washes(): HasMany
    {
        return $this->hasMany(Wash::class);
    }

    public function expenses(): HasMany
    {
        return $this->hasMany(Expense::class);
    }

    public function registeredAdvances(): HasMany
    {
        return $this->hasMany(EmployeeAdvance::class);
    }

    public function advancePayments(): HasMany
    {
        return $this->hasMany(EmployeeAdvancePayment::class);
    }

    public function createdPayrollPeriods(): HasMany
    {
        return $this->hasMany(PayrollPeriod::class, 'created_by');
    }

    public function processedPayrollPayments(): HasMany
    {
        return $this->hasMany(PayrollPayment::class, 'processed_by');
    }
}
