<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Admin SIAKAR')</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        primary: '#338F4A',
                        'primary-dark': '#1F6B33',
                        navy: '#1E1E49',
                        background: '#FFFEF2',
                        surface: '#FFFFFF',
                        tint: '#F1F7EF',
                        outline: '#CFDDD2',
                        muted: '#5B5B7A',
                    },
                    borderRadius: {
                        card: '12px',
                        input: '10px',
                    }
                }
            }
        }
    </script>
</head>
<body class="bg-background text-navy min-h-screen font-sans antialiased">
    <div class="min-h-screen flex">
        <!-- Sidebar Navy -->
        <aside class="w-64 bg-navy text-white flex flex-col shrink-0">
            <div class="px-6 py-5 border-b border-white/10">
                <a href="{{ route('admin.dashboard') }}" class="text-xl font-bold tracking-tight">SIAKAR Admin</a>
                <p class="text-xs text-white/70 mt-1">Panel Manajemen Absensi</p>
            </div>

            <nav class="flex-1 px-4 py-5 space-y-1 text-sm">
                <a href="{{ route('admin.dashboard') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.dashboard') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Dasbor
                </a>
                <a href="{{ route('admin.karyawan.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.karyawan.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Karyawan
                </a>
                <a href="{{ route('admin.departemen.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.departemen.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Departemen
                </a>
                <a href="{{ route('admin.jabatan.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.jabatan.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Jabatan
                </a>
                <a href="{{ route('admin.shift.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.shift.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Shift
                </a>
                <a href="{{ route('admin.jadwal.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.jadwal.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Jadwal Karyawan
                </a>
                <a href="{{ route('admin.lokasi.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.lokasi.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Lokasi Kantor
                </a>
                <a href="{{ route('admin.hari-libur.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.hari-libur.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Hari Libur
                </a>
                <a href="{{ route('admin.absensi.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.absensi.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Koreksi Absensi
                </a>
                <a href="{{ route('admin.laporan.index') }}"
                   class="block px-3 py-2.5 rounded-input {{ request()->routeIs('admin.laporan.*') ? 'bg-primary text-white font-semibold' : 'text-white/80 hover:bg-white/10' }}">
                    Laporan &amp; CSV
                </a>
            </nav>

            <div class="p-4 border-t border-white/10">
                <form method="POST" action="{{ route('admin.logout') }}">
                    @csrf
                    <button type="submit"
                            class="w-full px-3 py-2 text-left text-sm text-white/80 hover:bg-white/10 rounded-input">
                        Keluar ({{ auth()->user()->username ?? 'Admin' }})
                    </button>
                </form>
            </div>
        </aside>

        <!-- Konten Utama Krem -->
        <div class="flex-1 flex flex-col min-w-0">
            <header class="bg-surface border-b border-outline px-6 py-4 flex items-center justify-between">
                <h1 class="text-lg font-bold text-navy">@yield('header', 'Dasbor')</h1>
                <span class="text-sm text-muted">{{ auth()->user()->karyawan->nama ?? auth()->user()->username ?? '' }}</span>
            </header>

            <main class="flex-1 p-6">
                @if (session('success'))
                    <div class="mb-4 px-4 py-3 rounded-card bg-[#E3F3E7] text-[#1F6B33] border border-outline text-sm font-medium">
                        {{ session('success') }}
                    </div>
                @endif

                @if (session('error'))
                    <div class="mb-4 px-4 py-3 rounded-card bg-[#FBE3E3] text-[#A32121] border border-outline text-sm font-medium">
                        {{ session('error') }}
                    </div>
                @endif

                @yield('content')
            </main>
        </div>
    </div>
</body>
</html>
