/** @type {import('tailwindcss').Config} */
export default {
    content: [
        './resources/views/**/*.blade.php',
        './resources/js/**/*.js',
    ],
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
            fontFamily: {
                sans: ['"DM Sans"', 'system-ui', 'sans-serif'],
            },
            borderRadius: {
                card: '12px',
                input: '10px',
            },
        },
    },
    plugins: [],
};
