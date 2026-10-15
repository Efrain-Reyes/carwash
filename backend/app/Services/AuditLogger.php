<?php

namespace App\Services;

use App\Models\AuditLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class AuditLogger
{
    /** Campos que nunca se guardan con su valor real en la bitácora. */
    private const HIDDEN = ['password', 'remember_token'];

    /** Campos que cambian solos y no aportan información. */
    private const IGNORED = ['created_at', 'updated_at'];

    public static function record(string $event, ?Model $model = null, array $old = [], array $new = [], ?int $userId = null): void
    {
        AuditLog::create([
            'user_id'        => $userId ?? Auth::id(),
            'event'          => $event,
            'auditable_type' => $model ? $model::class : null,
            'auditable_id'   => $model?->getKey(),
            'old_values'     => self::clean($old) ?: null,
            'new_values'     => self::clean($new) ?: null,
            'source'         => self::source(),
            'ip_address'     => app()->runningInConsole() ? null : request()->ip(),
        ]);
    }

    /** Desde dónde se hizo el cambio: la app móvil usa /api, el panel usa /admin. */
    public static function source(): string
    {
        if (app()->runningInConsole() && ! app()->runningUnitTests()) {
            return 'sistema';
        }

        return request()->is('api/*') ? 'app' : 'web';
    }

    private static function clean(array $values): array
    {
        $values = array_diff_key($values, array_flip(self::IGNORED));

        foreach (self::HIDDEN as $field) {
            if (array_key_exists($field, $values)) {
                $values[$field] = '(oculto)';
            }
        }

        return $values;
    }
}
