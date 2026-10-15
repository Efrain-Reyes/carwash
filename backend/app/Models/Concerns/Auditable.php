<?php

namespace App\Models\Concerns;

use App\Services\AuditLogger;
use Illuminate\Database\Eloquent\Model;

/**
 * Registra en la bitácora cada vez que el modelo se crea, edita o elimina.
 *
 * Funciona con los eventos de Eloquent, así que captura los cambios hechos desde
 * la app y desde el panel sin tocar los controladores. Ojo: las actualizaciones
 * masivas (Model::where(...)->update([...])) no disparan eventos y no quedan aquí.
 */
trait Auditable
{
    public static function bootAuditable(): void
    {
        static::created(function (Model $model) {
            AuditLogger::record('created', $model, [], $model->getAttributes());
        });

        static::updated(function (Model $model) {
            $changes = $model->getChanges();
            unset($changes['updated_at']);

            if ($changes === []) {
                return;
            }

            $old = array_intersect_key($model->getRawOriginal(), $changes);

            AuditLogger::record('updated', $model, $old, $changes);
        });

        static::deleted(function (Model $model) {
            AuditLogger::record('deleted', $model, $model->getRawOriginal(), []);
        });
    }
}
