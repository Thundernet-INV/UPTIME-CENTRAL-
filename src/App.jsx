import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
import "./styles.css";
import "./dark-mode.css";

export default function App() {
  useEffect(() => {
    // Restaurar tema guardado
    try {
      const savedTheme = localStorage.getItem('uptime-theme');
      if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
      }
    } catch (e) {
      console.error('Error al restaurar tema:', e);
    }
  }, []);

  return (
    <>
      <DarkModeCornerButton />
      <Dashboard />
    </>
  );
}
