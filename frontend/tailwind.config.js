module.exports = {
    content: ['./src/**/*.{js,jsx,ts,tsx}'],
    darkMode: 'class',
    theme: {
        extend: {
            keyframes: {
                fadeIn: {
                    '0%': { opacity: 0 },
                    '100%': { opacity: 1 },
                },
                slideInFromLeft: {
                    '0%': { transform: 'translateX(-30px)', opacity: 0 },
                    '100%': { transform: 'translateX(0)', opacity: 1 },
                },
                slideInFromRight: {
                    '0%': { transform: 'translateX(30px)', opacity: 0 },
                    '100%': { transform: 'translateX(0)', opacity: 1 },
                },
                slideInFromBottom: {
                    '0%': { transform: 'translateY(20px)', opacity: 0 },
                    '100%': { transform: 'translateY(0)', opacity: 1 },
                },
            },
            animation: {
                fadeIn: 'fadeIn 0.4s ease-out',
                slideInLeft: 'slideInFromLeft 0.5s ease-out',
                slideInRight: 'slideInFromRight 0.5s ease-out',
                slideInBottom: 'slideInFromBottom 0.5s ease-out',
            },
        },
    },
    plugins: [],
};