import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    // Forzar inclusión de ciertos módulos
    rollupOptions: {
      output: {
        manualChunks(id) {
          // Asegurar que historyEngine.js se incluya
          if (id.includes('historyEngine')) {
            return 'history'
          }
          if (id.includes('historyApi')) {
            return 'history'
          }
        }
      }
    },
    // Desactivar algunas optimizaciones problemáticas
    minify: 'terser',
    terserOptions: {
      keep_fnames: true,  // Mantener nombres de funciones
      keep_classnames: true  // Mantener nombres de clases
    }
  },
  server: {
    port: 5173,
    host: true
  }
})
