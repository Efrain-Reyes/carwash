@props(['name', 'label', 'hint' => null])

{{-- Etiqueta + control (slot) + ayuda + error de validación de un campo. --}}
<div {{ $attributes }}>
    <label for="{{ $name }}" class="field-label">{{ $label }}</label>
    {{ $slot }}
    @if ($hint)
        <p class="mt-1.5 text-xs text-muted">{{ $hint }}</p>
    @endif
    @error($name)
        <p class="field-error">{{ $message }}</p>
    @enderror
</div>
