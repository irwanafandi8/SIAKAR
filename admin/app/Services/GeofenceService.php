<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\LokasiKantor;

class GeofenceService
{
    public const EARTH_RADIUS_METERS = 6371000.0;

    /**
     * Hitung jarak permukaan bumi antara dua titik koordinat GPS dalam meter (rumus Haversine).
     */
    public function haversineDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $radLat1 = deg2rad($lat1);
        $radLat2 = deg2rad($lat2);

        $a = sin($dLat / 2) * sin($dLat / 2)
            + cos($radLat1) * cos($radLat2) * sin($dLon / 2) * sin($dLon / 2);

        $a = max(0.0, min(1.0, $a));
        $c = 2 * atan2(sqrt($a), sqrt(1.0 - $a));

        return self::EARTH_RADIUS_METERS * $c;
    }

    /**
     * Cari lokasi kantor terdekat yang radiusnya mencakup titik GPS (jarak <= radius_meter).
     *
     * @param  float  $latitude
     * @param  float  $longitude
     * @param  iterable<LokasiKantor>|null  $locations
     * @return array{location: LokasiKantor, distance_meter: float}|null
     */
    public function findNearestValidLocation(float $latitude, float $longitude, ?iterable $locations = null): ?array
    {
        $locations = $locations ?? LokasiKantor::all();

        $nearestLocation = null;
        $nearestDistance = null;

        foreach ($locations as $lokasi) {
            $distance = $this->haversineDistance(
                $latitude,
                $longitude,
                (float) $lokasi->latitude,
                (float) $lokasi->longitude
            );

            // Toleransi kecil floating-point (1e-6 m) agar tepat di batas radius tetap lolos
            if ($distance <= ((float) $lokasi->radius_meter + 1e-6)) {
                if ($nearestDistance === null || $distance < $nearestDistance) {
                    $nearestLocation = $lokasi;
                    $nearestDistance = $distance;
                }
            }
        }

        if ($nearestLocation === null) {
            return null;
        }

        return [
            'location'       => $nearestLocation,
            'distance_meter' => $nearestDistance,
        ];
    }

    /**
     * Validasi titik GPS terhadap semua lokasi kantor; lempar OUT_OF_RADIUS bila tidak ada yang mencakup.
     *
     * @param  float  $latitude
     * @param  float  $longitude
     * @param  iterable<LokasiKantor>|null  $locations
     * @return array{location: LokasiKantor, distance_meter: float}
     *
     * @throws DomainException
     */
    public function validateGeofence(float $latitude, float $longitude, ?iterable $locations = null): array
    {
        $locationsList = $locations !== null
            ? (is_array($locations) ? $locations : iterator_to_array($locations))
            : LokasiKantor::all()->all();

        $valid = $this->findNearestValidLocation($latitude, $longitude, $locationsList);
        if ($valid !== null) {
            return $valid;
        }

        $closestOverall = null;
        foreach ($locationsList as $lokasi) {
            $distance = $this->haversineDistance(
                $latitude,
                $longitude,
                (float) $lokasi->latitude,
                (float) $lokasi->longitude
            );
            if ($closestOverall === null || $distance < $closestOverall) {
                $closestOverall = $distance;
            }
        }

        throw new DomainException(
            'Lokasi Anda berada di luar radius kantor.',
            'OUT_OF_RADIUS',
            422,
            null,
            $closestOverall !== null ? ['distance_meter' => round($closestOverall, 2)] : null
        );
    }
}
