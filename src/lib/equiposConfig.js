export const TIPOS_EQUIPO = ["PLANTA", "AVR", "CORPOELEC", "INVERSOR"];
export const KEYWORDS_TIPO = [
  { kw: "planta", tipo: "PLANTA" },
  { kw: "avr", tipo: "AVR" },
  { kw: "corpoelec", tipo: "CORPOELEC" },
  { kw: "corpo", tipo: "CORPOELEC" },
  { kw: "inversor", tipo: "INVERSOR" },
];
export function normalizarTags(tags = []) {
  return Array.from(new Set((Array.isArray(tags) ? tags : [])
    .map(t => String(t).trim())
    .filter(Boolean)
    .map(t => t.toUpperCase())));
}
export function deducirTipoPorNombre(nombre = "") {
  const name = String(nombre).toLowerCase();
  for (const { kw, tipo } of KEYWORDS_TIPO) {
    if (name.includes(kw)) return tipo;
  }
  return null;
}
