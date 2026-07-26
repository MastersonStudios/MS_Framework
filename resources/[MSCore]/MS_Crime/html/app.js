const loot = document.querySelector('#loot');
const itemsNode = document.querySelector('#items');
const targetName = document.querySelector('#target-name');
const targetMeta = document.querySelector('#target-meta');
const progress = document.querySelector('#search-progress');
const searchText = document.querySelector('#search-text');
const searchTarget = document.querySelector('#search-target');
const searchTimer = document.querySelector('#search-timer');
const progressBar = document.querySelector('#progress-bar');

const state = {
    payload: null,
    timer: null,
    deadline: 0
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

function closeAll() {
    clearInterval(state.timer);
    state.timer = null;
    state.payload = null;
    loot.classList.add('hidden');
    loot.setAttribute('aria-hidden', 'true');
    progress.classList.add('hidden');
    progressBar.classList.remove('running');
}

function startSearch(payload) {
    closeAll();
    const duration = Math.max(1000, Number(payload?.durationMs) || 60000);
    searchText.textContent = payload?.text || 'Du durchsuchst die Person.';
    searchTarget.textContent = payload?.targetName || '';
    state.deadline = Date.now() + duration;
    progressBar.style.setProperty('--duration', `${duration}ms`);
    progressBar.classList.remove('running');
    void progressBar.offsetWidth;
    progressBar.classList.add('running');
    progress.classList.remove('hidden');

    const updateTimer = () => {
        const seconds = Math.max(0, Math.ceil((state.deadline - Date.now()) / 1000));
        searchTimer.textContent = `${seconds} Sekunde${seconds === 1 ? '' : 'n'}`;
    };
    updateTimer();
    state.timer = setInterval(updateTimer, 250);
}

function itemCard(item) {
    const amount = Math.max(0, Number(item.amount) || 0);
    const maximum = Math.max(1, Math.min(amount, Number(state.payload?.maxAmount) || 100));
    const initial = String(item.label || item.name || '?').trim().charAt(0).toUpperCase();
    return `
        <article class="item-card">
            <div class="item-icon">${escapeHtml(initial)}</div>
            <div class="item-copy">
                <div class="item-heading">
                    <strong>${escapeHtml(item.label || item.name)}</strong>
                    <span>${amount}×</span>
                </div>
                <p>${escapeHtml(item.description || 'Keine Beschreibung')}</p>
                <div class="rob-controls">
                    <input type="number" min="1" max="${maximum}" value="1"
                           data-amount="${escapeHtml(item.name)}" ${item.tradable ? '' : 'disabled'}>
                    <button class="rob-button" data-rob="${escapeHtml(item.name)}"
                            ${item.tradable ? '' : 'disabled'}>
                        ${item.tradable ? 'Rauben' : 'Geschützt'}
                    </button>
                </div>
            </div>
        </article>
    `;
}

function bindRobButtons() {
    itemsNode.querySelectorAll('[data-rob]').forEach((button) => {
        button.addEventListener('click', () => {
            const item = button.dataset.rob;
            const input = [...itemsNode.querySelectorAll('[data-amount]')]
                .find((node) => node.dataset.amount === item);
            const amount = Math.max(1, Math.floor(Number(input?.value) || 1));
            post('robItem', { item, amount });
        });
    });
}

function renderLoot(payload) {
    state.payload = payload || {};
    clearInterval(state.timer);
    state.timer = null;
    progress.classList.add('hidden');
    targetName.textContent = state.payload.target?.name || 'Gefesselte Person';
    const seconds = Math.max(0, Math.ceil((Number(state.payload.remainingMs) || 0) / 1000));
    targetMeta.textContent = `ID ${Number(state.payload.target?.source) || 0} · ${seconds} Sekunden verbleiben`;

    const items = Array.isArray(state.payload.items) ? state.payload.items : [];
    itemsNode.innerHTML = items.length
        ? items.map(itemCard).join('')
        : '<div class="empty">Das Inventar ist leer.</div>';
    bindRobButtons();
    loot.classList.remove('hidden');
    loot.setAttribute('aria-hidden', 'false');
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'startSearch') {
        startSearch(message.payload || {});
    } else if (message.action === 'openLoot' || message.action === 'refreshLoot') {
        renderLoot(message.payload || {});
    } else if (message.action === 'close') {
        closeAll();
    }
});

document.querySelector('#close').addEventListener('click', () => post('close'));
document.querySelector('#refresh').addEventListener('click', () => post('refresh'));
document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !loot.classList.contains('hidden')) post('close');
});
