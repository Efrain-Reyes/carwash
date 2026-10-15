@props(['active'])

@if ($active)
    <span class="badge bg-ok-bg text-ok-fg"><span class="size-1.5 rounded-full bg-ok-fg"></span>Activo</span>
@else
    <span class="badge bg-bad-bg text-bad-fg"><span class="size-1.5 rounded-full bg-bad-fg"></span>Inactivo</span>
@endif
