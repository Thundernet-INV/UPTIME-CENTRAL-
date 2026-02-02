#!/bin/sh
# Crea SVGs de logos para UptimeKuma Frontend
# Ubicación: public/logos/
# Uso:
#   chmod +x create_service_logos.sh
#   ./create_service_logos.sh

mkdir -p public/logos

echo "Creando logos SVG en public/logos/ ..."

##########################################
# APPLE
##########################################
cat > public/logos/apple.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
<path fill="#000" d="M176 135c1-23 19-34 20-35-11-16-28-18-34-18-15-1-30 8-38 8s-20-8-33-7c-17 1-32 10-41 26-18 31-5 77 12 102 8 12 18 25 31 24 12-1 16-8 31-8 15 0 18 8 32 8 13-1 22-12 30-24 9-13 12-25 13-26-1 0-25-10-23-42z"/>
<path fill="#000" d="M158 56c6-8 10-19 9-30-9 1-21 7-27 15-6 7-11 18-9 29 10 1 21-6 27-14z"/>
</svg>
SVG

##########################################
# TIKTOK
##########################################
cat > public/logos/tiktok.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
<rect width="256" height="256" fill="#000"/>
<path fill="#69C9D0" d="M164 64c12 12 26 20 42 22v32c-15-1-29-7-42-17v60c0 57-68 84-105 42 30 11 59-10 59-42V64h46z"/>
<path fill="#EE1D52" d="M161 64h-46v97c0 32-29 53-59 42 16 19 44 27 71 16 23-10 38-32 38-58V64z"/>
</svg>
SVG

##########################################
# WHATSAPP
##########################################
cat > public/logos/whatsapp.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" rx="56" fill="#25D366"/>
  <path fill="#FFFFFF" d="M129.8 54c-40.1 0-72.6 32.5-72.6 72.6 0 12.8 3.3 25.5 9.6 36.7l-10.2 37.3 38.2-10c10.8 5.7 22.9 8.7 35 8.7 40.1 0 72.6-32.5 72.6-72.6S169.9 54 129.8 54zm41.3 94.3c-1.8 5.1-10.3 10-14.4 10.6-3.6.5-8.1.7-13.1-1.5-3-1.2-6.7-2.2-11.5-4.3-20.1-8.8-33.1-29.3-34.1-30.7-.9-1.2-8.1-10.7-8.1-20.5 0-9.8 5.1-14.6 6.9-16.7 1.8-2 4-2.5 5.3-2.5 1.4 0 2.7.1 3.8.1 1.2.1 2.9-.5 4.5 3.4 1.8 4.4 6.1 15 6.7 16.1.5 1.1.9 2.3.2 3.6-.7 1.2-1.1 1.8-2.1 2.9-.9 1-1.8 2.2-2.5 3-.8.8-1.6 1.7-.7 3.3.9 1.6 3.9 6.4 8.3 10.4 5.7 5.1 10.5 6.7 12.1 7.5 1.6.7 2.5.6 3.4-.4.9-1 3.9-4.5 4.9-6.1 1.1-1.6 2.1-1.3 3.4-.8 1.3.5 8.4 3.9 9.9 4.6 1.5.7 2.5 1.1 2.9 1.7.4.6.4 5.1-1.4 10.2z"/>
</svg>
SVG

##########################################
# IPTV (icono genérico tipo TV)
##########################################
cat > public/logos/iptv.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
<rect width="256" height="170" y="30" rx="20" fill="#1E293B"/>
<rect x="80" y="210" width="96" height="16" rx="8" fill="#475569"/>
<polygon fill="#38BDF8" points="110,90 110,150 160,120"/>
</svg>
SVG

##########################################
# YOUTUBE
##########################################
cat > public/logos/youtube.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" rx="40" fill="#FF0000"/>
  <polygon fill="#FFFFFF" points="105,168 105,88 175,128"/>
</svg>
SVG

##########################################
# FACEBOOK
##########################################
cat > public/logos/facebook.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" rx="56" fill="#1877F2"/>
  <path fill="#FFFFFF" d="M175 84h-22c-9.3 0-11 3.8-11 10.9v19.1h32.5l-4.2 32.5h-28.3V224h-34.1v-77.5H87V114h20.9V96.1C107.9 67 124 48 156.7 48c15.3 0 26.3 1.1 29.3 1.6V84z"/>
</svg>
SVG

##########################################
# GOOGLE
##########################################
cat > public/logos/google.svg << 'SVG'
<svg width="256" height="256" xmlns="http://www.w3.org/2000/svg">
<rect width="256" height="256" fill="#fff"/>
<path fill="#4285F4" d="M231 130c0-8-1-16-3-23H129v43h58c-2 11-8 20-17 27v23h28c17-16 33-42 33-70z"/>
<path fill="#34A853" d="M129 232c23 0 43-8 57-21l-28-23c-8 5-19 8-29 8-22 0-41-15-48-35H52v22c14 29 45 49 77 49z"/>
<path fill="#FBBC04" d="M81 161c-4-11-5-23 0-35v-22H52c-15 30-15 66 0 96l29-22z"/>
<path fill="#EA4335" d="M129 72c13 0 25 4 34 12l26-25c-17-16-39-25-60-25-32 0-63 20-77 49l29 22c7-20 26-35 48-35z"/>
</svg>
SVG

##########################################
# INSTAGRAM
##########################################
cat > public/logos/instagram.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="g" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#F58529"/>
      <stop offset="50%" stop-color="#DD2A7B"/>
      <stop offset="100%" stop-color="#8134AF"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="56" fill="url(#g)"/>
  <circle cx="128" cy="128" r="50" fill="none" stroke="#FFF" stroke-width="20"/>
  <circle cx="185" cy="71" r="20" fill="#FFF"/>
</svg>
SVG

##########################################
# TELEGRAM
##########################################
cat > public/logos/telegram.svg << 'SVG'
<svg width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="56" fill="#0088CC"/>
  <path fill="#fff" d="M203 67L40 121c-6 2-7 10-1 13l36 17 14 45c2 6 10 8 14 3l21-20 36 26c5 4 12 1 14-5l33-118c2-7-4-12-11-10z"/>
</svg>
SVG

##########################################
# MICROSOFT
##########################################
cat > public/logos/microsoft.svg << 'SVG'
<svg width="256" height="256">
  <rect width="256" height="256" fill="#fff"/>
  <rect x="20"  y="20"  width="100" height="100" fill="#F25022"/>
  <rect x="136" y="20"  width="100" height="100" fill="#7FBA00"/>
  <rect x="20"  y="136" width="100" height="100" fill="#00A4EF"/>
  <rect x="136" y="136" width="100" height="100" fill="#FFB900"/>
</svg>
SVG

##########################################
# NETFLIX
##########################################
cat > public/logos/netflix.svg << 'SVG'
<svg width="256" height="256">
  <rect width="256" height="256" fill="#000"/>
  <path fill="#E50914" d="M96 40v176l64-40V0z"/>
</svg>
SVG

echo "LOGOS SVG CREADOS CORRECTAMENTE ✔"
