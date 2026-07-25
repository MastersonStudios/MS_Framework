const app = document.getElementById('app');
const playerList = document.getElementById('player-list');
const playerSearch = document.getElementById('player-search');
const playerCount = document.getElementById('player-count');
const onlineStatus = document.getElementById('online-status');
const weatherStatus = document.getElementById('weather-status');
const emptySelection = document.getElementById('empty-selection');
const playerPanel = document.getElementById('player-panel');
const selectedServerName = document.getElementById('selected-server-name');
const selectedName = document.getElementById('selected-name');
const selectedMeta = document.getElementById('selected-meta');
const selectedId = document.getElementById('selected-id');
const selectedCash = document.getElementById('selected-cash');
const selectedBank = document.getElementById('selected-bank');
const selectedHealth = document.getElementById('selected-health');
const selectedItems = document.getElementById('selected-items');
const freezeAction = document.getElementById('freeze-action');
const itemName = document.getElementById('item-name');
const itemAmount = document.getElementById('item-amount');
const moneyAccount = document.getElementById('money-account');
const moneyAmount = document.getElementById('money-amount');
const weatherList = document.getElementById('weather-list');
const weatherTransition = document.getElementById('weather-transition');
const transitionValue = document.getElementById('transition-value');
const noclipButton = document.getElementById('noclip');
const kickButton = document.getElementById('kick-button');
const toast = document.getElementById('toast');

const state = {
    players: [],
    items: [],
    weathers: [],
    selected: null,
    currentWeather: null,
    selfId: null,
    limits: {},
    noclip: false,
    kickArmed: false
};

let toastTimer;
let kickTimer;

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

const currentPlayer = () => state.players.find(player => player.source === state.selected);

const initials = name => String(name || '?')
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0] || '')
    .join('')
    .toUpperCase();

const renderPlayers = () => {
    const query = playerSearch.value.trim().toLowerCase();
    const filtered = state.players.filter(player =>
        String(player.source).includes(query)
        || String(player.characterName || '').toLowerCase().includes(query)
        || String(player.serverName || '').toLowerCase().includes(query)
    );

    playerList.replaceChildren();
    if (!filtered.length) {
        const empty = document.createElement('div');
        empty.className = 'player-row empty';
        empty.textContent = 'Keine passenden Spieler gefunden.';
        playerList.append(empty);
    }

    filtered.forEach(player => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `player-row${player.source === state.selected ? ' active' : ''}`;
        button.dataset.source = String(player.source);

        const avatar = document.createElement('span');
        avatar.className = 'avatar';
        avatar.textContent = initials(player.characterName);

        const identity = document.createElement('span');
        const name = document.createElement('strong');
        const meta = document.createElement('small');
        name.textContent = player.characterName;
        meta.textContent = `ID ${player.source} · ${player.job} ${player.jobGrade}`;
        identity.append(name, meta);

        const ping = document.createElement('span');
        ping.className = 'ping';
        ping.textContent = `${player.ping}ms`;
        button.append(avatar, identity, ping);
        playerList.append(button);
    });

    playerCount.textContent = String(state.players.length);
    onlineStatus.textContent = `${state.players.length} Spieler`;
};

const renderSelected = () => {
    const player = currentPlayer();
    if (!player) {
        state.selected = null;
        emptySelection.classList.remove('hidden');
        playerPanel.classList.add('hidden');
        return;
    }

    emptySelection.classList.add('hidden');
    playerPanel.classList.remove('hidden');
    selectedServerName.textContent = player.serverName;
    selectedName.textContent = player.characterName;
    selectedMeta.textContent = `${player.job} · Grad ${player.jobGrade} · Charakter #${player.characterId} · ${player.ping}ms`;
    selectedId.textContent = `ID ${player.source}`;
    selectedCash.textContent = `$${Number(player.cash).toLocaleString('de-DE')}`;
    selectedBank.textContent = `$${Number(player.bank).toLocaleString('de-DE')}`;
    selectedHealth.textContent = String(player.health);
    selectedItems.textContent = String(player.itemCount);
    freezeAction.lastChild.textContent = player.frozen ? ' Freigeben' : ' Einfrieren';
};

