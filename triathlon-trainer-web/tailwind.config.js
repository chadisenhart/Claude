/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        swim: { DEFAULT: '#3b82f6', light: '#eff6ff' },
        bike: { DEFAULT: '#f97316', light: '#fff7ed' },
        run:  { DEFAULT: '#22c55e', light: '#f0fdf4' },
        brick:{ DEFAULT: '#a855f7', light: '#faf5ff' },
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'San Francisco', 'Helvetica Neue', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
