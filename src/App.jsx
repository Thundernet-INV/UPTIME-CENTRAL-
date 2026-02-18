import React, { useEffect } from "react";
import Dashboard from "./views/Dashboard.jsx";
import AdminPlantas from "./components/AdminPlantas.jsx";
import DarkModeCornerButton from "./components/DarkModeCornerButton.jsx";
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

  // Router simple por hash
  const hash = window.location.hash;
  
  if (hash === '#/admin-plantas') {
    return (
      <>
        <DarkModeCornerButton />
        <AdminPlantas />
      </>
    );
  }

  // También permitir acceso sin hash (para pruebas)
  if (window.location.pathname === '/admin-plantas') {
    window.location.hash = '#/admin-plantas';
    return null;
  }

  return (
    <>
      <DarkModeCornerButton />
      <Dashboard />
    </>
  );
}
