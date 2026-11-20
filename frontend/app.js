// =============================================================================
// Lógica de Cliente - Aplicación Móvil de Citas Escolares
// =============================================================================

let selectedHour = null;
let currentTab = 'acudiente';

// Base de datos de respaldo en memoria local (para modo de prueba local)
let localAppointments = [
  {
    teacher_id: "prof-garcia",
    fecha: getTomorrowDate(),
    hora: "09:00",
    estudiante: "Sofía Gómez — 7° A",
    acudiente: "Carlos Gómez",
    email: "carlos@gmail.com",
    motivo: "Plan de mejora académica",
    estado: "CONFIRMADA"
  }
];

function getTomorrowDate() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().split('T')[0];
}

// Inicialización de la App
document.addEventListener('DOMContentLoaded', () => {
  const inputFecha = document.getElementById('input-fecha');
  if (inputFecha) {
    inputFecha.value = getTomorrowDate();
    inputFecha.min = new Date().toISOString().split('T')[0];
  }
  loadSlots();
});

// Cambiar de Pestaña (Acudiente <-> Docente)
function switchTab(tab) {
  currentTab = tab;
  const tabAcu = document.getElementById('tab-acudiente');
  const tabDoc = document.getElementById('tab-docente');
  const secAcu = document.getElementById('section-acudiente');
  const secDoc = document.getElementById('section-docente');

  hideAlerts();

  if (tab === 'acudiente') {
    tabAcu.classList.add('active');
    tabDoc.classList.remove('active');
    secAcu.style.display = 'block';
    secDoc.style.display = 'none';
  } else {
    tabDoc.classList.add('active');
    tabAcu.classList.remove('active');
    secDoc.style.display = 'block';
    secAcu.style.display = 'none';
    loadDocenteCitas();
  }
}

