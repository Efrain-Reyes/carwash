<?php

namespace App\Http\Controllers\Admin\Concerns;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Valida formularios del panel con mensajes en español (la API conserva los suyos). */
trait ValidatesInSpanish
{
    protected function validateForm(Request $request, array $rules, array $attributes = [], array $messages = []): array
    {
        return $request->validate($rules, [...$this->spanishMessages(), ...$messages], $attributes);
    }

    /** Nombre único sin importar mayúsculas ni espacios ("Carro" = " carro"), en MySQL y en SQLite. */
    protected function uniqueName(string $table, ?int $ignoreId = null): Closure
    {
        return function (string $attribute, mixed $value, Closure $fail) use ($table, $ignoreId) {
            $exists = DB::table($table)
                ->whereRaw('LOWER(TRIM(name)) = ?', [mb_strtolower(trim((string) $value))])
                ->when($ignoreId, fn ($q) => $q->where('id', '!=', $ignoreId))
                ->exists();

            if ($exists) {
                $fail('Ya existe un registro con ese nombre.');
            }
        };
    }

    private function spanishMessages(): array
    {
        return [
            'required'    => 'El campo :attribute es obligatorio.',
            'unique'      => 'Ya existe un registro con ese :attribute.',
            'numeric'     => 'El campo :attribute debe ser un número.',
            'integer'     => 'El campo :attribute debe ser un número entero.',
            'min.numeric' => 'El campo :attribute no puede ser menor que :min.',
            'max.numeric' => 'El campo :attribute no puede ser mayor que :max.',
            'max.string'  => 'El campo :attribute no puede tener más de :max caracteres.',
            'in'          => 'Selecciona un :attribute válido.',
            'exists'      => 'El :attribute seleccionado no es válido.',
            'boolean'     => 'El campo :attribute no es válido.',
            'array'       => 'El campo :attribute no es válido.',
        ];
    }
}
