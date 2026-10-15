<?php

namespace App\Support;

use DateTimeInterface;
use Illuminate\Support\Carbon;

/** Formatos usados en las vistas del panel, iguales a los de la app (L 1,234.00). */
class Format
{
    public static function money(float|int|string|null $amount): string
    {
        $amount = (float) $amount;
        $formatted = number_format(abs($amount), 2);

        return $amount < 0 ? "-L {$formatted}" : "L {$formatted}";
    }

    public static function dateTime(?DateTimeInterface $date): string
    {
        return $date ? Carbon::instance($date)->locale('es')->isoFormat('D MMM YYYY, h:mm a') : '—';
    }

    public static function relative(?DateTimeInterface $date): string
    {
        return $date ? Carbon::instance($date)->locale('es')->diffForHumans(['options' => Carbon::JUST_NOW]) : 'Nunca';
    }
}
