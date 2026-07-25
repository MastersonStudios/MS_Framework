const builder = document.getElementById('builder');
const storage = document.getElementById('storage');
const definitionList = document.getElementById('definition-list');
const definitionSearch = document.getElementById('definition-search');
const definitionCount = document.getElementById('definition-count');
const activeCount = document.getElementById('active-count');
const listTitle = document.getElementById('list-title');
const prompt = document.getElementById('interaction-prompt');
const promptKey = document.getElementById('prompt-key');
const promptLabel = document.getElementById('prompt-label');
const promptDetail = document.getElementById('prompt-detail');
const captureHint = document.getElementById('capture-hint');
const toast = document.getElementById('toast');
const storageItems = document.getElementById('storage-items');

const state = {
    tab: 'npc',
    definitions: { npcs: [], storages: [], doors: [] },
    models: [],
    scenarios: [],
    limits: {},
    positions: { npc: null, storage: null },
    door: null,
    storage: null,
    pendingDelete: null
};

let toastTimer;
let deleteTimer;

const post = async (endpoint, body = {}) => {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    });
    return response.json();
};

const showToast = (message, success = true) => {
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.className = `toast ${success ? 'success' : 'error'}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 4000);
};

const fmt = value => Number(value).toFixed(2);
const positionText = position => `X ${fmt(position.x)}  ·  Y ${fmt(position.y)}  ·  Z ${fmt(position.z)}  ·  H ${fmt(position.heading)}`;

const setPosition = (kind, position) => {
    state.positions[kind] = position;
    const box = document.getElementById(`${kind}-position`);
    box.textContent = positionText(position);
    box.classList.add('ready');
};

const setDoor = door => {
    state.door = door;
    const box = document.getElementById('door-position');
    box.textContent = `MODEL ${door.modelHash}  ·  ${positionText(door)}`;
    box.classList.add('ready');
};

const currentRows = () => state.tab === 'npc'
    ? state.definitions.npcs
    : state.tab === 'storage'
        ? state.definitions.storages
        : state.definitions.doors;

const rowDescription = row => {
    if (state.tab === 'npc') return `${row.model}${row.scenario ? ` · ${row.scenario}` : ''}`;
    if (state.tab === 'storage') {
        return `${row.type === 'private' ? 'Privat pro Charakter' : 'Global geteilt'} · Kapazität ${row.capacity}${row.accessJob ? ` · Job ${row.accessJob}` : ''}`;
    }
    return `${row.locked ? 'Abgeschlossen' : 'Aufgeschlossen'} · Modell ${row.modelHash}${row.accessJob ? ` · Job ${row.accessJob}` : ''}`;
};

const renderList = () => {
    const query = definitionSearch.value.trim().toLowerCase();
    const rows = currentRows().filter(row =>
        String(row.id).includes(query) || String(row.label).toLowerCase().includes(query)
    );
    const titles = { npc: 'NPCs', storage: 'Storages', door: 'Türen' };
    listTitle.textContent = titles[state.tab];
    activeCount.textContent = String(currentRows().length);
    definitionCount.textContent = `${state.definitions.npcs.length + state.definitions.storages.length + state.definitions.doors.length} Einträge`;
    definitionList.replaceChildren();

    if (!rows.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-list';
        empty.textContent = 'Noch keine passenden Einträge vorhanden.';
        definitionList.append(empty);
        return;
    }

    rows.forEach(row => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const header = document.createElement('header');
        const name = document.createElement('strong');
        const id = document.createElement('span');
        name.textContent = row.label;
        id.className = 'id';
        id.textContent = `#${row.id}`;
        header.append(name, id);

        const description = document.createElement('p');
        description.textContent = rowDescription(row);
        const actions = document.createElement('div');
        actions.className = 'card-actions';

        if (state.tab === 'door') {
            const toggle = document.createElement('button');
            toggle.type = 'button';
            toggle.className = 'button secondary';
            toggle.dataset.toggleDoor = String(row.id);
            toggle.textContent = row.locked ? 'Aufschließen' : 'Abschließen';
            actions.append(toggle);
        }

        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = `button danger${state.pendingDelete === row.id ? ' armed' : ''}`;
        remove.dataset.deleteId = String(row.id);
        remove.textContent = state.pendingDelete === row.id ? 'Löschen bestätigen' : 'Löschen';
        actions.append(remove);
        card.append(header, description, actions);
        definitionList.append(card);
    });
};

