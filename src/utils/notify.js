/**
 * Notificaciones sin sonido:
 * - Si hay permiso de Notification API: muestra una notificación del sistema (silent: true).
 * - Si no hay permiso o no existe la API: muestra un toast visual in-app (arriba-derecha), sin audio.
 */
export function notify(title, body) {
  try {
    if (typeof window === 'undefined') return;

    // 1) Notification API (silent)
    if ('Notification' in window) {
      const show = () => {
        try {
          new Notification(title || 'Notificación', {
            body: body || '',
            silent: true,          // 👍 sin sonido
            requireInteraction: false
          });
        } catch {
          // Si falla la creación, usar toast
          showToast(title, body);
        }
      };

      if (Notification.permission === 'granted') {
        show();
        return;
      }
      if (Notification.permission === 'default') {
        Notification.requestPermission().then((p) => {
          if (p === 'granted') show();
          else showToast(title, body);
        }).catch(() => showToast(title, body));
        return;
      }
      // 'denied'
      showToast(title, body);
      return;
    }

    // 2) Fallback: toast visual (sin sonido)
    showToast(title, body);
  } catch {
    // ante cualquier excepción, intentar el toast
    try { showToast(title, body); } catch {}
  }
}

/** Toast ligero in-app (arriba-derecha), se autodestruye en ~6s */
function showToast(title, body) {
  const id = '__toast_container';
  let cont = document.getElementById(id);
  if (!cont) {
    cont = document.createElement('div');
    cont.id = id;
    Object.assign(cont.style, {
      position: 'fixed',
      top: '10px',
      right: '10px',
      zIndex: 99999,
      display: 'flex',
      flexDirection: 'column',
      gap: '8px',
      pointerEvents: 'none'
    });
    document.body.appendChild(cont);
  }

  const card = document.createElement('div');
  Object.assign(card.style, {
    background: '#111827',
    color: '#fff',
    borderRadius: '10px',
    boxShadow: '0 6px 18px rgba(0,0,0,.25)',
    padding: '10px 12px',
    minWidth: '260px',
    maxWidth: '360px',
    fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, sans-serif',
    pointerEvents: 'auto',
    opacity: '0',
    transform: 'translateY(-6px)',
    transition: 'all .18s ease'
  });

  const h = document.createElement('div');
  h.textContent = title || 'Notificación';
  h.style.fontWeight = '700';
  h.style.marginBottom = '4px';

  const b = document.createElement('div');
  b.textContent = body || '';
  b.style.fontSize = '12.5px';
  b.style.opacity = '0.9';

  const close = document.createElement('button');
  close.textContent = 'Cerrar';
  Object.assign(close.style, {
    marginTop: '8px',
    border: '1px solid #374151',
    background: 'transparent',
    color: '#fff',
    borderRadius: '6px',
    padding: '3px 8px',
    cursor: 'pointer'
  });
  close.onclick = () => remove();

  card.appendChild(h);
  if (body) card.appendChild(b);
  card.appendChild(close);
  cont.appendChild(card);

  // animación de entrada
  requestAnimationFrame(() => {
    card.style.opacity = '1';
    card.style.transform = 'translateY(0)';
  });

  // autodestruir en 6s (si el usuario no cierra)
  const t = setTimeout(remove, 6000);

  function remove() {
    clearTimeout(t);
    card.style.opacity = '0';
    card.style.transform = 'translateY(-6px)';
    setTimeout(() => {
      try { cont.removeChild(card); } catch {}
      // eliminar contenedor si no quedan toasts
      if (cont && cont.children.length === 0) {
        try { cont.parentNode.removeChild(cont); } catch {}
      }
    }, 180);
  }
}
