import React, { useEffect, useState } from "react";
import Dashboard from "./views/Dashboard.jsx";
import AdminPlantas from "./components/AdminPlantas.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
import ReportesCombustible from "./components/ReportesCombustible.jsx";
import EnergiaDashboard from "./components/EnergiaDashboard.jsx";
import { fetchAll } from "./api.js";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  const [hash, setHash] = useState(window.location.hash);
  const [monitorsAll, setMonitorsAll] = useState([]);

  // Cargar monitores al inicio
  useEffect(() => {
    const cargarMonitores = async () => {
      try {
        const data = await fetchAll();
        if (data?.monitors) {
          setMonitorsAll(data.monitors);
        }
      } catch (error) {
        console.error('Error cargando monitores:', error);
      }
    };
    
    cargarMonitores();
    
    // Recargar cada 30 segundos
    const interval = setInterval(cargarMonitores, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const savedTheme = localStorage.getItem('uptime-theme');
    if (savedTheme === 'dark') {
      document.body.classList.add('dark-mode');
    }
  }, []);

  useEffect(() => {
    const handleHashChange = () => {
      setHash(window.location.hash);
    };

    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

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

  // Ruta para energía - AHORA CON DATOS
  if (hash === '#/energia') {
    return (
      <>
        <DarkModeCornerButton />
        <EnergiaDashboard monitorsAll={monitorsAll} />
      </>
    );
  }

  // Ruta para comparar
  if (hash === '#/comparar') {
    return (
      <>
        <DarkModeCornerButton />
        <Dashboard monitorsAll={monitorsAll} />
      </>
    );
  }

  // Home
  return (
    <>
      <DarkModeCornerButton />
      <Dashboard monitorsAll={monitorsAll} />
    </>
  );
}
