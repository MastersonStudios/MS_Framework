const app = document.querySelector('#app');
const title = document.querySelector('#title');
const subtitle = document.querySelector('#subtitle');
const medicLayout = document.querySelector('#medic-layout');
const healthLayout = document.querySelector('#health-layout');
const patientsNode = document.querySelector('#patients');
const patientCount = document.querySelector('#patient-count');
const emptyState = document.querySelector('#empty-state');
const detailsNode = document.querySelector('#patient-details');
const refreshButton = document.querySelector('#refresh');
const progressNode = document.querySelector('#progress');
const progressTitle = document.querySelector('#progress-title');
const progressPatient = document.querySelector('#progress-patient');
const progressBar = document.querySelector('#progress-bar');

const state = {
    mode: null,
    payload: null,
    selectedSource: null,
    examination: null,
    progressTimer: null
};

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json()).catch(() => ({ ok: false }));
}

function escapeHtml(value) {
    return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}

function requirements(items) {
    if (!Array.isArray(items) || items.length === 0) {
        return '<span class="requirement">Keine Gegenstände</span>';
    }
    return items.map((item) =>
        `<span class="requirement">${Number(item.amount) || 1}× ${escapeHtml(item.label)}</span>`
    ).join('');
}

function openShell() {
    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
}

function closeShell() {
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    state.mode = null;
    state.payload = null;
    state.selectedSource = null;
    state.examination = null;
}

function renderPatients() {
    const patients = Array.isArray(state.payload?.patients) ? state.payload.patients : [];
    patientCount.textContent = String(patients.length);
    patientsNode.innerHTML = patients.length
        ? patients.map((patient) => `
            <button class="patient-card ${Number(patient.source) === state.selectedSource ? 'active' : ''}"
                    data-patient="${Number(patient.source)}">
                <strong>${escapeHtml(patient.name)}</strong>
                <span class="status-dot ${patient.dead ? 'dead' : ''}"></span>
                <small>ID ${Number(patient.source)} · ${patient.dead ? 'Verstorben' : `${Number(patient.health) || 0} Gesundheit`}</small>
            </button>
        `).join('')
        : '<div class="empty-state"><p>Keine Patienten in Reichweite.</p></div>';

    patientsNode.querySelectorAll('[data-patient]').forEach((button) => {
        button.addEventListener('click', () => {
            state.selectedSource = Number(button.dataset.patient);
            state.examination = null;
            renderPatients();
            renderDetails();
            post('examine', { target: state.selectedSource });
        });
    });
}

function actionCard(action, patient) {
    const isRevive = action.key === 'revive';
    const disabled = isRevive ? !patient.dead : patient.dead;
    return `
        <article class="action-card">
            <h3>${escapeHtml(action.label)}</h3>
            <p>${escapeHtml(action.description)}</p>
            <div class="requirements">${requirements(action.items)}</div>
            <button class="primary-button" data-care="${escapeHtml(action.key)}" ${disabled ? 'disabled' : ''}>
                ${escapeHtml(action.label)}
            </button>
        </article>
    `;
}

function diseaseCard(disease, patient) {
    const symptomText = Array.isArray(disease.symptoms) ? disease.symptoms.join(', ') : '';
    return `
        <article class="disease-card">
            <span class="severity">Schweregrad ${Number(disease.severity)}/${Number(disease.maxSeverity)}</span>
            <h3>${escapeHtml(disease.label)}</h3>
            <p>${escapeHtml(disease.description)}</p>
            <p><strong>Symptome:</strong> ${escapeHtml(symptomText || 'Keine Angaben')}</p>
            <div class="requirements">${requirements(disease.treatment?.items)}</div>
            <button class="primary-button" data-disease="${escapeHtml(disease.key)}" ${patient.dead ? 'disabled' : ''}>
                ${escapeHtml(disease.treatment?.label || 'Behandeln')}
            </button>
        </article>
    `;
}

function bindTreatmentButtons() {
    detailsNode.querySelectorAll('[data-care]').forEach((button) => {
        button.addEventListener('click', () => {
            post('treat', {
                target: state.selectedSource,
                actionType: 'care',
                actionKey: button.dataset.care
            });
        });
    });
    detailsNode.querySelectorAll('[data-disease]').forEach((button) => {
        button.addEventListener('click', () => {
            post('treat', {
                target: state.selectedSource,
                actionType: 'disease',
                actionKey: button.dataset.disease
            });
        });
    });
}