const applyBuilderData = envelope => {
    state.definitions = envelope.definitions || { npcs: [], storages: [], doors: [] };
    state.models = envelope.models || state.models;
    state.scenarios = envelope.scenarios || state.scenarios;
    state.limits = envelope.limits || state.limits;

    const modelList = document.getElementById('npc-models');
    const scenarioList = document.getElementById('npc-scenarios');
    modelList.replaceChildren();
    scenarioList.replaceChildren();
    state.models.forEach(model => {
        const option = document.createElement('option');
        option.value = model.model;
        option.label = model.label;
        modelList.append(option);
    });
    state.scenarios.forEach(scenario => {
        if (!scenario.scenario) return;
        const option = document.createElement('option');
        option.value = scenario.scenario;
        option.label = scenario.label;
        scenarioList.append(option);
    });
    document.getElementById('storage-capacity').max = String(state.limits.storageCapacity || 1000);
    renderList();
};

const switchTab = tab => {
    state.tab = tab;
    state.pendingDelete = null;
    document.querySelectorAll('.tab').forEach(button => button.classList.toggle('active', button.dataset.tab === tab));
    document.querySelectorAll('.tab-panel').forEach(panel => panel.classList.toggle('hidden', panel.dataset.panel !== tab));
    renderList();
};

document.querySelectorAll('.tab').forEach(button => {
    button.addEventListener('click', () => switchTab(button.dataset.tab));
});
definitionSearch.addEventListener('input', renderList);

document.querySelectorAll('.capture-position').forEach(button => {
    button.addEventListener('click', async () => {
        try {
            const response = await post('capturePosition', { kind: button.dataset.kind });
            if (!response.ok) return showToast(response.error || 'Position konnte nicht übernommen werden.', false);
            setPosition(button.dataset.kind, response.coords);
        } catch {
            showToast('Position konnte nicht übernommen werden.', false);
        }
    });
});

document.getElementById('capture-door').addEventListener('click', async () => {
    try {
        const response = await post('captureDoor');
        if (!response.ok) return showToast(response.error || 'Tür konnte nicht erfasst werden.', false);
        setDoor(response.door);
    } catch {
        showToast('Tür konnte nicht erfasst werden.', false);
    }
});

document.getElementById('npc-form').addEventListener('submit', event => {
    event.preventDefault();
    const position = state.positions.npc;
    if (!position) return showToast('Übernimm zuerst eine Position.', false);
    post('createDefinition', {
        kind: 'npc',
        data: {
            label: document.getElementById('npc-label').value,
            model: document.getElementById('npc-model').value,
            scenario: document.getElementById('npc-scenario').value,
            ...position
        }
    });
});

document.getElementById('storage-form').addEventListener('submit', event => {
    event.preventDefault();
    const position = state.positions.storage;
    if (!position) return showToast('Übernimm zuerst eine Position.', false);
    post('createDefinition', {
        kind: 'storage',
        data: {
            label: document.getElementById('storage-label').value,
            type: document.getElementById('storage-type').value,
            capacity: Number(document.getElementById('storage-capacity').value),
            accessJob: document.getElementById('storage-job').value,
            radius: Number(document.getElementById('storage-radius').value),
            ...position
        }
    });
});

document.getElementById('door-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!state.door) return showToast('Erfasse zuerst eine Tür.', false);
    post('createDefinition', {
        kind: 'door',
        data: {
            label: document.getElementById('door-label').value,
            accessJob: document.getElementById('door-job').value,
            radius: Number(document.getElementById('door-radius').value),
            locked: document.getElementById('door-locked').checked,
            ...state.door
        }
    });
});

