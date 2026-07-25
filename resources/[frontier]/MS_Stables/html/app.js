const app = document.getElementById('app');
const prompt = document.getElementById('prompt');
const toast = document.getElementById('toast');
const pageTitle = document.getElementById('page-title');
const equipmentHorse = document.getElementById('equipment-horse');
const coatHorse = document.getElementById('coat-horse');

const state = {
    tab: 'owned',
    data: null,
    equipmentHorseId: null,
    coatHorseId: null
};

let toastTimer;

const post = async (endpoint, body = {}) => {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    });
    return response.json();
};

const money = value => `${state.data?.currency || '$'}${Number(value || 0).toLocaleString('de-DE')}`;
const empty = message => `<div class="empty">${message}</div>`;
const horseById = id => state.data?.horses.find(horse => Number(horse.id) === Number(id));
const horseDefinition = key => state.data?.catalog.horses.find(horse => horse.key === key);

const showToast = (message, success = true) => {
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.className = `toast ${success ? 'success' : 'error'}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 4200);
};

const tag = text => {
    const span = document.createElement('span');
    span.textContent = text;
    return span.outerHTML;
};

const setTab = tab => {
    state.tab = tab;
    const titles = {
        owned: 'Mein Stall',
        horses: 'Pferdemarkt',
        equipment: 'Ausrüstung',
        coats: 'Fellfarben',
        wagons: 'Kutschen'
    };
    pageTitle.textContent = titles[tab] || 'Stallungen';
    document.querySelectorAll('.nav-item').forEach(button =>
        button.classList.toggle('active', button.dataset.tab === tab));
    document.querySelectorAll('.tab-panel').forEach(panel =>
        panel.classList.toggle('hidden', panel.dataset.panel !== tab));
    render();
};

const renderHorseOptions = () => {
    const horses = state.data?.horses || [];
    const renderSelect = (select, currentId) => {
        select.replaceChildren();
        horses.forEach(horse => {
            const option = document.createElement('option');
            option.value = String(horse.id);
            option.textContent = horse.name;
            select.append(option);
        });
        const selected = horses.some(horse => Number(horse.id) === Number(currentId))
            ? Number(currentId)
            : horses[0]?.id;
        if (selected) select.value = String(selected);
        return selected || null;
    };
    state.equipmentHorseId = renderSelect(equipmentHorse, state.equipmentHorseId);
    state.coatHorseId = renderSelect(coatHorse, state.coatHorseId);
};

const renderOwned = () => {
    const data = state.data;
    const active = data.active;
    const activeState = document.getElementById('active-state');
    if (active) {
        const asset = active.kind === 'horse'
            ? data.horses.find(row => Number(row.id) === Number(active.assetId))
            : data.wagons.find(row => Number(row.id) === Number(active.assetId));
        activeState.innerHTML = `<strong>${asset?.name || asset?.label || 'Stallobjekt'}</strong><span>Aktuell draußen</span>`;
    } else {
        activeState.innerHTML = '<strong>Alles eingestellt</strong><span>Kein Stallobjekt aktiv</span>';
    }

    document.getElementById('horse-count').textContent = `${data.horses.length} / ${data.limits.horses}`;
    document.getElementById('wagon-count').textContent = `${data.wagons.length} / ${data.limits.wagons}`;

    const horseRoot = document.getElementById('owned-horses');
    horseRoot.replaceChildren();
    if (!data.horses.length) horseRoot.innerHTML = empty('Du besitzt noch kein Pferd.');
    data.horses.forEach(horse => {
        const definition = horseDefinition(horse.horseKey);
        const coat = definition?.coats.find(row => row.key === horse.coatKey);
        const isActive = active?.kind === 'horse' && Number(active.assetId) === Number(horse.id);
        const card = document.createElement('article');
        card.className = `asset-card${isActive ? ' active' : ''}`;
        card.innerHTML = `
            <header><h4></h4><span class="tag">${isActive ? 'Draußen' : definition?.label || horse.horseKey}</span></header>
            <p>${coat?.label || horse.coatKey} · ${Object.keys(horse.equipped || {}).length} Ausrüstungsteile angelegt</p>
            <div class="card-meta">${tag(`ID ${horse.id}`)}${tag(horse.model)}</div>
            <div class="card-footer">
                <span class="price">${isActive ? 'Bereit' : 'Im Stall'}</span>
                <button class="button ${isActive ? 'danger' : ''}" data-${isActive ? 'dismiss-kind' : 'spawn-kind'}="horse" data-asset-id="${horse.id}">
                    ${isActive ? 'Einstellen' : 'Pferd holen'}
                </button>
            </div>`;
        card.querySelector('h4').textContent = horse.name;
        horseRoot.append(card);
    });

    const wagonRoot = document.getElementById('owned-wagons');
    wagonRoot.replaceChildren();
    if (!data.wagons.length) wagonRoot.innerHTML = empty('Du besitzt noch keine Kutsche.');
    data.wagons.forEach(wagon => {
        const isActive = active?.kind === 'wagon' && Number(active.assetId) === Number(wagon.id);
        const card = document.createElement('article');
        card.className = `asset-card${isActive ? ' active' : ''}`;
        card.innerHTML = `
            <header><h4></h4><span class="tag">${isActive ? 'Draußen' : 'Kutsche'}</span></header>
            <p>${wagon.model}</p>
            <div class="card-meta">${tag(`ID ${wagon.id}`)}</div>
            <div class="card-footer">
                <span class="price">${isActive ? 'Bereit' : 'Im Stall'}</span>
                <button class="button ${isActive ? 'danger' : ''}" data-${isActive ? 'dismiss-kind' : 'spawn-kind'}="wagon" data-asset-id="${wagon.id}">
                    ${isActive ? 'Einstellen' : 'Kutsche holen'}
                </button>
            </div>`;
        card.querySelector('h4').textContent = wagon.label;
        wagonRoot.append(card);
    });
};

const renderHorseCatalog = () => {
    const root = document.getElementById('horse-catalog');
    root.replaceChildren();
    state.data.catalog.horses.forEach(horse => {
        const defaultCoat = horse.coats[0];
        const card = document.createElement('article');
        card.className = 'catalog-card';
        card.innerHTML = `
            <header><h4></h4><span class="tag">${horse.coats.length} Farben</span></header>
            <p></p>
            <div class="card-meta">${tag(defaultCoat?.label || 'Standardfell')}${tag(defaultCoat?.model || '')}</div>
            <div class="card-footer">
                <strong class="price">${money(horse.price)}</strong>
                <button class="button" data-buy-horse="${horse.key}">Kaufen</button>
            </div>`;
        card.querySelector('h4').textContent = horse.label;
        card.querySelector('p').textContent = horse.description;
        root.append(card);
    });
};

const renderEquipment = () => {
    const root = document.getElementById('equipment-catalog');
    root.replaceChildren();
    const horse = horseById(state.equipmentHorseId);
    if (!horse) return root.innerHTML = empty('Kaufe zuerst ein Pferd.');

    state.data.catalog.equipment.forEach(equipment => {
        const compatible = !equipment.breeds || equipment.breeds.includes(horse.horseKey);
        const owned = (horse.ownedEquipment || []).includes(equipment.key);
        const equipped = horse.equipped?.[equipment.category] === equipment.key;
        const card = document.createElement('article');
        card.className = `catalog-card${equipped ? ' active' : ''}`;
        card.innerHTML = `
            <header><h4></h4><span class="tag">${equipped ? 'Angelegt' : equipment.categoryLabel}</span></header>
            <p></p>
            <div class="card-meta">${tag(`Gesundheit +${equipment.healthBonus}`)}${owned ? tag('Im Besitz') : ''}</div>
            <div class="card-footer">
                <strong class="price">${owned ? 'Gekauft' : money(equipment.price)}</strong>
                <button class="button" data-equipment="${equipment.key}" ${!compatible || equipped ? 'disabled' : ''}>
                    ${equipped ? 'Angelegt' : owned ? 'Anlegen' : 'Kaufen & anlegen'}
                </button>
            </div>`;
        card.querySelector('h4').textContent = equipment.label;
        card.querySelector('p').textContent = compatible ? equipment.description : 'Nicht mit dieser Pferderasse kompatibel.';
        root.append(card);
    });
};

const renderCoats = () => {
    const root = document.getElementById('coat-catalog');
    root.replaceChildren();
    const horse = horseById(state.coatHorseId);
    const definition = horse && horseDefinition(horse.horseKey);
    if (!horse || !definition) return root.innerHTML = empty('Kaufe zuerst ein Pferd.');

    definition.coats.forEach(coat => {
        const owned = (horse.ownedCoats || []).includes(coat.key);
        const equipped = horse.coatKey === coat.key;
        const card = document.createElement('article');
        card.className = `catalog-card${equipped ? ' active' : ''}`;
        card.innerHTML = `
            <header><h4></h4><span class="tag">${equipped ? 'Aktiv' : definition.label}</span></header>
            <p>${coat.model}</p>
            <div class="card-meta">${owned ? tag('Im Besitz') : tag('Neue Fellvariante')}</div>
            <div class="card-footer">
                <strong class="price">${owned ? 'Gekauft' : money(coat.price)}</strong>
                <button class="button" data-coat="${coat.key}" ${equipped ? 'disabled' : ''}>
                    ${equipped ? 'Ausgewählt' : owned ? 'Auswählen' : 'Kaufen & auswählen'}
                </button>
            </div>`;
        card.querySelector('h4').textContent = coat.label;
        root.append(card);
    });
};

const renderWagonCatalog = () => {
    const root = document.getElementById('wagon-catalog');
    root.replaceChildren();
    state.data.catalog.wagons.forEach(wagon => {
        const card = document.createElement('article');
        card.className = 'catalog-card';
        card.innerHTML = `
            <header><h4></h4><span class="tag">Wagen</span></header>
            <p></p>
            <div class="card-meta">${tag(wagon.model)}</div>
            <div class="card-footer">
                <strong class="price">${money(wagon.price)}</strong>
                <button class="button" data-buy-wagon="${wagon.key}">Kaufen</button>
            </div>`;
        card.querySelector('h4').textContent = wagon.label;
        card.querySelector('p').textContent = wagon.description;
        root.append(card);
    });
};

const render = () => {
    if (!state.data) return;
    document.getElementById('stable-name').textContent = state.data.stable.label.toUpperCase();
    document.getElementById('account-label').textContent = state.data.account.toUpperCase();
    document.getElementById('balance').textContent = money(state.data.balance);
    renderHorseOptions();
    if (state.tab === 'owned') renderOwned();
    else if (state.tab === 'horses') renderHorseCatalog();
    else if (state.tab === 'equipment') renderEquipment();
    else if (state.tab === 'coats') renderCoats();
    else if (state.tab === 'wagons') renderWagonCatalog();
};

document.querySelectorAll('.nav-item').forEach(button =>
    button.addEventListener('click', () => setTab(button.dataset.tab)));

equipmentHorse.addEventListener('change', () => {
    state.equipmentHorseId = Number(equipmentHorse.value);
    renderEquipment();
});
coatHorse.addEventListener('change', () => {
    state.coatHorseId = Number(coatHorse.value);
    renderCoats();
});

document.querySelector('.page').addEventListener('click', event => {
    const buyHorse = event.target.closest('[data-buy-horse]');
    if (buyHorse) {
        const name = document.getElementById('horse-name').value.trim();
        if (name.length < 2) return showToast('Gib deinem Pferd zuerst einen Namen.', false);
        return post('purchaseHorse', { horseKey: buyHorse.dataset.buyHorse, name });
    }

    const equipment = event.target.closest('[data-equipment]');
    if (equipment) return post('purchaseEquipment', {
        horseId: state.equipmentHorseId,
        equipmentKey: equipment.dataset.equipment
    });

    const coat = event.target.closest('[data-coat]');
    if (coat) return post('purchaseCoat', {
        horseId: state.coatHorseId,
        coatKey: coat.dataset.coat
    });

    const wagon = event.target.closest('[data-buy-wagon]');
    if (wagon) return post('purchaseWagon', { wagonKey: wagon.dataset.buyWagon });

    const spawn = event.target.closest('[data-spawn-kind]');
    if (spawn) return post('spawnAsset', {
        kind: spawn.dataset.spawnKind,
        assetId: Number(spawn.dataset.assetId)
    });

    const dismiss = event.target.closest('[data-dismiss-kind]');
    if (dismiss) return post('dismissAsset', { kind: dismiss.dataset.dismissKind });
});

const close = async () => {
    app.classList.add('hidden');
    try { await post('close'); } catch {}
};
document.getElementById('close').addEventListener('click', close);
document.getElementById('refresh').addEventListener('click', () => post('refresh'));
document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !app.classList.contains('hidden')) close();
});

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;
    if (data.action === 'open') {
        state.data = data.data;
        app.classList.remove('hidden');
        setTab('owned');
    } else if (data.action === 'refresh') {
        state.data = data.data;
        render();
    } else if (data.action === 'result') {
        showToast(data.message, data.success);
    } else if (data.action === 'prompt') {
        prompt.classList.toggle('hidden', !data.visible);
        if (data.visible) {
            document.getElementById('prompt-key').textContent = data.key || 'E';
            document.getElementById('prompt-label').textContent = data.label || 'Stallungen';
        }
    } else if (data.action === 'close') {
        app.classList.add('hidden');
    }
});

const preview = new URLSearchParams(window.location.search).get('preview');
if (preview) {
    state.data = {
        stable: { id: 'valentine', label: 'Valentine Stallungen' },
        account: 'bank',
        currency: '$',
        balance: 1325,
        limits: { horses: 8, wagons: 5 },
        active: { kind: 'horse', assetId: 1 },
        horses: [{
            id: 1,
            name: 'Spirit',
            horseKey: 'morgan',
            coatKey: 'bay',
            model: 'a_c_horse_morgan_bay',
            ownedEquipment: ['trail_saddle'],
            equipped: { saddle: 'trail_saddle' },
            ownedCoats: ['bay']
        }],
        wagons: [{ id: 2, label: 'Arbeitskarren', wagonKey: 'utility_cart', model: 'cart01' }],
        catalog: {
            horses: [{
                key: 'morgan',
                label: 'Morgan',
                description: 'Ein zuverlässiges, wendiges Pferd für den Alltag.',
                price: 180,
                coats: [
                    { key: 'bay', label: 'Braun', model: 'a_c_horse_morgan_bay', price: 0 },
                    { key: 'flaxen_chestnut', label: 'Fuchs', model: 'a_c_horse_morgan_flaxenchestnut', price: 55 }
                ]
            }],
            equipment: [{
                key: 'trail_saddle',
                label: 'Wandersattel',
                description: 'Bequemer Sattel für längere Reisen.',
                category: 'saddle',
                categoryLabel: 'Sattel',
                price: 85,
                healthBonus: 20
            }],
            wagons: [{
                key: 'utility_cart',
                label: 'Arbeitskarren',
                description: 'Kleiner Karren für Waren und kurze Wege.',
                model: 'cart01',
                price: 300
            }]
        }
    };
    app.classList.remove('hidden');
    setTab(preview);
}
