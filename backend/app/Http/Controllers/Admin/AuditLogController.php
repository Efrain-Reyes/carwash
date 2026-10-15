<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AuditLogController extends Controller
{
    public function index(Request $request): View
    {
        $filters = $request->validate([
            'user_id'   => 'nullable|integer',
            'module'    => 'nullable|string',
            'event'     => 'nullable|string',
            'source'    => 'nullable|string',
            'date_from' => 'nullable|date',
            'date_to'   => 'nullable|date',
        ]);

        // En la URL el módulo va como nombre corto (Wash), no como clase completa.
        $modules = collect(AuditLog::MODULES)
            ->mapWithKeys(fn (string $label, string $class) => [class_basename($class) => ['class' => $class, 'label' => $label]]);

        $logs = AuditLog::with('user')
            ->when($filters['user_id'] ?? null, fn ($q, $id) => $q->where('user_id', $id))
            ->when($modules[$filters['module'] ?? ''] ?? null, fn ($q, $module) => $q->where('auditable_type', $module['class']))
            ->when($filters['event'] ?? null, fn ($q, $event) => $q->where('event', $event))
            ->when($filters['source'] ?? null, fn ($q, $source) => $q->where('source', $source))
            ->when($filters['date_from'] ?? null, fn ($q, $date) => $q->where('created_at', '>=', $date.' 00:00:00'))
            ->when($filters['date_to'] ?? null, fn ($q, $date) => $q->where('created_at', '<=', $date.' 23:59:59'))
            ->latest('created_at')
            ->latest('id')
            ->paginate(25)
            ->withQueryString();

        return view('admin.audit.index', [
            'logs'    => $logs,
            'filters' => $filters,
            'modules' => $modules,
            'users'   => User::orderBy('name')->get(['id', 'name']),
        ]);
    }
}
