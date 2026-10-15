@extends('admin.layouts.app')

@php
    $editing = $user->exists;
    $currentRole = old('role', $user->roles->first()?->name ?? 'operador');
    $isMe = $editing && $user->is(auth()->user());
@endphp

@section('title', $editing ? 'Editar usuario' : 'Nuevo usuario')

@section('content')
    <a href="{{ route('admin.users.index') }}" class="mb-4 inline-block text-sm font-semibold text-accent-600 hover:underline">← Volver a usuarios</a>

    <form method="POST" action="{{ $editing ? route('admin.users.update', $user) : route('admin.users.store') }}" class="card max-w-2xl space-y-6 p-6">
        @csrf
        @if ($editing) @method('PUT') @endif

        <div class="grid gap-5 sm:grid-cols-2">
            <div class="sm:col-span-2">
                <label for="name" class="field-label">Nombre</label>
                <input id="name" name="name" type="text" value="{{ old('name', $user->name) }}" required maxlength="100" class="field">
                @error('name') <p class="field-error">{{ $message }}</p> @enderror
            </div>

            <div class="sm:col-span-2">
                <label for="email" class="field-label">Correo</label>
                <input id="email" name="email" type="email" value="{{ old('email', $user->email) }}" required maxlength="150" autocomplete="off" class="field">
                <p class="mt-1.5 text-xs text-muted">Es con lo que inicia sesión en la app.</p>
                @error('email') <p class="field-error">{{ $message }}</p> @enderror
            </div>

            <div>
                <label for="role" class="field-label">Rol</label>
                <select id="role" name="role" class="field" @disabled($isMe)>
                    @foreach ($roles as $value => $label)
                        <option value="{{ $value }}" @selected($currentRole === $value)>{{ $label }}</option>
                    @endforeach
                </select>
                @if ($isMe)
                    {{-- Un select deshabilitado no se envía; mandamos el valor actual para no perder el rol. --}}
                    <input type="hidden" name="role" value="administrador">
                    <p class="mt-1.5 text-xs text-muted">No puedes cambiar tu propio rol.</p>
                @endif
                @error('role') <p class="field-error">{{ $message }}</p> @enderror
            </div>

            <div class="flex items-end">
                <input type="hidden" name="is_active" value="{{ $isMe ? 1 : 0 }}">
                <label class="flex items-center gap-3 rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">
                    <input type="checkbox" name="is_active" value="1" class="size-4 rounded border-line" @checked(old('is_active', $user->is_active)) @disabled($isMe)>
                    Cuenta activa
                </label>
            </div>
        </div>

        <fieldset class="border-t border-line pt-5">
            <legend class="sr-only">Contraseña</legend>
            <p class="mb-4 text-sm text-muted">
                @if ($editing)
                    Deja la contraseña en blanco para no cambiarla. Si la cambias, se cierran sus sesiones en la app.
                @else
                    Mínimo 8 caracteres.
                @endif
            </p>
            <div class="grid gap-5 sm:grid-cols-2">
                <div>
                    <label for="password" class="field-label">{{ $editing ? 'Nueva contraseña' : 'Contraseña' }}</label>
                    <input id="password" name="password" type="password" minlength="8" autocomplete="new-password" class="field" @required(! $editing)>
                    @error('password') <p class="field-error">{{ $message }}</p> @enderror
                </div>
                <div>
                    <label for="password_confirmation" class="field-label">Confirmar contraseña</label>
                    <input id="password_confirmation" name="password_confirmation" type="password" minlength="8" autocomplete="new-password" class="field" @required(! $editing)>
                </div>
            </div>
        </fieldset>

        <div class="flex justify-end gap-3 border-t border-line pt-5">
            <a href="{{ route('admin.users.index') }}" class="btn btn-secondary">Cancelar</a>
            <button type="submit" class="btn btn-primary">{{ $editing ? 'Guardar cambios' : 'Crear usuario' }}</button>
        </div>
    </form>
@endsection
