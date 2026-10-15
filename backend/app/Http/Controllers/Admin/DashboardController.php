<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\CashSession;
use App\Services\AccountingReportService;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function __invoke(): View
    {
        $today = now()->toDateString();
        $monthStart = now()->startOfMonth()->toDateString();

        // Mismo servicio que usa la app en Reportes, para que los números coincidan.
        $todayReport = app(AccountingReportService::class)->generate($today, $today);
        $monthReport = app(AccountingReportService::class)->generate($monthStart, $today);

        $openSession = CashSession::with('openedBy')
            ->where('status', 'abierta')
            ->orderBy('opened_at')
            ->orderBy('id')
            ->first();

        // Igual que CashSessionController::current(): todo el movimiento desde que se abrió la caja.
        $cash = null;
        if ($openSession) {
            $reports = app(AccountingReportService::class);
            $movement = (float) $reports->cashMovementForSession($openSession, now()->endOfDay())['movimiento_neto_efectivo'];

            $cash = [
                'movement'        => $movement,
                'expected'        => $reports->calculateExpectedClosing((float) $openSession->opening_amount, $movement),
                'pending_closure' => $openSession->opened_at->lt(now()->startOfDay()),
            ];
        }

        $recentActivity = AuditLog::with('user')
            ->latest('created_at')
            ->latest('id')
            ->limit(8)
            ->get();

        return view('admin.dashboard', compact('todayReport', 'monthReport', 'openSession', 'cash', 'recentActivity'));
    }
}
