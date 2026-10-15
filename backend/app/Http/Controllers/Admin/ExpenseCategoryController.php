<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Admin\Concerns\ValidatesInSpanish;
use App\Http\Controllers\Controller;
use App\Models\ExpenseCategory;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ExpenseCategoryController extends Controller
{
    use ValidatesInSpanish;

    public function index(): View
    {
        $categories = ExpenseCategory::ordered()->withCount('items')->get();

        return view('admin.catalog.expense-categories.index', compact('categories'));
    }

    public function create(): View
    {
        $category = new ExpenseCategory([
            'is_active'  => true,
            'sort_order' => (int) ExpenseCategory::max('sort_order') + 1,
        ]);

        return view('admin.catalog.expense-categories.form', compact('category'));
    }

    public function store(Request $request): RedirectResponse
    {
        $category = ExpenseCategory::create($this->validated($request));

        return redirect()->route('admin.catalog.expense-categories.index')
            ->with('status', "Categoría «{$category->name}» creada.");
    }

    public function edit(ExpenseCategory $category): View
    {
        return view('admin.catalog.expense-categories.form', compact('category'));
    }

    public function update(Request $request, ExpenseCategory $category): RedirectResponse
    {
        $category->update($this->validated($request, $category));

        return redirect()->route('admin.catalog.expense-categories.index')
            ->with('status', "Categoría «{$category->name}» actualizada.");
    }

    public function toggle(ExpenseCategory $category): RedirectResponse
    {
        $category->update(['is_active' => ! $category->is_active]);

        return back()->with('status', $category->is_active
            ? "«{$category->name}» está activa."
            : "«{$category->name}» se desactivó.");
    }

    private function validated(Request $request, ?ExpenseCategory $category = null): array
    {
        $data = $this->validateForm($request, [
            'name'       => ['required', 'string', 'max:100', $this->uniqueName('expense_categories', $category?->id)],
            'sort_order' => 'nullable|integer|min:0|max:999',
            'is_active'  => 'boolean',
        ], ['name' => 'nombre', 'sort_order' => 'orden']);

        return [
            'name'       => trim($data['name']),
            'sort_order' => $data['sort_order'] ?? 0,
            'is_active'  => $request->boolean('is_active'),
        ];
    }
}
