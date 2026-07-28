const menu = document.querySelector('#boss-menu');
const prompt = document.querySelector('#prompt');
const candidateList = document.querySelector('#candidate-list');
const employeeList = document.querySelector('#employee-list');
const companyAmount = document.querySelector('#company-amount');
const depositButton = document.querySelector('#company-deposit');
const withdrawButton = document.querySelector('#company-withdraw');
const dutyButton = document.querySelector('#duty-toggle');
const dutyCard = document.querySelector('#duty-card');
const confirmModal = document.querySelector('#confirm');
const toast = document.querySelector('#toast');

const state = {
    data: null,
    activeTab: 'duty',
    busy: false,
    busyTimer: null,
    pendingFire: null,
    toastTimer: null,
    dutyRenderedAt: Date.now()
};

function post(endpoint, body = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
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

function money(value) {
    return `$${Math.max(0, Math.floor(Number(value) || 0)).toLocaleString('de-DE')}`;
}

function showToast(message, success = true) {
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.className = `toast ${success ? 'success' : 'error'}`;
    clearTimeout(state.toastTimer);
    state.toastTimer = setTimeout(() => toast.classList.add('hidden'), 4200);
}

function setBusy(busy) {
    state.busy = busy === true;
    clearTimeout(state.busyTimer);
    document.querySelectorAll(
        '[data-hire], [data-fire], #company-deposit, #company-withdraw, #duty-toggle'
    )
        .forEach((button) => {
            button.disabled = state.busy || button.dataset.allowed === 'false';
        });
    if (state.busy) {
        state.busyTimer = setTimeout(() => setBusy(false), 5000);
    }
}

function switchTab(tabName) {
    if (!['duty', 'hire', 'fire', 'company'].includes(tabName)) return;
    if (tabName !== 'duty' && state.data?.permissions?.manage !== true) return;
    state.activeTab = tabName;
    document.querySelectorAll('[data-tab]').forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tabName);
    });
    document.querySelectorAll('[data-panel]').forEach((panel) => {
        panel.classList.toggle('active', panel.dataset.panel === tabName);
    });
}

function formatDuration(rawSeconds) {
    const seconds = Math.max(0, Math.floor(Number(rawSeconds) || 0));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds % 3600 / 60);
    const remainder = seconds % 60;
    return [hours, minutes, remainder]
        .map((value) => String(value).padStart(2, '0'))
        .join(':');
}

function liveWorkedSeconds() {
    const duty = state.data?.duty;
    if (!duty) return 0;
    const base = Math.max(0, Math.floor(Number(duty.workedSeconds) || 0));
    if (duty.onDuty !== true) return base;
    return base + Math.max(0, Math.floor((Date.now() - state.dutyRenderedAt) / 1000));
}

function updateDutyClock() {
    const duty = state.data?.duty;
    const available = duty && Number(duty.intervalSeconds) > 0;
    const onDuty = available && duty.onDuty === true;
    const worked = available ? liveWorkedSeconds() : 0;
    const interval = available ? Math.max(1, Number(duty.intervalSeconds)) : 1;
    const remaining = available ? Math.max(0, interval - worked) : 0;
    const progress = available ? Math.min(100, worked / interval * 100) : 0;

    dutyCard.classList.toggle('on-duty', onDuty);
    dutyCard.classList.toggle('off-duty', !onDuty);
    document.querySelector('#duty-seal').textContent = onDuty ? '✓' : 'D';
    document.querySelector('#duty-status').textContent = onDuty ? 'Im Dienst' : 'Außer Dienst';
    document.querySelector('#duty-description').textContent = available
        ? onDuty
            ? 'Deine aktive Arbeitszeit wird jetzt serverseitig erfasst.'
            : 'Die bisherige Dienstzeit bleibt erhalten, bis du den Dienst fortsetzt.'
        : 'Für diesen Job ist keine Gehaltszahlung konfiguriert.';
    document.querySelector('#duty-elapsed').textContent = formatDuration(worked);
    document.querySelector('#duty-remaining').textContent = available
        ? `${formatDuration(remaining)} bis zur nächsten Auszahlung`
        : 'Nächste Auszahlung nicht verfügbar';
    document.querySelector('#duty-progress-bar').style.width = `${progress}%`;
    document.querySelector('#duty-salary').textContent = money(duty?.salary);
    document.querySelector('#duty-account').textContent = available
        ? `${formatDuration(interval)} aktive Dienstzeit · ${duty.account === 'cash' ? 'Bargeld' : 'Bankkonto'}`
        : 'Keine Auszahlung eingerichtet';
    dutyButton.textContent = onDuty ? 'Dienst beenden' : 'In den Dienst melden';
    dutyButton.classList.toggle('primary', !onDuty);
    dutyButton.classList.toggle('danger-button', onDuty);
    dutyButton.dataset.allowed = available ? 'true' : 'false';
    dutyButton.disabled = state.busy || !available;
}

function renderDuty() {
    state.dutyRenderedAt = Date.now();
    updateDutyClock();
}

