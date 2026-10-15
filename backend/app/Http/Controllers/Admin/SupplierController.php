<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Admin\Concerns\ValidatesInSpanish;
use App\Http\Controllers\Controller;
use App\Models\ExpenseSupplier;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class SupplierController extends Controller
{
    use ValidatesInSpanish;

    public function index(Request $request): View
    {
        $search = trim((string) $request->query('buscar', ''));

        $suppliers = ExpenseSupplier::withCount('expenses')
            ->when($search !== '', fn ($q) => $q->where(fn ($q) => $q
                ->where('name', 'like', "%{$search}%")
                ->orWhere('contact', 'like', "%{$search}%")))
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->get();

        return view('admin.catalog.suppliers.index', compact('suppliers', 'search'));
    }

    public function create(): View
    {
        return view('admin.catalog.suppliers.form', ['supplier' => new ExpenseSupplier(['is_active' => true])]);
    }

    public function store(Request $request): RedirectResponse
    {
        $supplier = ExpenseSupplier::create($this->validated($request));

        return redirect()->route('admin.catalog.suppliers.index')
            ->with('status', "Proveedor «{$supplier->name}» creado.");
    }

    public function edit(ExpenseSupplier $supplier): View
    {
        return view('admin.catalog.suppliers.form', compact('supplier'));
    }

    public function update(Request $request, ExpenseSupplier $supplier): RedirectResponse
    {
        $supplier->update($this->validated($request));

        return redirect()->route('admin.catalog.suppliers.index')
            ->with('status', "Proveedor «{$supplier->name}» actualizado.");
    }

    public function toggle(ExpenseSupplier $supplier): RedirectResponse
    {
        $supplier->update(['is_active' => ! $supplier->is_active]);

        return back()->with('status', $supplier->is_active
            ? "«{$supplier->name}» está activo."
            : "«{$supplier->name}» se desactivó.");
    }

    private function validated(Request $request): array
    {
        $data = $this->validateForm($request, [
            'name'      => 'required|string|max:150',
            'contact'   => 'nullable|string|max:150',
            'is_active' => 'boolean',
        ], ['name' => 'nombre', 'contact' => 'contacto']);

        return [...$data, 'is_active' => $request->boolean('is_active')];
    }
}
