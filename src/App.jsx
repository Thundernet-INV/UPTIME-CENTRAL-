import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import AdminPlantas from "./components/AdminPlantas.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
import ReportesCombustible from "./components/ReportesCombustible.jsx";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  useEffect(() => {
    try {
      const savedTheme = localStorage.getItem('uptime-theme');
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
      }
    } catch (e) {}
  }, []);

  // Router por hash
  const hash = window.location.hash;

  // Ruta para admin-plantas
  if (hash === '#/admin-plantas') {
    return (
      <>
        <DarkModeCornerButton />
        <AdminPlantas />
      </>
    );
  }

  // Ruta para reportes de combustible
  if (hash === '#/reportes') {
    return (
      <>
        <DarkModeCornerButton />
        <ReportesCombustible />
      </>
    );
  }

  // Ruta para energía (si usas #/energia)
if (hash === '#/energia') {
  return (
    <>
      <DarkModeCornerButton />
      <Energia monitorsAll={[]} />
    </>
  );
}
  return (
    <>
      <DarkModeCornerButton />
      <Dashboard />
    </>
  );
}
