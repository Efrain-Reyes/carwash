<?php

namespace App\Services;

use App\Models\CashSession;
use App\Models\Expense;
use Illuminate\Support\Facades\DB;

class ExpenseService
{
    public function create(array $data, int $userId): Expense
    {
        return DB::transaction(function () use ($data, $userId) {
            $internalCorrelative = null;

            if ($data['is_internal_invoice']) {
                // lockForUpdate evita que dos requests simultáneos generen el mismo número
                $internalCorrelative = (Expense::lockForUpdate()->max('internal_correlative') ?? 0) + 1;
            }

            ['items' => $itemsData, 'subtotal' => $subtotal, 'taxAmount' => $taxAmount] = $this->calculateItems($data['items']);

            $expense = Expense::create([
                'user_id'              => $userId,
                'cash_session_id'      => CashSession::openSessionIdForUpdate(),
                'supplier_id'          => $data['supplier_id'],
                'invoice_number'       => $data['is_internal_invoice'] ? null : $data['invoice_number'],
                'is_internal_invoice'  => $data['is_internal_invoice'],
                'internal_correlative' => $internalCorrelative,
                'subtotal'             => $subtotal,
                'tax_amount'           => $taxAmount,
                'total'                => $subtotal + $taxAmount,
                'expense_date'         => $data['expense_date'],
                'notes'                => $data['notes'] ?? null,
                'status'               => 'activo',
            ]);

            $expense->items()->createMany($itemsData);

            return $expense->load(['supplier', 'items.catalogItem', 'user:id,name']);
        });
    }

    private function calculateItems(array $items): array
    {
        $calculated = [];
        $subtotal   = 0;
        $taxAmount  = 0;

        foreach ($items as $item) {
            $itemSubtotal = round($item['quantity'] * $item['unit_price'], 2);
            $taxRate      = $item['tax_rate'] ?? 0;
            $itemTax      = round($itemSubtotal * ($taxRate / 100), 2);
            $itemTotal    = $itemSubtotal + $itemTax;

            $calculated[] = [
                'catalog_item_id' => $item['catalog_item_id'] ?? null,
                'description'     => $item['description'],
                'quantity'        => $item['quantity'],
                'unit_price'      => $item['unit_price'],
                'tax_rate'        => $taxRate,
                'subtotal'        => $itemSubtotal,
                'tax_amount'      => $itemTax,
                'total'           => $itemTotal,
            ];

            $subtotal  += $itemSubtotal;
            $taxAmount += $itemTax;
        }

        return [
            'items'     => $calculated,
            'subtotal'  => round($subtotal, 2),
            'taxAmount' => round($taxAmount, 2),
        ];
    }
}
