      {/* BOTÓN FLOTANTE */}
      <button
        onClick={() => window.location.hash = '#/admin-plantas'}
        style={{
          position: 'fixed',
          bottom: '30px',
          right: '30px',
          zIndex: 99999,
          padding: '20px 30px',
          background: '#ff4444',
          color: 'white',
          border: '5px solid yellow',
          borderRadius: '50px',
          fontSize: '24px',
          fontWeight: 'bold',
          cursor: 'pointer',
          boxShadow: '0 0 30px rgba(255,0,0,0.5)',
        }}
      >
        🔧 ADMIN PLANTAS AQUÍ
      </button>
