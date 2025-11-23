import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'axiom-green': '#10b981',
        'axiom-blue': '#3b82f6',
        'axiom-red': '#ef4444',
        'axiom-yellow': '#f59e0b',
      },
    },
  },
  plugins: [],
}
export default config
