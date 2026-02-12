// 🆕 NUEVO SERVICIO - PROMEDIOS DE INSTANCIA
// NO modifica los servicios existentes

const API_BASE = 'http://10.10.31.31:8080/api';

export const promediosApi = {
    // Obtener promedios históricos de una instancia
    async getInstanceAverages(instanceName, hours = 24) {
        try {
            const url = `${API_BASE}/instance/averages/${encodeURIComponent(instanceName)}?hours=${hours}&_=${Date.now()}`;
            const response = await fetch(url, { cache: 'no-store' });
            
            if (!response.ok) return { data: [], count: 0 };
            
            const result = await response.json();
            return result;
        } catch (error) {
            console.error('[PromediosApi] Error:', error);
            return { data: [], count: 0 };
        }
    },

    // Forzar cálculo de promedios
    async calculateAll() {
        try {
            const url = `${API_BASE}/instance/averages/calculate`;
            const response = await fetch(url, { method: 'POST' });
            return await response.json();
        } catch (error) {
            console.error('[PromediosApi] Error calculando:', error);
            return { success: false };
        }
    }
};

export default promediosApi;
