@props(['action', 'active', 'name'])

{{-- Botón Activar/Desactivar con confirmación. Nunca se borra nada del catálogo: se desactiva. --}}
<form method="POST" action="{{ $action }}"
      onsubmit="return confirm(@js($active ? "¿Desactivar «{$name}»? Dejará de aparecer en la app." : "¿Activar «{$name}»?"))">
    @csrf
    @method('PATCH')
    <button type="submit" @class(['btn px-3 py-2', 'btn-danger' => $active, 'btn-secondary' => ! $active])>
        {{ $active ? 'Desactivar' : 'Activar' }}
    </button>
</form>