function emptyState(title, text) {
    return `
        <div class="empty-state">
            <span>MS</span>
            <h3>${escapeHtml(title)}</h3>
            <p>${escapeHtml(text)}</p>
        </div>
    `;
}

function renderCandidates() {
    const candidates = Array.isArray(state.data?.candidates) ? state.data.candidates : [];
    candidateList.innerHTML = candidates.length
        ? candidates.map((candidate) => `
            <article class="person-card">
                <div class="person-avatar">${escapeHtml(candidate.name?.charAt(0) || '?')}</div>
                <div class="person-main">
                    <strong>${escapeHtml(candidate.name)}</strong>
                    <small>ID ${Number(candidate.source) || 0} · ${Number(candidate.distance).toFixed(1)} Meter entfernt</small>
                </div>
                <span class="status-pill available">Verfügbar</span>
                <button class="button compact primary" type="button"
                        data-hire="${Number(candidate.source) || 0}" data-allowed="true">
                    Einstellen
                </button>
            </article>
        `).join('')
        : emptyState(
            'Keine Bewerber in der Nähe',
            state.data?.settings?.requireUnemployed
                ? 'Arbeitslose Spieler müssen sich in deiner Nähe befinden.'
                : 'Ein Spieler muss sich in deiner Nähe befinden.'
        );
}

function renderEmployees() {
    const employees = Array.isArray(state.data?.employees) ? state.data.employees : [];
    employeeList.innerHTML = employees.length
        ? employees.map((employee) => {
            const protectedEntry = employee.manageable !== true;
            const actionLabel = employee.isSelf
                ? 'Eigener Charakter'
                : employee.isBoss ? 'Leitung geschützt' : 'Geschützt';
            return `
                <article class="person-card">
                    <div class="person-avatar">${escapeHtml(employee.name?.charAt(0) || '?')}</div>
                    <div class="person-main">
                        <strong>${escapeHtml(employee.name)}</strong>
                        <small>Charakter ${Number(employee.characterId) || 0} · Jobgrad ${Number(employee.grade) || 0}</small>
                    </div>
                    <span class="status-pill ${employee.online ? 'online' : 'offline'}">
                        ${employee.online ? 'Online' : 'Offline'}
                    </span>
                    <button class="button compact ${protectedEntry ? 'locked' : 'danger-button'}"
                            type="button"
                            data-fire="${Number(employee.characterId) || 0}"
                            data-name="${escapeHtml(employee.name)}"
                            data-allowed="${protectedEntry ? 'false' : 'true'}"
                            ${protectedEntry ? 'disabled' : ''}>
                        ${protectedEntry ? actionLabel : 'Entlassen'}
                    </button>
                </article>
            `;
        }).join('')
        : emptyState('Keine Mitarbeiter', 'Dieser Job hat derzeit keine eingetragenen Mitarbeiter.');
}

function roundedTax(value, mode) {
    if (mode === 'floor') return Math.floor(value);
    if (mode === 'round') return Math.round(value);
    return Math.ceil(value);
}

function updateTaxHint() {
    const account = state.data?.company;
    const tax = account?.tax;
    if (!tax?.enabled) {
        document.querySelector('#tax-hint').textContent = 'Für Firmenbuchungen ist keine Steuer aktiv.';
        return;
    }
    const amount = Math.max(0, Math.floor(Number(companyAmount.value) || 0));
    const percent = Math.max(0, Number(tax.percent) || 0);
    if (!amount) {
        document.querySelector('#tax-hint').textContent =
            `Transaktionssteuer: ${percent.toLocaleString('de-DE')} % pro Firmenbuchung.`;
        return;
    }
    const charge = Math.max(
        Number(tax.minimum) || 0,
        roundedTax(amount * percent / 100, tax.rounding)
    );
    document.querySelector('#tax-hint').textContent =
        `Bei ${money(amount)} werden ${money(charge)} dem Administrationskonto gutgeschrieben.`;
}

function renderCompany() {
    const company = state.data?.company;
    const boss = state.data?.boss || {};
    document.querySelector('#company-balance').textContent = money(company?.balance);
    document.querySelector('#company-label').textContent = company?.label || 'Nicht verfügbar';
    document.querySelector('#ledger-label').textContent = company?.label || 'Firmenkonto';
    document.querySelector('#ledger-balance').textContent = money(company?.balance);
    document.querySelector('#boss-cash').textContent = money(boss.cash);

    const canDeposit = company && Number(boss.grade) >= Number(company.minDepositGrade);
    const canWithdraw = company && Number(boss.grade) >= Number(company.minWithdrawGrade);
    depositButton.dataset.allowed = canDeposit ? 'true' : 'false';
    withdrawButton.dataset.allowed = canWithdraw ? 'true' : 'false';
    depositButton.disabled = state.busy || !canDeposit;
    withdrawButton.disabled = state.busy || !canWithdraw;
    updateTaxHint();
}

