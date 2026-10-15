@if ($paginator->hasPages())
    <nav class="flex items-center justify-between gap-3 border-t border-line px-5 py-3 text-sm" aria-label="Paginación">
        <p class="text-muted">
            {{ $paginator->firstItem() }}–{{ $paginator->lastItem() }} de {{ $paginator->total() }}
        </p>
        <div class="flex gap-2">
            @if ($paginator->onFirstPage())
                <span class="btn btn-secondary px-3 py-2 opacity-50">Anterior</span>
            @else
                <a href="{{ $paginator->previousPageUrl() }}" rel="prev" class="btn btn-secondary px-3 py-2">Anterior</a>
            @endif

            @if ($paginator->hasMorePages())
                <a href="{{ $paginator->nextPageUrl() }}" rel="next" class="btn btn-secondary px-3 py-2">Siguiente</a>
            @else
                <span class="btn btn-secondary px-3 py-2 opacity-50">Siguiente</span>
            @endif
        </div>
    </nav>
@endif
