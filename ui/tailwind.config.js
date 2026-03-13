import daisyui from 'daisyui';

export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        display: ['"Space Grotesk"', 'Inter', 'system-ui', 'sans-serif'],
        body: ['"Space Grotesk"', 'Inter', 'system-ui', 'sans-serif']
      }
    }
  },
  plugins: [daisyui],
  daisyui: {
    themes: ['cupcake', 'emerald']
  }
};