definitionList.addEventListener('click', event => {
    const toggle = event.target.closest('[data-toggle-door]');
    if (toggle) return post('toggleDoor', { id: Number(toggle.dataset.toggleDoor) });

    const remove = event.target.closest('[data-delete-id]');
    if (!remove) return;
    const id = Number(remove.dataset.deleteId);
    if (state.pendingDelete !== id) {
        state.pendingDelete = id;
        clearTimeout(deleteTimer);
        deleteTimer = setTimeout(() => {
            state.pendingDelete = null;
            renderList();
        }, 4000);
        return renderList();
    }
    state.pendingDelete = null;
    post('deleteDefinition', { kind: state.tab, id });
});

const closeBuilder = async () => {
    builder.classList.add('hidden');
    try { await post('closeBuilder'); } catch {}
};
const closeStorage = async () => {
    storage.classList.add('hidden');
    try { await post('closeStorage'); } catch {}
};
document.getElementById('close-builder').addEventListener('click', closeBuilder);
document.getElementById('close-storage').addEventListener('click', closeStorage);

const renderStorage = data => {
    state.storage = data;
    document.getElementById('storage-title').textContent = data.label;
    document.getElementById('storage-type-label').textContent = data.type === 'private' ? 'PRIVATES CHARAKTERLAGER' : 'GLOBALES GEMEINSCHAFTSLAGER';
    document.getElementById('storage-capacity-label').textContent = `${data.used} von ${data.capacity} Plätzen belegt`;
    document.getElementById('capacity-bar').style.width = `${Math.min((data.used / data.capacity) * 100, 100)}%`;
    storageItems.replaceChildren();

    data.items.forEach(item => {
        const row = document.createElement('article');
        row.className = 'storage-row';
        const initial = (item.label[0] || '?').toUpperCase();

        const playerSide = document.createElement('div');
        playerSide.className = 'item-side';
        const playerIcon = document.createElement('span');
        const playerText = document.createElement('span');
        const playerName = document.createElement('strong');
        const playerAmount = document.createElement('small');
        playerIcon.className = 'item-icon';
        playerIcon.textContent = initial;
        playerName.textContent = item.label;
        playerAmount.textContent = `${item.playerAmount} im Inventar`;
        playerText.append(playerName, playerAmount);
        playerSide.append(playerIcon, playerText);

        const controls = document.createElement('div');
        controls.className = 'transfer-controls';
        const amount = document.createElement('input');
        amount.type = 'number';
        amount.min = '1';
        amount.max = String(state.limits.transfer || 100);
        amount.value = '1';
        const deposit = document.createElement('button');
        deposit.type = 'button';
        deposit.className = 'button secondary';
        deposit.textContent = '→';
        deposit.title = 'Einlagern';
        deposit.addEventListener('click', () => post('storageTransfer', {
            storageId: data.id, direction: 'deposit', item: item.name, amount: Number(amount.value)
        }));
        const withdraw = document.createElement('button');
        withdraw.type = 'button';
        withdraw.className = 'button secondary';
        withdraw.textContent = '←';
        withdraw.title = 'Entnehmen';
        withdraw.addEventListener('click', () => post('storageTransfer', {
            storageId: data.id, direction: 'withdraw', item: item.name, amount: Number(amount.value)
        }));
        controls.append(amount, deposit, withdraw);

        const storageSide = document.createElement('div');
        storageSide.className = 'item-side right';
        const storageText = document.createElement('span');
        const storageAmount = document.createElement('strong');
        const storageCaption = document.createElement('small');
        const storageIcon = document.createElement('span');
        storageAmount.textContent = String(item.storageAmount);
        storageCaption.textContent = 'im Storage';
        storageIcon.className = 'item-icon';
        storageIcon.textContent = initial;
        storageText.append(storageAmount, storageCaption);
        storageSide.append(storageText, storageIcon);
        row.append(playerSide, controls, storageSide);
        storageItems.append(row);
    });
};

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;
    if (data.action === 'openBuilder') {
        storage.classList.add('hidden');
        builder.classList.remove('hidden');
        applyBuilderData(data.data);
    } else if (data.action === 'builderData') {
        applyBuilderData(data.data);
    } else if (data.action === 'openStorage') {
        builder.classList.add('hidden');
        storage.classList.remove('hidden');
        renderStorage(data.data);
    } else if (data.action === 'result') {
        showToast(data.message, data.success);
    } else if (data.action === 'prompt') {
        prompt.classList.toggle('hidden', !data.visible);
        if (data.visible) {
            promptKey.textContent = data.key || 'E';
            promptLabel.textContent = data.label || '';
            promptDetail.textContent = data.detail || '';
        }
    } else if (data.action === 'captureHint') {
        captureHint.classList.toggle('hidden', !data.visible);
        builder.classList.toggle('hidden', data.visible);
    } else if (data.action === 'closeAll') {
        builder.classList.add('hidden');
        storage.classList.add('hidden');
    }
});

