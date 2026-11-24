<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Support\ApiResponse;

class EnsureRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  ...$roles
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (!$user) {
            return ApiResponse::error(
                'Token tidak ada atau telah kedaluwarsa.',
                'UNAUTHENTICATED',
                401
            );
        }

        if (!in_array($user->role, $roles, true)) {
            return ApiResponse::error(
                'Peran Anda tidak berhak mengakses layanan ini.',
                'FORBIDDEN_ROLE',
                403
            );
        }

        return $next($request);
    }
}
