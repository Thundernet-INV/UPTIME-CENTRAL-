import React from 'react';
import SearchBar from './SearchBar';

const Hero = ({ onSearch }) => {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero-overlay" />
      <div className="hero-content">
        <h1 id="hero-title" className="hero-title">
          Monitor de problemas e interrupciones en tiempo real
        </h1>
        <p className="hero-subtitle">
          Te avisamos cuando tus servicios favoritos presentan incidencias.
        </p>
        {/* 🔎 Aquí conectamos la barra del banner con el estado `search` de Home */}
        <SearchBar onSearch={onSearch} />
      </div>

      <div className="hero-wave" aria-hidden="true" />
    </section>
  );
};

export default Hero;