function bindPeopleActions() {
    candidateList.querySelectorAll('[data-hire]').forEach((button) => {
        button.addEventListener('click', () => {
            if (state.busy) return;
            const source = Number(button.dataset.hire);
            if (!source) return;
            setBusy(true);
            post('hire', { source });
        });
    });
    employeeList.querySelectorAll('[data-fire]').forEach((button) => {
        button.addEventListener('click', () => {
            if (state.busy || button.dataset.allowed !== 'true') return;
            state.pendingFire = {
                characterId: Number(button.dataset.fire),
                name: button.dataset.name || 'Mitarbeiter'
            };
            document.querySelector('#confirm-name').textContent = state.pendingFire.name;
            confirmModal.classList.remove('hidden');
            confirmModal.setAttribute('aria-hidden', 'false');
        });
    });
}

function render() {
    const data = state.data || {};
    const canManage = data.permissions?.manage === true;
    document.querySelector('#job-label').textContent = data.job?.label || 'Dienst- & Boss-Menü';
    document.querySelector('#point-label').textContent = data.point?.label || 'Dienststelle';
    document.querySelector('#boss-name').textContent = data.boss?.name || 'Mitarbeiter';
    document.querySelector('#boss-grade').textContent = `Jobgrad ${Number(data.boss?.grade) || 0}`;
    document.querySelector('#management-summary').hidden = !canManage;
    document.querySelector('#menu-shell').classList.toggle('duty-only', !canManage);
    document.querySelector('#menu-tabs').classList.toggle('duty-only', !canManage);
    document.querySelectorAll('.management-tab').forEach((tab) => {
        tab.hidden = !canManage;
    });
    if (!canManage && state.activeTab !== 'duty') state.activeTab = 'duty';
    document.querySelector('#employee-count').textContent = String(data.employees?.length || 0);
    document.querySelector('#candidate-count').textContent = String(data.candidates?.length || 0);
    document.querySelector('#hire-distance').textContent =
        `im Umkreis von ${Number(data.settings?.hireDistance) || 5} Metern`;
    renderDuty();
    renderCandidates();
    renderEmployees();
    renderCompany();
    bindPeopleActions();
    switchTab(state.activeTab);
    setBusy(false);
}

function closeConfirm() {
    state.pendingFire = null;
    confirmModal.classList.add('hidden');
    confirmModal.setAttribute('aria-hidden', 'true');
}

function closeMenu() {
    menu.classList.add('hidden');
    menu.setAttribute('aria-hidden', 'true');
    closeConfirm();
    state.data = null;
    setBusy(false);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'prompt') {
        prompt.classList.toggle('hidden', message.visible !== true);
        document.querySelector('#prompt-key').textContent = message.key || 'E';
        document.querySelector('#prompt-label').textContent = message.label || 'Boss-Menü';
    } else if (message.action === 'open') {
        state.data = message.data || {};
        state.activeTab = 'duty';
        menu.classList.remove('hidden');
        menu.setAttribute('aria-hidden', 'false');
        render();
    } else if (message.action === 'refresh') {
        state.data = message.data || {};
        render();
    } else if (message.action === 'result') {
        setBusy(false);
        showToast(message.message, message.success === true);
    } else if (message.action === 'close') {
        closeMenu();
    }
});

document.querySelectorAll('[data-tab]').forEach((button) => {
    button.addEventListener('click', () => switchTab(button.dataset.tab));
});
document.querySelector('#close').addEventListener('click', () => post('close'));
document.querySelector('#refresh').addEventListener('click', () => {
    if (!state.busy) post('refresh');
});
document.querySelector('#confirm-cancel').addEventListener('click', closeConfirm);
document.querySelector('#confirm-fire').addEventListener('click', () => {
    if (!state.pendingFire || state.busy) return;
    const characterId = state.pendingFire.characterId;
    closeConfirm();
    setBusy(true);
    post('fire', { characterId });
});
confirmModal.addEventListener('click', (event) => {
    if (event.target === confirmModal) closeConfirm();
});
document.querySelectorAll('[data-amount]').forEach((button) => {
    button.addEventListener('click', () => {
        companyAmount.value = button.dataset.amount;
        updateTaxHint();
    });
});
companyAmount.addEventListener('input', updateTaxHint);
dutyButton.addEventListener('click', () => {
    if (state.busy || dutyButton.dataset.allowed !== 'true') return;
    const onDuty = state.data?.duty?.onDuty !== true;
    setBusy(true);
    post('toggleDuty', { onDuty });
});

function companyOperation(operation) {
    if (state.busy) return;
    const amount = Number(companyAmount.value);
    if (!Number.isInteger(amount) || amount < 1) {
        return showToast('Gib einen gültigen ganzzahligen Betrag ein.', false);
    }
    setBusy(true);
    post('companyOperation', { operation, amount });
}

depositButton.addEventListener('click', () => companyOperation('deposit'));
withdrawButton.addEventListener('click', () => companyOperation('withdraw'));
document.querySelector('#company-form').addEventListener('submit', (event) => {
    event.preventDefault();
});
document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape' || menu.classList.contains('hidden')) return;
    if (!confirmModal.classList.contains('hidden')) closeConfirm();
    else post('close');
});

setInterval(() => {
    if (!menu.classList.contains('hidden')) updateDutyClock();
}, 1000);
