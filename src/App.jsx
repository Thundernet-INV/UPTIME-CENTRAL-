import React from 'react';
import Home from './views/Home';
import './styles.css';

function App() {
  return (
    <div className="app-root">
      <header className="app-header">
        <div className="app-header-left">
          <span className="app-logo-text">Uptime Central</span>
        </div>
      </header>
      <Home />
    </div>
  );
}

export default App;