const renderItems = () => {
    const previous = itemName.value;
    itemName.replaceChildren();
    state.items.forEach(item => {
        const option = document.createElement('option');
        option.value = item.name;
        option.textContent = `${item.label} (max. ${item.maxStack})`;
        itemName.append(option);
    });
    if (state.items.some(item => item.name === previous)) itemName.value = previous;
    itemAmount.max = String(state.limits.items || 50);
    moneyAmount.max = String(state.limits.money || 100000);
};

const renderWeather = () => {
    weatherList.replaceChildren();
    state.weathers.forEach(weather => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `weather-option${weather.id === state.currentWeather ? ' active' : ''}`;
        button.dataset.weather = weather.id;

        const label = document.createElement('strong');
        const description = document.createElement('span');
        label.textContent = weather.label;
        description.textContent = weather.description;
        button.append(label, description);
        weatherList.append(button);
    });

    const active = state.weathers.find(weather => weather.id === state.currentWeather);
    weatherStatus.textContent = `Wetter: ${active ? active.label : '–'}`;
    weatherTransition.max = String(state.limits.weatherTransition || 30);
    if (Number.isFinite(Number(state.currentTransition))) {
        weatherTransition.value = String(state.currentTransition);
        transitionValue.textContent = `${weatherTransition.value}s`;
    }
};

const applyData = data => {
    const selected = state.selected;
    Object.assign(state, data || {});
    state.selected = state.players.some(player => player.source === selected)
        ? selected
        : state.players.some(player => player.source === state.selfId)
            ? state.selfId
            : state.players[0]?.source || null;
    renderPlayers();
    renderSelected();
    renderItems();
    renderWeather();
};

const execute = async (action, data = {}) => {
    try {
        await post('execute', { action, data });
    } catch {
        showToast('Die Aktion konnte nicht an die Resource gesendet werden.', false);
    }
};

const closeMenu = async () => {
    app.classList.add('hidden');
    try { await post('close'); } catch {}
};

playerList.addEventListener('click', event => {
    const row = event.target.closest('[data-source]');
    if (!row) return;
    state.selected = Number(row.dataset.source);
    state.kickArmed = false;
    kickButton.classList.remove('armed');
    kickButton.textContent = 'Spieler kicken';
    renderPlayers();
    renderSelected();
});

playerSearch.addEventListener('input', renderPlayers);

document.querySelectorAll('[data-player-action]').forEach(button => {
    button.addEventListener('click', () => {
        if (!currentPlayer()) return showToast('Wähle zuerst einen Spieler.', false);
        execute(button.dataset.playerAction, { target: state.selected });
    });
});

document.getElementById('money-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!currentPlayer()) return showToast('Wähle zuerst einen Spieler.', false);
    execute('giveMoney', {
        target: state.selected,
        account: moneyAccount.value,
        amount: Number(moneyAmount.value)
    });
});

document.getElementById('item-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!currentPlayer()) return showToast('Wähle zuerst einen Spieler.', false);
    execute('giveItem', {
        target: state.selected,
        item: itemName.value,
        amount: Number(itemAmount.value)
    });
});

document.getElementById('kick-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!currentPlayer()) return showToast('Wähle zuerst einen Spieler.', false);
    if (!state.kickArmed) {
        state.kickArmed = true;
        kickButton.classList.add('armed');
        kickButton.textContent = 'Kick bestätigen';
        clearTimeout(kickTimer);
        kickTimer = setTimeout(() => {
            state.kickArmed = false;
            kickButton.classList.remove('armed');
            kickButton.textContent = 'Spieler kicken';
        }, 4000);
        return;
    }
    state.kickArmed = false;
    kickButton.classList.remove('armed');
    kickButton.textContent = 'Spieler kicken';
    execute('kick', {
        target: state.selected,
        reason: document.getElementById('kick-reason').value
    });
});

