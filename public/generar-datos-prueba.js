// Script para generar datos de prueba en el backend
// Ejecutar en consola del navegador cuando estés en el dashboard

(async function generarDatosPrueba() {
  console.log('📊 Generando datos de prueba...');
  
  const BACKEND_URL = 'http://10.10.31.31:8080/api';
  const INSTANCIAS = ['Caracas', 'Guanare', 'Valencia', 'Maracaibo', 'Barquisimeto'];
  const SERVICIOS = ['WhatsApp', 'Facebook', 'Instagram', 'YouTube', 'Google'];
  
  const now = Date.now();
  const horaInicio = now - (7 * 24 * 60 * 60 * 1000); // 7 días atrás
  
  for (const instancia of INSTANCIAS) {
    for (const servicio of SERVICIOS) {
      const monitorId = `${instancia}_${servicio}`;
      
      // Generar 100 puntos de datos para los últimos 7 días
      for (let i = 0; i < 100; i++) {
        const timestamp = horaInicio + (i * 60 * 60 * 1000); // 1 punto por hora
        
        const dataPoint = {
          monitorId: monitorId,
          timestamp: timestamp,
          responseTime: Math.floor(Math.random() * 200) + 50, // 50-250ms
          status: Math.random() > 0.1 ? 1 : 0 // 90% UP
        };
        
        try {
          await fetch(`${BACKEND_URL}/history`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(dataPoint)
          });
        } catch (e) {
          console.error(`Error enviando datos para ${monitorId}:`, e);
        }
      }
      
      console.log(`✅ Datos generados para ${monitorId}`);
    }
  }
  
  console.log('🎉 Datos de prueba generados exitosamente!');
  console.log('Recarga el dashboard para ver los datos.');
})();
