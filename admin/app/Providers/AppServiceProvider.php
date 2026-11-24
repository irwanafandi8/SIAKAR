<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('attendance', function (Request $request): Limit {
            $maxAttempts = (int) config('face.max_attempts', 5);
            $identifier = $request->user()?->id_pengguna ?? $request->ip();

            return Limit::perMinute($maxAttempts)->by('attendance:' . $identifier);
        });
    }
}