weatherList.addEventListener('click', event => {
    const option = event.target.closest('[data-weather]');
    if (!option) return;
    execute('setWeather', {
        weather: option.dataset.weather,
        transition: Number(weatherTransition.value)
    });
});

weatherTransition.addEventListener('input', () => {
    transitionValue.textContent = `${weatherTransition.value}s`;
});

document.getElementById('coords-form').addEventListener('submit', event => {
    event.preventDefault();
    const xInput = document.getElementById('coord-x');
    const yInput = document.getElementById('coord-y');
    const zInput = document.getElementById('coord-z');
    if (!xInput.value || !yInput.value || !zInput.value) {
        return showToast('Trage X-, Y- und Z-Koordinaten ein.', false);
    }
    execute('teleportCoords', {
        x: Number(xInput.value),
        y: Number(yInput.value),
        z: Number(zInput.value),
        w: Number(document.getElementById('coord-w').value || 0)
    });
});

noclipButton.addEventListener('click', () => execute('noclip'));
document.getElementById('refresh').addEventListener('click', async () => {
    try {
        await post('refresh');
    } catch {
        showToast('Aktualisierung fehlgeschlagen.', false);
    }
});
document.getElementById('close').addEventListener('click', closeMenu);

document.addEventListener('keydown', event => {
    if ((event.key === 'Escape' || event.key === 'F10') && !app.classList.contains('hidden')) closeMenu();
});

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;
    if (data.action === 'open') {
        app.classList.remove('hidden');
        weatherTransition.value = String(data.data.currentTransition ?? 8);
        transitionValue.textContent = `${weatherTransition.value}s`;
        applyData(data.data);
    } else if (data.action === 'refresh') {
        applyData(data.data);
    } else if (data.action === 'result') {
        showToast(data.message, data.success);
    } else if (data.action === 'noclipState') {
        state.noclip = data.enabled === true;
        noclipButton.classList.toggle('active', state.noclip);
        noclipButton.textContent = state.noclip ? 'Noclip aktiv' : 'Noclip';
    } else if (data.action === 'close') {
        app.classList.add('hidden');
    }
});

if (new URLSearchParams(window.location.search).has('preview')) {
    app.classList.remove('hidden');
    applyData({
        selfId: 4,
        players: [
            { source: 4, serverName: 'Hermion1337', characterName: 'Arthur Masterson', characterId: 3, job: 'sheriff', jobGrade: 1, cash: 850, bank: 4250, ping: 28, health: 200, itemCount: 14, frozen: false },
            { source: 12, serverName: 'EliasM', characterName: 'Elias Mercer', characterId: 8, job: 'unemployed', jobGrade: 0, cash: 75, bank: 310, ping: 51, health: 143, itemCount: 5, frozen: false },
            { source: 27, serverName: 'ClaraB', characterName: 'Clara Bennett', characterId: 11, job: 'sheriff', jobGrade: 0, cash: 215, bank: 970, ping: 37, health: 0, itemCount: 9, frozen: true }
        ],
        items: [
            { name: 'bandage', label: 'Verband', maxStack: 10 },
            { name: 'bread', label: 'Brot', maxStack: 20 },
            { name: 'lockpick', label: 'Dietrich', maxStack: 10 },
            { name: 'water', label: 'Wasserflasche', maxStack: 20 }
        ],
        weathers: [
            { id: 'sunny', label: 'Sonnig', description: 'Klarer Himmel und warmes Licht.' },
            { id: 'overcast', label: 'Bewölkt', description: 'Dichte Wolkendecke ohne Gewitter.' },
            { id: 'fog', label: 'Nebel', description: 'Starker Bodennebel mit geringer Sicht.' },
            { id: 'thunderstorm', label: 'Gewitter', description: 'Starkregen, Wind, Donner und Blitze.' },
            { id: 'snow', label: 'Schnee', description: 'Winterliches Wetter mit Schneefall.' }
        ],
        currentWeather: 'sunny',
        currentTransition: 8,
        limits: { money: 100000, items: 50, weatherTransition: 30 }
    });
}
