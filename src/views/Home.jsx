import React, { useEffect, useMemo, useState } from 'react';
import Hero from '../components/Hero';
import InstanceGrid from '../components/InstanceGrid';
import InstanceSection from '../components/InstanceSection';
import { fetchAll } from '../api';

const Home = () => {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Estado de UI
  const [selectedInstance, setSelectedInstance] = useState(null);
  const [search, setSearch] = useState('');          // 🔎 texto de búsqueda global
  const [typeFilter, setTypeFilter] = useState('all'); // filtro por tipo
  const [autoPlay, setAutoPlay] = useState(false);   // playlist (lo afinamos luego)
  const [autoPlayIndex, setAutoPlayIndex] = useState(0);

  // Cargar datos de la API
  useEffect(() => {
    let mounted = true;

    const load = async () => {
      try {
        const data = await fetchAll();
        if (mounted) {
          setSummary(data);
          setError(null);
        }
      } catch (err) {
        console.error('Error al cargar summary:', err);
        if (mounted) {
          setError(err?.message || 'Error cargando datos');
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    load();
    return () => {
      mounted = false;
    };
  }, []);

  // Agrupar monitores por instancia/sede
  const instancesWithMonitors = useMemo(() => {
    if (!summary) return [];

    const instancesArray = Array.isArray(summary.instances)
      ? summary.instances
      : [];

    const monitorsArray = Array.isArray(summary.monitors)
      ? summary.monitors
      : [];

    const map = new Map();

    // Inicializar con las instancias reportadas
    for (const inst of instancesArray) {
      map.set(inst.name, { ...inst, monitors: [] });
    }

    // Agregar monitores a cada instancia
    for (const mon of monitorsArray) {
      const instName = mon.instance || 'Desconocido';
      if (!map.has(instName)) {
        map.set(instName, {
          name: instName,
          ok: true,
          ts: mon.latest?.ts || Date.now(),
          monitors: [],
        });
      }
      map.get(instName).monitors.push(mon);
    }

    // Ordenar por nombre de sede
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, 'es', { sensitivity: 'base' }),
    );
  }, [summary]);

  // 🔁 Playlist entre sedes (por ahora solo lo dejamos listo; lo probamos luego)
  useEffect(() => {
    if (!autoPlay || instancesWithMonitors.length === 0) return;

    const timer = setInterval(() => {
      setAutoPlayIndex((prev) => {
        const next = (prev + 1) % instancesWithMonitors.length;
        const inst = instancesWithMonitors[next];
        setSelectedInstance(inst?.name || null);
        return next;
      });
    }, 5000);

    return () => clearInterval(timer);
  }, [autoPlay, instancesWithMonitors]);

  const handleSelectInstance = (name) => {
    setSelectedInstance(name);
    setAutoPlay(false); // si el usuario hace clic, paramos playlist
  };

  const handleBackToInstances = () => {
    setSelectedInstance(null);
  };

  const activeInstance = useMemo(() => {
    if (!selectedInstance) return null;
    return (
      instancesWithMonitors.find((i) => i.name === selectedInstance) || null
    );
  }, [instancesWithMonitors, selectedInstance]);

  return (
    <main>
      {/* 🔎 Búsqueda principal del banner controla `search` */}
      <Hero onSearch={setSearch} />

      <section className="home-services-section">
        <div className="home-services-container">
          {/* 🔧 Filtros debajo del hero (SOLO tipo + playlist) */}
          <div className="filters-toolbar">
            <select
              className="filter-select"
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
            >
              <option value="all">Todos los tipos</option>
              <option value="http">HTTP</option>
              <option value="ping">PING</option>
              <option value="dns">DNS</option>
              <option value="group">Grupo</option>
            </select>
            <label className="playlist-toggle">
              <input
                type="checkbox"
                checked={autoPlay}
                onChange={() => setAutoPlay((prev) => !prev)}
              />
              <span>Playlist entre sedes</span>
            </label>
          </div>

          {loading && (
            <p className="home-status-message">
              Cargando datos de sedes y servicios...
            </p>
          )}

          {error && (
            <p className="home-status-message home-status-message--error">
              Error al cargar datos: {error}
            </p>
          )}

          {/* Vista: grid de sedes */}
          {!loading && !error && !selectedInstance && (
            <>
              <h2 className="home-section-title">Sedes monitoreadas</h2>
              <InstanceGrid
                instances={instancesWithMonitors}
                onSelectInstance={handleSelectInstance}
              />
            </>
          )}

          {/* Vista: detalle de una sede */}
          {!loading && !error && selectedInstance && activeInstance && (
            <>
              <button
                type="button"
                className="instance-back-button"
                onClick={handleBackToInstances}
              >
                ← Volver a todas las sedes
              </button>
              <InstanceSection
                instance={activeInstance}
                search={search}
                typeFilter={typeFilter}
              />
            </>
          )}

          {!loading && !error && selectedInstance && !activeInstance && (
            <p className="home-status-message">
              No se encontró información para la sede seleccionada.
            </p>
          )}
        </div>
      </section>
    </main>
  );
};

export default Home;
