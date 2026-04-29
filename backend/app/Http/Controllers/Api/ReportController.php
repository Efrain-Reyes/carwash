<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AccountingReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(private AccountingReportService $reportService) {}

    public function accounting(Request $request): JsonResponse
    {
        $request->validate([
            'date_from' => 'required|date',
            'date_to'   => 'required|date|after_or_equal:date_from',
        ]);

        $report = $this->reportService->generate(
            $request->date_from,
            $request->date_to
        );

        return response()->json($report);
    }

    public function accountingTimeline(Request $request): JsonResponse
    {
        $request->validate([
            'date_from' => 'required|date',
            'date_to'   => 'required|date|after_or_equal:date_from',
        ]);

        $timeline = $this->reportService->timeline(
            $request->date_from,
            $request->date_to
        );

        return response()->json($timeline);
    }
}
