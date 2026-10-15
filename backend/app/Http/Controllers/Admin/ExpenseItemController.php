<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Admin\Concerns\ValidatesInSpanish;
use App\Http\Controllers\Controller;
use App\Models\ExpenseCatalogItem;
use App\Models\ExpenseCategory;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/** Artículos que se compran con frecuencia (jabón, cera, agua, luz...). */
class ExpenseItemController extends Controller
{
    use ValidatesInSpanish;

    public function index(Request $request): View
    {
        $search = trim((string) $request->query('buscar', ''));
        $categoryId = $request->integer('categoria') ?: null;

        $items = ExpenseCatalogItem::with('category')
            ->when($search !== '', fn ($q) => $q->where('name', 'like', "%{$search}%"))
            ->when($categoryId, fn ($q) => $q->where('expense_category_id', $categoryId))
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->get();

        $categories = ExpenseCategory::ordered()->get();

        return view('admin.catalog.expense-items.index', compact('items', 'categories', 'search', 'categoryId'));
    }

    public function create(): View
    {
        return $this->form(new ExpenseCatalogItem(['is_active' => true, 'tax_rate' => 0]));
    }

    public function store(Request $request): RedirectResponse
    {
        $item = ExpenseCatalogItem::create($this->validated($request));

        return redirect()->route('admin.catalog.expense-items.index')
            ->with('status', "Artículo «{$item->name}» creado.");
    }

    public function edit(ExpenseCatalogItem $item): View
    {
        return $this->form($item);
    }

    public function update(Request $request, ExpenseCatalogItem $item): RedirectResponse
    {
        $item->update($this->validated($request));

        return redirect()->route('admin.catalog.expense-items.index')
            ->with('status', "Artículo «{$item->name}» actualizado.");
    }

    public function toggle(ExpenseCatalogItem $item): RedirectResponse
    {
        $item->update(['is_active' => ! $item->is_active]);

        return back()->with('status', $item->is_active
            ? "«{$item->name}» está activo."
            : "«{$item->name}» se desactivó.");
    }

    private function form(ExpenseCatalogItem $item): View
    {
        // Categorías activas, más la actual aunque esté desactivada.
        $categories = ExpenseCategory::ordered()
            ->where(fn ($q) => $q->where('is_active', true)->orWhere('id', $item->expense_category_id))
            ->get();

        return view('admin.catalog.expense-items.form', compact('item', 'categories'));
    }

    private function validated(Request $request): array
    {
        $data = $this->validateForm($request, [
            'name'                => 'required|string|max:150',
            'expense_category_id' => 'required|integer|exists:expense_categories,id',
            'base_price'          => 'nullable|numeric|min:0|max:999999',
            'tax_rate'            => 'nullable|numeric|min:0|max:100',
            'is_active'           => 'boolean',
        ], [
            'name'                => 'nombre',
            'expense_category_id' => 'categoría',
            'base_price'          => 'precio de referencia',
            'tax_rate'            => 'impuesto',
        ]);

        return [
            ...$data,
            'tax_rate'  => $data['tax_rate'] ?? 0,
            'is_active' => $request->boolean('is_active'),
        ];
    }
}