document.addEventListener('keydown', event => {
    if (event.key !== 'Escape' && event.key !== 'F9') return;
    if (!builder.classList.contains('hidden')) closeBuilder();
    else if (!storage.classList.contains('hidden')) closeStorage();
});

const previewParams = new URLSearchParams(window.location.search);
const previewMode = previewParams.get('preview');
if (previewMode === 'builder') {
    builder.classList.remove('hidden');
    applyBuilderData({
        definitions: {
            npcs: [
                { id: 1, label: 'Bahnhofsvorsteher', model: 'u_m_m_rhdtrainstationworker_01', scenario: 'GENERIC_STANDING_SCENARIO' },
                { id: 2, label: 'Gemischtwarenhändler', model: 'u_m_m_valgenstoreowner_01', scenario: '' }
            ],
            storages: [
                { id: 1, label: 'Sheriff-Waffenkammer', type: 'global', capacity: 250, accessJob: 'sheriff' },
                { id: 2, label: 'Persönliche Truhe', type: 'private', capacity: 60 }
            ],
            doors: [
                { id: 1, label: 'Sheriff-Haupteingang', modelHash: 1245831483, locked: true, accessJob: 'sheriff' }
            ]
        },
        models: [
            { model: 'u_m_m_valgenstoreowner_01', label: 'Händler – Valentine' },
            { model: 'u_m_m_rhdtrainstationworker_01', label: 'Bahnhofsarbeiter – Rhodes' }
        ],
        scenarios: [
            { scenario: 'GENERIC_STANDING_SCENARIO', label: 'Neutrales Stehen' },
            { scenario: 'WORLD_HUMAN_SMOKING', label: 'Rauchen' }
        ],
        limits: { storageCapacity: 1000, transfer: 100 }
    });
    const requestedTab = previewParams.get('tab');
    if (['npc', 'storage', 'door'].includes(requestedTab)) switchTab(requestedTab);
} else if (previewMode === 'storage') {
    storage.classList.remove('hidden');
    state.limits = { transfer: 100 };
    renderStorage({
        id: 1,
        label: 'Sheriff-Waffenkammer',
        type: 'global',
        capacity: 250,
        used: 78,
        items: [
            { name: 'bandage', label: 'Verband', description: 'Wundversorgung', playerAmount: 4, storageAmount: 32 },
            { name: 'bread', label: 'Brot', description: 'Reiseproviant', playerAmount: 2, storageAmount: 18 },
            { name: 'lockpick', label: 'Dietrich', description: 'Werkzeug', playerAmount: 1, storageAmount: 7 },
            { name: 'water', label: 'Wasserflasche', description: 'Trinkwasser', playerAmount: 6, storageAmount: 21 }
        ]
    });
}
