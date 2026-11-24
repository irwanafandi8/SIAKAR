<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Masuk Admin — SIAKAR</title>
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
<body class="bg-background text-navy min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md bg-surface border border-outline rounded-card p-6">
        <h1 class="text-2xl font-bold text-navy mb-1">Masuk Admin SIAKAR</h1>
        <p class="text-sm text-muted mb-6">Silakan masuk menggunakan akun administrator.</p>

        <form method="POST" action="{{ route('admin.login.submit') }}">
            @csrf
            <x-form-field name="username" label="Username" required autofocus />
            <x-form-field name="password" label="Password" type="password" required />

            <x-button class="w-full mt-2">Masuk</x-button>
        </form>
    </div>
</body>
</html>