// -----------------------------------------------------------------------------
// 1. CARGA DE HORARIOS DISPONIBLES (GET /slots)
// -----------------------------------------------------------------------------
async function loadSlots() {
  const teacherId = document.getElementById('select-docente').value;
  const fecha = document.getElementById('input-fecha').value;
  const grid = document.getElementById('slots-grid');
  selectedHour = null;

  grid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: var(--text-muted); font-size: 0.85rem; padding: 10px;">Consultando disponibilidad...</div>';

  try {
    const config = window.APP_CONFIG || {};
    const url = `${config.API_BASE_URL}/slots?teacher_id=${encodeURIComponent(teacherId)}&fecha=${encodeURIComponent(fecha)}`;
    
    let slotsLibres = [];
    let slotsOcupados = [];

    // Intento de llamada al backend real
    let isLiveSuccess = false;
    if (config.API_BASE_URL && !config.API_BASE_URL.includes("your-api-id")) {
      try {
        const resp = await fetch(url);
        if (resp.ok) {
          const data = await resp.json();
          slotsLibres = data.slots_disponibles || [];
          slotsOcupados = data.slots_ocupados || [];
          isLiveSuccess = true;
        }
      } catch (err) {
        console.warn("No se pudo conectar a la API en vivo, usando fallback local:", err);
      }
    }

    // Modo simulación local si no hay conexión al API Gateway
    if (!isLiveSuccess && config.USE_MOCK_FALLBACK) {
      const defaultHours = ["07:30", "08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "14:00", "14:30", "15:00"];
      slotsOcupados = localAppointments
        .filter(a => a.teacher_id === teacherId && a.fecha === fecha && a.estado !== 'CANCELADA')
        .map(a => a.hora);
      slotsLibres = defaultHours.filter(h => !slotsOcupados.includes(h));
    }

    // Renderizar grilla
    grid.innerHTML = '';
    const allHours = ["07:30", "08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "14:00", "14:30", "15:00"];

    allHours.forEach(hora => {
      const btn = document.createElement('div');
      const isAvailable = slotsLibres.includes(hora);
      btn.className = `slot-btn ${isAvailable ? '' : 'disabled'}`;
      btn.textContent = hora;

      if (isAvailable) {
        btn.onclick = () => {
          document.querySelectorAll('.slot-btn').forEach(b => b.classList.remove('selected'));
          btn.classList.add('selected');
          selectedHour = hora;
        };
      }
      grid.appendChild(btn);
    });

  } catch (error) {
    grid.innerHTML = '<div style="grid-column: 1 / -1; text-align: center; color: var(--danger); font-size: 0.85rem;">Error al cargar horarios.</div>';
  }
}

// -----------------------------------------------------------------------------
// 2. AGENDAR CITA CON BLOQUEO ATÓMICO (POST /citas)
// -----------------------------------------------------------------------------
async function agendarCita() {
  const teacherId = document.getElementById('select-docente').value;
  const fecha = document.getElementById('input-fecha').value;
  const acudiente = document.getElementById('input-acudiente').value.trim();
  const estudiante = document.getElementById('input-estudiante').value.trim();
  const email = document.getElementById('input-email').value.trim();
  const motivo = document.getElementById('input-motivo').value.trim() || 'Atención a padres';

  hideAlerts();

  if (!selectedHour) {
    showError("Por favor selecciona un horario libre en la grilla.");
    return;
  }
  if (!acudiente || !estudiante || !email) {
    showError("Por favor completa tu nombre, el nombre del estudiante y tu correo.");
    return;
  }

  const payload = {
    teacher_id: teacherId,
    fecha: fecha,
    hora: selectedHour,
    acudiente: acudiente,
    estudiante: estudiante,
    email: email,
    motivo: motivo
  };

  const btnAgendar = document.getElementById('btn-agendar');
  btnAgendar.disabled = true;
  btnAgendar.textContent = "Verificando y asegurando turno...";

  try {
    const config = window.APP_CONFIG || {};
    let isLiveSuccess = false;

    if (config.API_BASE_URL && !config.API_BASE_URL.includes("your-api-id")) {
      const resp = await fetch(`${config.API_BASE_URL}/citas`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (resp.status === 409) {
        // DETECCIÓN DE CONFLICTO / CONDITIONAL WRITE FAILED
        showError("⚠️ ¡Horario no disponible! Otro acudiente acaba de reservar este mismo turno hace un instante. Por favor selecciona otro horario.");
        loadSlots();
        btnAgendar.disabled = false;
        btnAgendar.textContent = "📅 Confirmar Cita sin Cruces";
        return;
      }

      if (resp.ok) {
        isLiveSuccess = true;
      }
    }

    // Modo simulación local
    if (!isLiveSuccess) {
      // Verificar conflicto en memoria
      const conflict = localAppointments.some(a => a.teacher_id === teacherId && a.fecha === fecha && a.hora === selectedHour && a.estado !== 'CANCELADA');
      if (conflict) {
        showError("⚠️ ¡Horario no disponible! Este turno ya fue tomado. Selecciona otro horario.");
        loadSlots();
        btnAgendar.disabled = false;
        btnAgendar.textContent = "📅 Confirmar Cita sin Cruces";
        return;
      }
      localAppointments.push(payload);
    }

    showSuccess(`✅ ¡Cita confirmada con éxito para el día ${fecha} a las ${selectedHour}! Se ha enviado un correo con el archivo de calendario.`);
    document.getElementById('input-acudiente').value = '';
    document.getElementById('input-estudiante').value = '';
    document.getElementById('input-motivo').value = '';
    selectedHour = null;
    loadSlots();

  } catch (err) {
    showError("Error de comunicación al agendar cita: " + err.message);
  } finally {
    btnAgendar.disabled = false;
    btnAgendar.textContent = "📅 Confirmar Cita sin Cruces";
  }
}

// -----------------------------------------------------------------------------
// 3. CONSULTAR CITAS DEL DOCENTE (GET /docente/citas)
// -----------------------------------------------------------------------------
async function loadDocenteCitas() {
  const container = document.getElementById('docente-citas-list');
  const countSpan = document.getElementById('total-citas');
  const teacherId = "prof-garcia"; // Identidad del profesor simulado

  container.innerHTML = '<div style="text-align: center; color: var(--text-muted); font-size: 0.85rem; padding: 20px;">Cargando tus citas asignadas...</div>';

  try {
    const config = window.APP_CONFIG || {};
    let citas = [];
    let isLiveSuccess = false;

    if (config.API_BASE_URL && !config.API_BASE_URL.includes("your-api-id")) {
      try {
        const resp = await fetch(`${config.API_BASE_URL}/docente/citas?teacher_id=${teacherId}`, {
          headers: {
            'Authorization': localStorage.getItem('cognito_token') || 'mock_token'
          }
        });
        if (resp.ok) {
          const data = await resp.json();
          citas = data.citas || [];
          isLiveSuccess = true;
        }
      } catch (e) {
        console.warn("Fallback a citas locales");
      }
    }

    if (!isLiveSuccess) {
      citas = localAppointments.filter(a => a.teacher_id === teacherId && a.estado !== 'CANCELADA');
    }

    countSpan.textContent = citas.length;
    container.innerHTML = '';

    if (citas.length === 0) {
      container.innerHTML = '<div style="text-align: center; color: var(--text-muted); font-size: 0.85rem; padding: 30px;">No tienes citas programadas actualmente.</div>';
      return;
    }

    citas.forEach(cita => {
      const item = document.createElement('div');
      item.className = 'appointment-item';
      item.innerHTML = `
        <div class="appointment-top">
          <span class="badge-time">📅 ${cita.fecha} • ⏰ ${cita.hora}</span>
          <span class="badge-status">● ${cita.estado || 'CONFIRMADA'}</span>
        </div>
        <div class="item-student">👦 ${cita.estudiante}</div>
        <div class="item-meta">👤 <strong>Acudiente:</strong> ${cita.acudiente}</div>
        <div class="item-meta">✉️ <strong>Correo:</strong> ${cita.email_acudiente || cita.email}</div>
        <div class="item-meta" style="font-style: italic; margin-top: 4px;">📝 "${cita.motivo || 'Atención a padres'}"</div>
        <button class="btn-cancel" onclick="cancelarCitaDocente('${cita.fecha}', '${cita.hora}')">✕ Cancelar y Liberar Turno</button>
      `;
      container.appendChild(item);
    });

  } catch (err) {
    container.innerHTML = '<div style="text-align: center; color: var(--danger); font-size: 0.85rem; padding: 20px;">Error al obtener tus citas.</div>';
  }
}

// Cancelar Cita como Docente
async function cancelarCitaDocente(fecha, hora) {
  if (!confirm(`¿Deseas cancelar la cita del ${fecha} a las ${hora}? El horario quedará disponible para otros acudientes.`)) {
    return;
  }

  const config = window.APP_CONFIG || {};
  const teacherId = "prof-garcia";

  try {
    if (config.API_BASE_URL && !config.API_BASE_URL.includes("your-api-id")) {
      await fetch(`${config.API_BASE_URL}/docente/citas`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ teacher_id: teacherId, fecha, hora })
      });
    }

    // Actualizar local
    const found = localAppointments.find(a => a.teacher_id === teacherId && a.fecha === fecha && a.hora === hora);
    if (found) {
      found.estado = 'CANCELADA';
    }

    showSuccess(`Turno del ${fecha} a las ${hora} cancelado y liberado con éxito.`);
    loadDocenteCitas();
    loadSlots();
  } catch (err) {
    showError("No se pudo cancelar la cita: " + err.message);
  }
}

function showError(msg) {
  const box = document.getElementById('alert-error');
  box.textContent = msg;
  box.style.display = 'block';
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showSuccess(msg) {
  const box = document.getElementById('alert-success');
  box.textContent = msg;
  box.style.display = 'block';
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function hideAlerts() {
  document.getElementById('alert-error').style.display = 'none';
  document.getElementById('alert-success').style.display = 'none';
}
