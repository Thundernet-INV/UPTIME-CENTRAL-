// Script para limpiar TODAS las preferencias del tema
(function() {
    try {
        localStorage.removeItem('uptime-theme');
        console.log('✅ Tema eliminado de localStorage');
        
        // Limpiar cualquier otra clave relacionada
        const keysToRemove = [];
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && (key.includes('theme') || key.includes('dark') || key.includes('light'))) {
                keysToRemove.push(key);
            }
        }
        
        keysToRemove.forEach(key => {
            localStorage.removeItem(key);
            console.log(`✅ Eliminado: ${key}`);
        });
        
        console.log('✅ localStorage limpiado completamente');
    } catch(e) {
        console.error('Error limpiando localStorage:', e);
    }
})();
