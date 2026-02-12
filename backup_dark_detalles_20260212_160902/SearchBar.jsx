import React, { useState } from 'react';

const SearchBar = ({ onSearch }) => {
  const [query, setQuery] = useState('');

  const handleSubmit = (event) => {
    event.preventDefault();
    if (onSearch) {
      onSearch(query);
    }
  };

  return (
    <form className="hero-search" onSubmit={handleSubmit} role="search">
      <label className="sr-only" htmlFor="hero-search-input">
        Buscar un servicio
      </label>
      <input
        id="hero-search-input"
        type="search"
        className="hero-search-input"
        placeholder="Busca un servicio (WhatsApp, YouTube, Instagram...)"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <button type="submit" className="hero-search-button">
        Buscar
      </button>
    </form>
  );
};

export default SearchBar;
