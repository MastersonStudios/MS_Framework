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
const patientContext = document.querySelector('#patient-context');
const contextPatientName = document.querySelector('#context-patient-name');
const contextExamineButton = document.querySelector('#context-examine');
const examinationModal = document.querySelector('#examination-modal');
const examinationPatientName = document.querySelector('#examination-patient-name');
const examinationContent = document.querySelector('#examination-content');
const examinationCloseButton = document.querySelector('#examination-close');
const examinationTreatmentButton = document.querySelector('#examination-treatment');
const unconsciousScreen = document.querySelector('#unconscious-screen');
const unconsciousTimerNode = document.querySelector('#unconscious-timer');
const emergencyButton = document.querySelector('#emergency-button');
const emergencyStatus = document.querySelector('#emergency-status');

const state = {
    mode: null,
    payload: null,
    selectedSource: null,
    examination: null,
    progressTimer: null,
    unconsciousTimer: null,
    unconsciousDeadline: 0,
    emergencyCalled: false
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

function closePatientContext() {
    patientContext.classList.add('hidden');
}

function closeExaminationWindow() {
    examinationModal.classList.add('hidden');
    examinationModal.setAttribute('aria-hidden', 'true');
}

function closeShell() {
    closePatientContext();
    closeExaminationWindow();
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    state.mode = null;
    state.payload = null;
    state.selectedSource = null;
    state.examination = null;
}

function formatCountdown(seconds) {
    const remaining = Math.max(0, Math.ceil(Number(seconds) || 0));
    const minutes = Math.floor(remaining / 60);
    return `${String(minutes).padStart(2, '0')}:${String(remaining % 60).padStart(2, '0')}`;
}

function updateUnconsciousTimer() {
    const remaining = Math.max(0, (state.unconsciousDeadline - Date.now()) / 1000);
    unconsciousTimerNode.textContent = formatCountdown(remaining);
    if (remaining <= 0) {
        emergencyStatus.textContent = 'Du wirst jetzt in die nächste Stadt gebracht …';
        clearInterval(state.unconsciousTimer);
        state.unconsciousTimer = null;
    }
}

function renderEmergencyState() {
    emergencyButton.disabled = state.emergencyCalled;
    emergencyButton.classList.toggle('sent', state.emergencyCalled);
    emergencyButton.querySelector('strong').textContent = state.emergencyCalled
        ? 'Notruf gesendet'
        : 'Notruf senden';
    emergencyButton.querySelector('small').textContent = state.emergencyCalled
        ? 'Alle diensthabenden Medics wurden alarmiert'
        : 'Diensthabende Medics alarmieren';
    emergencyStatus.textContent = state.emergencyCalled
        ? 'Medics alarmiert · Standortmarkierung mit 15 Meter Radius aktiv'
        : 'Der Notruf setzt die Wartezeit auf 20 Minuten und markiert deinen Standort.';
}

function applyUnconsciousPayload(payload = {}) {
    const remainingSeconds = Math.max(0, Number(payload.remainingSeconds) || 0);
    state.unconsciousDeadline = Date.now() + (remainingSeconds * 1000);
    state.emergencyCalled = payload.emergencyCalled === true;
    clearInterval(state.unconsciousTimer);
    renderEmergencyState();
    updateUnconsciousTimer();
    if (remainingSeconds > 0) {
        state.unconsciousTimer = setInterval(updateUnconsciousTimer, 250);
    }
}

function openUnconsciousScreen(payload) {
    closeShell();
    clearTimeout(state.progressTimer);
    progressNode.classList.add('hidden');
    unconsciousScreen.classList.remove('hidden');
    unconsciousScreen.setAttribute('aria-hidden', 'false');
    applyUnconsciousPayload(payload);
}

function closeUnconsciousScreen() {
    clearInterval(state.unconsciousTimer);
    state.unconsciousTimer = null;
    state.unconsciousDeadline = 0;
    state.emergencyCalled = false;
    unconsciousScreen.classList.add('hidden');
    unconsciousScreen.setAttribute('aria-hidden', 'true');
}

function openPatientContext(patient, anchorRect) {
    contextPatientName.textContent = patient?.name || 'Patient';
    patientContext.classList.remove('hidden');

    const width = patientContext.offsetWidth || 290;
    const height = patientContext.offsetHeight || 150;
    const preferredLeft = anchorRect.right + 10;
    const left = preferredLeft + width <= window.innerWidth - 12
        ? preferredLeft
        : Math.max(12, anchorRect.left - width - 10);
    const top = Math.min(
        Math.max(12, anchorRect.top),
        Math.max(12, window.innerHeight - height - 12)
    );
    patientContext.style.left = `${left}px`;
    patientContext.style.top = `${top}px`;
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
            const patient = patients.find((entry) =>
                Number(entry.source) === Number(button.dataset.patient)
            );
            const anchorRect = button.getBoundingClientRect();
            state.selectedSource = Number(button.dataset.patient);
            state.examination = null;
            renderPatients();
            renderDetails();
            openPatientContext(patient, anchorRect);
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

function renderExaminationWindow(patient) {
    const diseases = Array.isArray(patient?.diseases) ? patient.diseases : [];
    examinationPatientName.textContent = `${patient?.name || 'Patient'} · ID ${Number(patient?.source) || 0}`;
    examinationContent.innerHTML = `
        <div class="examination-vitals">
            <span>Gesundheit</span>
            <strong class="${patient?.dead ? 'dead-text' : ''}">
                ${patient?.dead ? 'VERSTORBEN' : `${Number(patient?.health) || 0} / 200`}
            </strong>
        </div>
        <div class="block-title">Festgestellte Symptome</div>
        ${diseases.length
            ? `<div class="examination-diseases">${diseases.map((disease) => {
                const symptoms = Array.isArray(disease.symptoms) ? disease.symptoms : [];
                return `
                    <article class="examination-disease">
                        <div>
                            <span class="severity">Schweregrad ${Number(disease.severity)}/${Number(disease.maxSeverity)}</span>
                            <h3>${escapeHtml(disease.label)}</h3>
                        </div>
                        <div class="symptom-list">
                            ${symptoms.length
                                ? symptoms.map((symptom) => `<span>${escapeHtml(symptom)}</span>`).join('')
                                : '<span>Keine sichtbaren Symptome</span>'}
                        </div>
                    </article>
                `;
            }).join('')}</div>`
            : '<div class="healthy">Keine Krankheit oder Verletzung festgestellt.</div>'}
    `;
    examinationModal.classList.remove('hidden');
    examinationModal.setAttribute('aria-hidden', 'false');
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
        closePatientContext();
        renderPatients();
        renderDetails();
        if (state.examination) renderExaminationWindow(state.examination);
    } else if (message.action === 'treatmentProgress') {
        showProgress(message.payload);
    } else if (message.action === 'treatmentFinished') {
        finishProgress(message.payload);
    } else if (message.action === 'unconsciousOpen') {
        openUnconsciousScreen(message.payload || {});
    } else if (message.action === 'unconsciousUpdate') {
        if (unconsciousScreen.classList.contains('hidden')) {
            openUnconsciousScreen(message.payload || {});
        } else {
            applyUnconsciousPayload(message.payload || {});
        }
    } else if (message.action === 'unconsciousClose') {
        closeUnconsciousScreen();
    } else if (message.action === 'reset') {
        closeShell();
        closeUnconsciousScreen();
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
contextExamineButton.addEventListener('click', () => {
    closePatientContext();
    if (state.selectedSource) post('examine', { target: state.selectedSource });
});
examinationCloseButton.addEventListener('click', closeExaminationWindow);
examinationTreatmentButton.addEventListener('click', closeExaminationWindow);
emergencyButton.addEventListener('click', async () => {
    if (state.emergencyCalled || emergencyButton.disabled) return;
    emergencyButton.disabled = true;
    emergencyButton.classList.add('pending');
    emergencyButton.querySelector('strong').textContent = 'Notruf wird gesendet …';
    const result = await post('emergency');
    emergencyButton.classList.remove('pending');
    if (!result?.ok) {
        emergencyButton.disabled = false;
        emergencyButton.querySelector('strong').textContent = 'Notruf senden';
        emergencyStatus.textContent = 'Der Notruf konnte nicht gesendet werden. Bitte versuche es erneut.';
    }
});
examinationModal.addEventListener('click', (event) => {
    if (event.target === examinationModal) closeExaminationWindow();
});
document.addEventListener('pointerdown', (event) => {
    if (patientContext.classList.contains('hidden')) return;
    if (patientContext.contains(event.target) || event.target.closest('[data-patient]')) return;
    closePatientContext();
});
document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape' || app.classList.contains('hidden')) return;
    if (!examinationModal.classList.contains('hidden')) {
        closeExaminationWindow();
    } else if (!patientContext.classList.contains('hidden')) {
        closePatientContext();
    } else {
        post('close');
    }
});
