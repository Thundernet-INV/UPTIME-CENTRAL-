#!/bin/sh
set -eu

APPROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
CSS="$APPROOT/src/styles.css"

cd "$APPROOT"
ts=$(date +%Y%m%d_%H%M%S)
[ -f "$CSS" ] || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== Inyectando CSS anti-overflow (v2: badge absoluto + padding de reserva) =="

cat >> "$CSS" <<'CSS'
/* ===========================================================
   Copilot patch v2 — Tarjetas sin desbordes (header robusto)
   - Badge UP/DOWN en posición absoluta (top-right) => no empuja texto
   - Título 2 líneas con elipsis; subtítulo 1 línea con elipsis
   - Contenedores con min-width:0; textos con overflow hidden
   =========================================================== */

/* --- Base tarjeta --- */
.card, .monitor-card, .service-card {
  display:flex; flex-direction:column; gap:8px;
  border-radius:12px; border:1px solid #e5e7eb; background:#fff;
  padding:10px 12px; min-width:0;
}

/* --- Header tarjeta (1er hijo) --- */
.card > *:first-child,
.monitor-card > *:first-child,
.service-card > *:first-child,
.card-head, .monitor-card_head, .service-card_head {
  position:relative;            /* <- necesario para posicionar el badge */
  display:flex; align-items:center; gap:10px;
  min-width:0;                  /* <- CLAVE para elipsis abajo */
}

/* --- Bloque de textos (normalmente 2º hijo del header) --- */
.card > *:first-child > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2),
.service-card > *:first-child > :nth-child(2),
.card-head_texts, .monitor-cardtexts, .service-card_texts {
  display:flex; flex-direction:column;
  min-width:0; overflow:hidden;
  padding-right:84px;           /* <- reserva espacio para el badge absoluto */
}

/* --- Título: 2 líneas con elipsis --- */
.card > *:first-child > :nth-child(2) > :first-child,
.monitor-card > *:first-child > :nth-child(2) > :first-child,
.service-card > *:first-child > :nth-child(2) > :first-child,
.card-title, .monitor-card_title, .service-card_title {
  color:#111827; font-weight:600; min-width:0; overflow:hidden;
  display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical;
  text-overflow:ellipsis; white-space:normal;
  line-height:1.2; font-size:15px;
}

/* --- Subtítulo: 1 línea con elipsis --- */
.card > *:first-child > :nth-child(2) > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2) > :nth-child(2),
.service-card > *:first-child > :nth-child(2) > :nth-child(2),
.card-subtitle, .monitor-card_subtitle, .service-card_subtitle {
  color:#6b7280; font-size:12.5px;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0;
}

/* --- Logo/Icono: fijo, no empuja --- */
.card img, .monitor-card img, .service-card img,
.card-logo, .monitor-card_logo, .service-card_logo {
  flex:0 0 auto; width:22px; height:22px; border-radius:6px; object-fit:contain;
}

/* --- Badge UP/DOWN: ABSOLUTO en top-right dentro del header --- */
.card > *:first-child .badge,
.monitor-card > *:first-child .badge,
.service-card > *:first-child .badge,
.card > *:first-child .status-badge,
.monitor-card > *:first-child .status-badge,
.service-card > *:first-child .status-badge,
.card > *:first-child .monitor-card__badge,
.monitor-card > *:first-child .monitor-card__badge,
.service-card > *:first-child .service-card__badge {
  position:absolute; top:8px; right:10px;
  max-width:72px; padding:2px 8px; border-radius:9999px;
  font-size:11px; font-weight:700; line-height:1.6; text-align:center;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
  background:#e8f8ef; color:#0e9f6e;   /* default (UP) */
}
.badge--up  { background:#e8f8ef !important; color:#0e9f6e !important; }
.badge--down{ background:#fde8e8 !important; color:#d93025 !important; }

/* --- Pie de tarjeta --- */
.card-foot, .monitor-card_foot, .service-card_foot {
  display:flex; align-items:center; gap:10px; min-width:0;
}
.sparkline, .monitor-card_sparkline, .service-card_sparkline { min-width:0; width:100%; }

/* --- Acciones --- */
.card-actions, .monitor-card_actions, .service-card_actions { display:flex; gap:8px; flex-wrap:wrap; }

/* --- Grid responsivo --- */
.cards-grid, .services-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(260px,1fr)); gap:14px; }

/* --- Ajustes finos en pantallas muy angostas --- */
@media (max-width: 380px) {
  .card > *:first-child > :nth-child(2),
  .monitor-card > *:first-child > :nth-child(2),
  .service-card > *:first-child > :nth-child(2),
  .card-head_texts, .monitor-cardtexts, .service-card_texts {
    padding-right:72px; /* badge levemente más pequeño */
  }
  .card > *:first-child .badge,
  .monitor-card > *:first-child .badge,
  .service-card > *:first-child .badge,
  .status-badge, .monitor-card_badge, .service-card_badge {
    max-width:64px; top:6px; right:8px; font-size:10.5px;
  }
}
CSS

echo "== CSS inyectado. Compilando =="
npm run build

echo "== Desplegando =="
rsync -av --delete "$APPROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: títulos/subtítulos con elipsis, badge absoluto y tarjetas sin desbordes."