function renderDetails() {
    const patient = state.examination;
    if (!patient) {
        emptyState.classList.remove('hidden');
        detailsNode.classList.add('hidden');
        return;
    }

    emptyState.classList.add('hidden');
    detailsNode.classList.remove('hidden');
    const careActions = Array.isArray(state.payload?.careActions) ? state.payload.careActions : [];
    const diseases = Array.isArray(patient.diseases) ? patient.diseases : [];

    detailsNode.innerHTML = `
        <div class="patient-header">
            <div>
                <p class="eyebrow">Untersuchungsbericht · ID ${Number(patient.source)}</p>
                <h2>${escapeHtml(patient.name)}</h2>
                <p class="muted">${diseases.length} aktive Erkrankung${diseases.length === 1 ? '' : 'en'}</p>
            </div>
            <span class="vital ${patient.dead ? 'dead' : ''}">
                ${patient.dead ? 'VERSTORBEN' : `${Number(patient.health) || 0} / 200`}
            </span>
        </div>
        <section class="block">
            <div class="block-title">Grundversorgung</div>
            <div class="action-grid">${careActions.map((action) => actionCard(action, patient)).join('')}</div>
        </section>
        <section class="block">
            <div class="block-title">Diagnostizierte Krankheiten</div>
            ${diseases.length
                ? `<div class="disease-list">${diseases.map((disease) => diseaseCard(disease, patient)).join('')}</div>`
                : '<div class="healthy">Keine aktive Krankheit festgestellt.</div>'}
        </section>
    `;
    bindTreatmentButtons();
}

function renderMedic() {
    title.textContent = 'Medic-Zentrale';
    subtitle.textContent = `${state.payload?.medic?.name || 'Medic'} · Patienten untersuchen und behandeln`;
    medicLayout.classList.remove('hidden');
    healthLayout.classList.add('hidden');
    refreshButton.classList.remove('hidden');
    renderPatients();
    renderDetails();
}

function renderHealth() {
    const patient = state.payload?.patient || {};
    const diseases = Array.isArray(patient.diseases) ? patient.diseases : [];
    title.textContent = 'Gesundheitsakte';
    subtitle.textContent = patient.name || 'Eigener Gesundheitsstatus';
    medicLayout.classList.add('hidden');
    healthLayout.classList.remove('hidden');
    refreshButton.classList.add('hidden');
    healthLayout.innerHTML = `
        <div class="health-summary">
            <article class="health-card">
                <p>Aktuelle Gesundheit</p>
                <div class="health-number">${Number(patient.health) || 0}</div>
                <span class="severity">${patient.dead ? 'Verstorben' : 'von 200'}</span>
            </article>
            <section>
                <div class="block-title">Aktive Krankheiten</div>
                ${diseases.length
                    ? `<div class="disease-list">${diseases.map((disease) => `
                        <article class="disease-card">
                            <span class="severity">Schweregrad ${Number(disease.severity)}/${Number(disease.maxSeverity)}</span>
                            <h3>${escapeHtml(disease.label)}</h3>
                            <p>${escapeHtml(disease.description)}</p>
                            <p>${escapeHtml(Array.isArray(disease.symptoms) ? disease.symptoms.join(', ') : '')}</p>
                        </article>
                    `).join('')}</div>`
                    : '<div class="healthy">Keine aktive Krankheit festgestellt.</div>'}
            </section>
        </div>
    `;
}

function showProgress(payload) {
    closeShell();
    clearTimeout(state.progressTimer);
    progressTitle.textContent = payload?.label || 'Behandlung läuft';
    progressPatient.textContent = payload?.patientName || '';
    progressNode.classList.remove('hidden');
    progressBar.classList.remove('running');
    progressBar.style.setProperty('--duration', `${Math.max(500, Number(payload?.durationMs) || 5000)}ms`);
    void progressBar.offsetWidth;
    progressBar.classList.add('running');
}

function finishProgress(payload) {
    clearTimeout(state.progressTimer);
    progressTitle.textContent = payload?.success === false ? 'Behandlung fehlgeschlagen' : 'Behandlung abgeschlossen';
    progressPatient.textContent = payload?.message || '';
    progressBar.classList.remove('running');
    progressBar.style.width = '100%';
    state.progressTimer = setTimeout(() => {
        progressNode.classList.add('hidden');
        progressBar.style.width = '';
    }, 1800);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'openMedic') {
        state.mode = 'medic';
        state.payload = message.payload || {};
        state.selectedSource = null;
        state.examination = null;
        openShell();
        renderMedic();
    } else if (message.action === 'refreshMedic' && state.mode === 'medic') {
        state.payload = message.payload || {};
        const stillNearby = state.payload.patients?.some((patient) =>
            Number(patient.source) === state.selectedSource
        );
        if (!stillNearby) {
            state.selectedSource = null;
            state.examination = null;
        }
        renderMedic();
    } else if (message.action === 'openHealth') {
        state.mode = 'health';
        state.payload = message.payload || {};
        openShell();
        renderHealth();
    } else if (message.action === 'examination' && state.mode === 'medic') {
        state.examination = message.patient || null;
        state.selectedSource = Number(message.patient?.source) || null;
        renderPatients();
        renderDetails();
    } else if (message.action === 'treatmentProgress') {
        showProgress(message.payload);
    } else if (message.action === 'treatmentFinished') {
        finishProgress(message.payload);
    } else if (message.action === 'reset') {
        closeShell();
        clearTimeout(state.progressTimer);
        progressNode.classList.add('hidden');
        progressBar.classList.remove('running');
        progressBar.style.width = '';
    } else if (message.action === 'close') {
        closeShell();
    }
});

document.querySelector('#close').addEventListener('click', () => post('close'));
refreshButton.addEventListener('click', () => post('refresh'));
document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !app.classList.contains('hidden')) post('close');
});
