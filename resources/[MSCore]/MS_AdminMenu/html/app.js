const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const preview = new URLSearchParams(window.location.search).get('preview');
const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'MS_AdminMenu';

const app = $('#app');
const craftingUi = $('#crafting-ui');
const toast = $('#toast');
const state = {
    data: null,
    selectedPlayer: null,
    selectedWeather: null,
    page: 'overview',
    selectedSupportLog: null,
    worldTab: 'npc',
    craftAdminTab: 'recipes',
    dataAdminTab: 'items',
    worldPositions: {},
    capturedDoor: null,
    craftPointPosition: null,
    craftSession: null,
    craftingBusy: false,
    noclip: false
};

let toastTimer;

async function post(endpoint, body = {}) {
    if (preview) return { ok: true };
    try {
        const response = await fetch(`https://${resourceName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body)
        });
        return await response.json();
    } catch {
        return { ok: false };
    }
}

function showToast(message, success = false) {
    clearTimeout(toastTimer);
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.className = `toast ${success ? 'success' : 'error'}`;
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 4200);
}

function text(tag, value, className) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    element.textContent = value;
    return element;
}

function formatCoords(coords) {
    return coords
        ? `X ${Number(coords.x).toFixed(2)} · Y ${Number(coords.y).toFixed(2)} · Z ${Number(coords.z).toFixed(2)} · H ${Number(coords.heading || 0).toFixed(1)}`
        : 'Noch keine Position erfasst';
}

function hasPermission(permission) {
    return state.data?.permissions?.[permission] === true;
}

function choosePage(page) {
    const button = $(`.nav-button[data-tab="${page}"]`);
    if (!button || button.classList.contains('permission-hidden')) page = 'overview';
    state.page = page;
    $$('.nav-button').forEach((item) => item.classList.toggle('active', item.dataset.tab === page));
    $$('.page').forEach((item) => item.classList.toggle('active', item.dataset.page === page));
}

function applyPermissionVisibility() {
    $$('.nav-button[data-permission]').forEach((button) => {
        const allowed = button.dataset.permission.split(',').some((permission) => hasPermission(permission));
        button.classList.toggle('permission-hidden', !allowed);
    });
    ['players', 'economy', 'weather'].forEach((permission) => {
        $(`.permission-${permission}`)?.classList.toggle('permission-hidden', !hasPermission(permission));
        $$(`.permission-${permission}`).forEach((element) => {
            element.classList.toggle('permission-hidden', !hasPermission(permission));
        });
    });
    choosePage(state.page);
}

function currentPlayer() {
    return state.data?.players?.find((player) => player.source === state.selectedPlayer);
}

function renderPlayers() {
    const players = state.data?.players || [];
    const query = $('#player-search').value.trim().toLowerCase();
    const list = $('#player-list');
    list.replaceChildren();
    players
        .filter((player) => `${player.source} ${player.serverName} ${player.characterName}`.toLowerCase().includes(query))
        .forEach((player) => {
            const row = document.createElement('button');
            row.type = 'button';
            row.className = `record-row${state.selectedPlayer === player.source ? ' selected' : ''}`;
            row.append(
                text('span', `#${player.source}`, 'record-id'),
                (() => {
                    const box = document.createElement('span');
                    box.append(text('strong', player.characterName), text('small', `${player.serverName} · ${player.job} ${player.jobGrade}`));
                    return box;
                })(),
                text('small', `${player.ping}ms`)
            );
            row.addEventListener('click', () => {
                state.selectedPlayer = player.source;
                renderPlayers();
                renderPlayerDetail();
            });
            list.append(row);
        });
    $('#player-count').textContent = String(players.length);
    $('#online-status').textContent = `${players.length} Spieler`;
    $('#metric-players').textContent = String(players.length);
}

function renderPlayerDetail() {
    const player = currentPlayer();
    $('#player-empty').classList.toggle('hidden', Boolean(player));
    $('#player-detail').classList.toggle('hidden', !player);
    if (!player) return;
    $('#selected-server-name').textContent = player.serverName;
    $('#selected-name').textContent = player.characterName;
    $('#selected-meta').textContent = `${player.job} · Rang ${player.jobGrade} · Charakter #${player.characterId}`;
    $('#selected-id').textContent = `ID ${player.source}`;
    $('#selected-cash').textContent = `$${player.cash}`;
    $('#selected-bank').textContent = `$${player.bank}`;
    $('#selected-health').textContent = String(player.health);
    $('#selected-items').textContent = String(player.itemCount);
    $('#freeze-player').textContent = player.frozen ? 'Freigeben' : 'Einfrieren';
}

function itemOptions(select, selected) {
    select.replaceChildren();
    (state.data?.items || []).forEach((item) => {
        const option = document.createElement('option');
        option.value = item.name;
        option.textContent = `${item.label} (${item.name})`;
        option.selected = item.name === selected;
        select.append(option);
    });
}

function renderItems() {
    itemOptions($('#item-name'), $('#item-name').value);
    itemOptions($('#recipe-output'), $('#recipe-output').value);
    $$('.ingredient-item').forEach((select) => itemOptions(select, select.value));
}

function renderWeather() {
    const list = $('#weather-list');
    list.replaceChildren();
    (state.data?.weathers || []).forEach((weather) => {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = `weather-card${state.selectedWeather === weather.id ? ' selected' : ''}`;
        card.append(text('strong', weather.label), text('small', weather.description));
        card.addEventListener('click', () => {
            state.selectedWeather = weather.id;
            renderWeather();
        });
        list.append(card);
    });
    const selected = state.data?.weathers?.find((weather) => weather.id === state.data.currentWeather);
    $('#weather-status').textContent = `Wetter: ${selected?.label || '–'}`;
}

function renderMetrics() {
    const world = state.data?.worldBuilder?.definitions;
    const worldCount = (world?.npcs?.length || 0) + (world?.storages?.length || 0) + (world?.doors?.length || 0);
    const craft = state.data?.crafting;
    const craftCount = (craft?.recipes?.length || 0) + (craft?.points?.length || 0);
    $('#metric-admins').textContent = String(state.data?.admins?.length || 0);
    $('#metric-world').textContent = String(worldCount);
    $('#metric-crafting').textContent = String(craftCount);
}

function selectWorldTab(tab) {
    state.worldTab = tab;
    $$('[data-world-tab]').forEach((button) => button.classList.toggle('active', button.dataset.worldTab === tab));
    $$('[data-world-form]').forEach((form) => form.classList.toggle('active', form.dataset.worldForm === tab));
    const labels = { npc: 'NPCs', storage: 'Storages', door: 'Türen' };
    $('#world-list-title').textContent = labels[tab];
    renderWorldList();
}

function renderWorldCatalog() {
    const world = state.data?.worldBuilder;
    const modelList = $('#npc-models');
    const scenarioList = $('#npc-scenarios');
    modelList.replaceChildren();
    scenarioList.replaceChildren();
    (world?.models || []).forEach((entry) => {
        const option = document.createElement('option');
        option.value = entry.model;
        option.label = entry.label;
        modelList.append(option);
    });
    (world?.scenarios || []).forEach((entry) => {
        const option = document.createElement('option');
        option.value = entry.scenario;
        option.label = entry.label;
        scenarioList.append(option);
    });
    if (world?.limits?.storageCapacity) $('#storage-capacity').max = world.limits.storageCapacity;
}

function confirmAction(button, callback) {
    if (button.dataset.confirm === 'true') {
        callback();
        return;
    }
    button.dataset.confirm = 'true';
    const previous = button.textContent;
    button.textContent = 'Nochmals klicken';
    setTimeout(() => {
        button.dataset.confirm = '';
        button.textContent = previous;
    }, 2500);
}

function renderWorldList() {
    const definitions = state.data?.worldBuilder?.definitions || {};
    const key = { npc: 'npcs', storage: 'storages', door: 'doors' }[state.worldTab];
    const query = $('#world-search').value.trim().toLowerCase();
    const entries = (definitions[key] || []).filter((entry) =>
        `${entry.id} ${entry.label} ${entry.model || ''} ${entry.accessJob || ''}`.toLowerCase().includes(query)
    );
    $('#world-count').textContent = String(entries.length);
    const list = $('#world-list');
    list.replaceChildren();
    entries.forEach((entry) => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const header = document.createElement('header');
        const heading = document.createElement('div');
        heading.append(text('strong', entry.label), text('small', `#${entry.id}`));
        header.append(heading, text('span', state.worldTab.toUpperCase(), 'count-badge'));
        let detail;
        if (state.worldTab === 'npc') detail = `${entry.model}${entry.scenario ? ` · ${entry.scenario}` : ''}`;
        if (state.worldTab === 'storage') detail = `${entry.type === 'private' ? 'Privat' : 'Global'} · Kapazität ${entry.capacity} · ${entry.accessJob || 'Alle Jobs'}`;
        if (state.worldTab === 'door') detail = `${entry.locked ? 'Abgeschlossen' : 'Aufgeschlossen'} · ${entry.accessJob || 'Alle Jobs'} · Hash ${entry.modelHash}`;
        card.append(header, text('small', detail), text('small', formatCoords(entry)));
        const footer = document.createElement('footer');
        if (state.worldTab === 'door') {
            const toggle = text('button', entry.locked ? 'Aufschließen' : 'Abschließen', 'mini-button');
            toggle.type = 'button';
            toggle.addEventListener('click', () => post('worldToggleDoor', { id: entry.id }));
            footer.append(toggle);
        }
        const remove = text('button', 'Löschen', 'mini-button danger');
        remove.type = 'button';
        remove.addEventListener('click', () => confirmAction(remove, () => post('worldDelete', { kind: state.worldTab, id: entry.id })));
        footer.append(remove);
        card.append(footer);
        list.append(card);
    });
    if (!entries.length) list.append(text('div', 'Keine Einträge gefunden.', 'empty-state'));
}

function addIngredientRow(item, amount = 1) {
    const row = document.createElement('div');
    row.className = 'ingredient-row';
    const select = document.createElement('select');
    select.className = 'ingredient-item';
    itemOptions(select, item);
    const input = document.createElement('input');
    input.className = 'ingredient-amount';
    input.type = 'number';
    input.min = '1';
    input.value = String(amount);
    const remove = text('button', '×', 'mini-button');
    remove.type = 'button';
    remove.addEventListener('click', () => {
        if ($$('.ingredient-row').length > 1) row.remove();
    });
    row.append(select, input, remove);
    $('#ingredient-list').append(row);
}

function itemLabel(name) {
    return state.data?.items?.find((item) => item.name === name)?.label || name;
}

function selectCraftAdminTab(tab) {
    state.craftAdminTab = tab;
    $$('[data-craft-tab]').forEach((button) => button.classList.toggle('active', button.dataset.craftTab === tab));
    $$('[data-craft-view]').forEach((view) => view.classList.toggle('active', view.dataset.craftView === tab));
}

function selectDataAdminTab(tab) {
    state.dataAdminTab = tab;
    $$('[data-data-tab]').forEach((button) => button.classList.toggle('active', button.dataset.dataTab === tab));
    $$('[data-data-view]').forEach((view) => view.classList.toggle('active', view.dataset.dataView === tab));
}

function renderCraftingAdmin() {
    const crafting = state.data?.crafting || { recipes: [], points: [] };
    const recipeList = $('#recipe-list');
    recipeList.replaceChildren();
    crafting.recipes.forEach((recipe) => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const heading = document.createElement('header');
        const title = document.createElement('div');
        title.append(text('strong', recipe.label), text('small', `#${recipe.id} · ${recipe.duration} ms`));
        heading.append(title, text('span', `${recipe.outputAmount}× ${itemLabel(recipe.outputItem)}`, 'count-badge'));
        const materials = recipe.ingredients.map((ingredient) => `${ingredient.amount}× ${itemLabel(ingredient.item)}`).join(' · ');
        const footer = document.createElement('footer');
        const remove = text('button', 'Rezept löschen', 'mini-button danger');
        remove.type = 'button';
        remove.addEventListener('click', () => confirmAction(remove, () => post('execute', {
            action: 'deleteRecipe',
            data: { id: recipe.id }
        })));
        footer.append(remove);
        card.append(heading, text('small', recipe.description || 'Keine Beschreibung'), text('small', `Zutaten: ${materials}`), footer);
        recipeList.append(card);
    });
    if (!crafting.recipes.length) recipeList.append(text('div', 'Noch keine Rezepte vorhanden.', 'empty-state'));
    $('#recipe-count').textContent = String(crafting.recipes.length);

    const options = $('#point-recipe-options');
    options.replaceChildren();
    crafting.recipes.forEach((recipe) => {
        const label = document.createElement('label');
        label.className = 'check-option';
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.value = recipe.id;
        label.append(checkbox, text('span', `${recipe.label} → ${recipe.outputAmount}× ${itemLabel(recipe.outputItem)}`));
        options.append(label);
    });
    if (!crafting.recipes.length) options.append(text('small', 'Erstelle zuerst mindestens ein Rezept.', 'muted'));

    const pointList = $('#craft-point-list');
    pointList.replaceChildren();
    crafting.points.forEach((point) => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const heading = document.createElement('header');
        const title = document.createElement('div');
        title.append(text('strong', point.label), text('small', `#${point.id} · Radius ${point.radius}`));
        heading.append(title, text('span', point.accessJob || 'Alle Jobs', 'count-badge'));
        const names = point.recipeIds.map((id) => crafting.recipes.find((recipe) => recipe.id === id)?.label || `#${id}`).join(', ');
        const footer = document.createElement('footer');
        const remove = text('button', 'Punkt löschen', 'mini-button danger');
        remove.type = 'button';
        remove.addEventListener('click', () => confirmAction(remove, () => post('execute', {
            action: 'deleteCraftingPoint',
            data: { id: point.id }
        })));
        footer.append(remove);
        card.append(heading, text('small', `Rezepte: ${names || 'Keine'}`), text('small', formatCoords(point)), footer);
        pointList.append(card);
    });
    if (!crafting.points.length) pointList.append(text('div', 'Noch keine Crafting-Punkte vorhanden.', 'empty-state'));
    $('#craft-point-count').textContent = String(crafting.points.length);
}

function rarityLabel(rarity) {
    return {
        common: 'Gewöhnlich',
        uncommon: 'Ungewöhnlich',
        rare: 'Selten',
        epic: 'Episch',
        legendary: 'Legendär'
    }[rarity] || rarity;
}

function renderDataItems() {
    const query = $('#data-item-search').value.trim().toLowerCase();
    const items = (state.data?.items || []).filter((item) =>
        `${item.name} ${item.label} ${item.category || ''} ${item.prop || ''}`.toLowerCase().includes(query)
    );
    $('#data-item-count').textContent = String(items.length);
    const list = $('#data-item-list');
    list.replaceChildren();
    items.forEach((item) => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const heading = document.createElement('header');
        const title = document.createElement('div');
        title.append(text('strong', item.label), text('small', item.name));
        heading.append(title, text('span', item.category || 'general', 'count-badge'));
        card.append(
            heading,
            text('small', item.description || 'Keine Beschreibung'),
            text('small', `Stack ${item.maxStack} · ${item.weight || 0} g · Prop ${item.prop || 'keine Zuordnung'}`)
        );
        const flags = document.createElement('div');
        flags.className = 'item-flags';
        flags.append(text('span', rarityLabel(item.rarity || 'common'), `item-flag rarity-${item.rarity || 'common'}`));
        if (item.usable) flags.append(text('span', 'Benutzbar', 'item-flag'));
        if (item.consumable) flags.append(text('span', 'Verbrauchbar', 'item-flag'));
        if (item.unique) flags.append(text('span', 'Einzigartig', 'item-flag'));
        flags.append(text('span', item.tradable === false ? 'Nicht handelbar' : 'Handelbar', 'item-flag'));
        if (item.protected) flags.append(text('span', 'Systemitem', 'item-flag'));
        card.append(flags);

        const footer = document.createElement('footer');
        if (!item.protected) {
            const remove = text('button', 'Item löschen', 'mini-button danger');
            remove.type = 'button';
            remove.addEventListener('click', () => confirmAction(remove, () => post('execute', {
                action: 'deleteItem',
                data: { name: item.name }
            })));
            footer.append(remove);
        } else {
            footer.append(text('small', 'Geschützt durch MSCore/config.lua'));
        }
        card.append(footer);
        list.append(card);
    });
    if (!items.length) list.append(text('div', 'Keine Items gefunden.', 'empty-state'));
}

function renderProps() {
    const props = state.data?.props || [];
    const datalist = $('#item-props');
    datalist.replaceChildren();
    props.forEach((prop) => {
        const option = document.createElement('option');
        option.value = prop.model;
        option.label = `${prop.label} · ${prop.category}`;
        datalist.append(option);
    });

    const query = $('#prop-search').value.trim().toLowerCase();
    const visible = props.filter((prop) =>
        `${prop.label} ${prop.model} ${prop.category}`.toLowerCase().includes(query)
    );
    $('#prop-count').textContent = String(visible.length);
    const list = $('#prop-list');
    list.replaceChildren();
    visible.forEach((prop) => {
        const card = document.createElement('article');
        card.className = 'prop-card';
        card.append(
            text('strong', prop.label),
            text('code', prop.model || 'ohne_prop'),
            text('small', prop.category)
        );
        const use = text('button', 'In Itemcreator übernehmen', 'mini-button');
        use.type = 'button';
        use.addEventListener('click', () => {
            $('#creator-prop').value = prop.model;
            selectDataAdminTab('items');
            showToast(prop.model ? `${prop.model} übernommen.` : 'Prop-Zuordnung entfernt.', true);
        });
        card.append(use);
        list.append(card);
    });
    if (!visible.length) list.append(text('div', 'Keine Props gefunden.', 'empty-state'));
}

function renderDataAdmin() {
    renderDataItems();
    renderProps();
}

const supportLogTypes = {
    connection: { label: 'Eingehende Verbindung', icon: '↪' },
    player_spawn: { label: 'Playerspawn', icon: '⌖' },
    damage_dealt: { label: 'Ausgeteilter Schaden', icon: '⚔' },
    killed_by: { label: 'Getötet von', icon: '☠' }
};

function formatLogDate(value) {
    if (!value) return 'Zeit unbekannt';
    const date = new Date(typeof value === 'string' ? value.replace(' ', 'T') : value);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat('de-DE', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    }).format(date);
}

function supportLogTitle(log) {
    if (log.type === 'connection') return `${log.actorName} verbindet sich`;
    if (log.type === 'player_spawn') return `${log.actorName} ist gespawnt`;
    if (log.type === 'damage_dealt') return `${log.actorName} → ${log.targetName || 'Unbekannt'}`;
    if (log.type === 'killed_by') return `${log.targetName || 'Unbekannt'} getötet von ${log.actorName}`;
    return log.actorName || 'Unbekanntes Ereignis';
}

function supportLogMeta(log) {
    if (log.type === 'damage_dealt') {
        return `${log.damage ?? 0} Schaden · Waffe ${log.weaponHash || 'unbekannt'}`;
    }
    if (log.type === 'killed_by') return `Tödlicher Treffer · Waffe ${log.weaponHash || 'unbekannt'}`;
    if (log.type === 'player_spawn') return `Charakter #${log.actorCharacterId || '–'} · Server-ID ${log.actorSource || '–'}`;
    return `${log.actorIdentifier || 'Keine Lizenz'} · temporäre ID ${log.actorSource || '–'}`;
}

function supportPartyMeta(source, characterId) {
    return `Server-ID ${source || '–'} · Charakter #${characterId || '–'}`;
}

function renderSupportDetail() {
    const logs = state.data?.support?.logs || [];
    const log = logs.find((entry) => Number(entry.id) === Number(state.selectedSupportLog));
    $('#support-log-empty').classList.toggle('hidden', Boolean(log));
    $('#support-log-detail').classList.toggle('hidden', !log);
    if (!log) return;

    const definition = supportLogTypes[log.type] || { label: log.type, icon: '•' };
    $('#support-detail-type').textContent = definition.label.toUpperCase();
    $('#support-detail-title').textContent = supportLogTitle(log);
    $('#support-detail-time').textContent = formatLogDate(log.createdAt);
    $('#support-detail-id').textContent = `#${log.id}`;
    $('#support-actor-name').textContent = log.actorName || 'Unbekannt';
    $('#support-actor-meta').textContent = supportPartyMeta(log.actorSource, log.actorCharacterId);
    $('#support-actor-license').textContent = log.actorIdentifier || 'Keine Lizenz hinterlegt';
    $('#support-target-name').textContent = log.targetName || 'Kein Ziel';
    $('#support-target-meta').textContent = supportPartyMeta(log.targetSource, log.targetCharacterId);
    $('#support-target-license').textContent = log.targetIdentifier || 'Keine Lizenz hinterlegt';
    $('#support-detail-damage').textContent = log.damage == null ? '–' : String(log.damage);
    $('#support-detail-weapon').textContent = log.weaponHash || '–';
    $('#support-detail-json').textContent = JSON.stringify(log.details || {}, null, 2);
    $('#support-retention').textContent =
        `Aufbewahrung: ${state.data?.support?.retentionDays || 30} Tage · Anzeige: letzte ${state.data?.support?.limit || 500} Einträge`;
}

function renderSupportLogs() {
    const logs = state.data?.support?.logs || [];
    $('#support-connections').textContent = String(logs.filter((log) => log.type === 'connection').length);
    $('#support-spawns').textContent = String(logs.filter((log) => log.type === 'player_spawn').length);
    $('#support-damage').textContent = String(logs.filter((log) => log.type === 'damage_dealt').length);
    $('#support-kills').textContent = String(logs.filter((log) => log.type === 'killed_by').length);

    const query = $('#support-log-search').value.trim().toLowerCase();
    const type = $('#support-log-type').value;
    const visible = logs.filter((log) => {
        if (type !== 'all' && log.type !== type) return false;
        const haystack = [
            log.id,
            log.actorName,
            log.actorSource,
            log.actorCharacterId,
            log.actorIdentifier,
            log.targetName,
            log.targetSource,
            log.targetCharacterId,
            log.targetIdentifier,
            log.weaponHash,
            log.damage
        ].join(' ').toLowerCase();
        return haystack.includes(query);
    });

    if (!visible.some((log) => Number(log.id) === Number(state.selectedSupportLog))) {
        state.selectedSupportLog = visible[0]?.id ?? null;
    }

    $('#support-log-count').textContent = String(visible.length);
    const list = $('#support-log-list');
    list.replaceChildren();
    visible.forEach((log) => {
        const definition = supportLogTypes[log.type] || { label: log.type, icon: '•' };
        const row = document.createElement('button');
        row.type = 'button';
        row.className = `support-log-row type-${log.type}${Number(log.id) === Number(state.selectedSupportLog) ? ' selected' : ''}`;
        const copy = document.createElement('span');
        copy.className = 'support-log-copy';
        copy.append(text('strong', supportLogTitle(log)), text('small', `${definition.label} · ${supportLogMeta(log)}`));
        row.append(
            text('span', definition.icon, 'support-log-icon'),
            copy,
            text('time', formatLogDate(log.createdAt))
        );
        row.addEventListener('click', () => {
            state.selectedSupportLog = log.id;
            renderSupportLogs();
        });
        list.append(row);
    });
    if (!visible.length) list.append(text('div', 'Keine passenden Support-Logs gefunden.', 'empty-state'));
    renderSupportDetail();
}

function fillRightsForPlayer() {
    const source = Number($('#rights-player').value);
    const player = state.data?.players?.find((entry) => entry.source === source);
    $$('.permission-checkbox').forEach((checkbox) => {
        checkbox.checked = player?.aceRoot === true || player?.permissions?.[checkbox.value] === true;
        checkbox.disabled = player?.aceRoot === true;
    });
    const access = $('.permission-checkbox[value="access"]');
    if (access && !player?.acpGranted) access.checked = true;
}

function renderRights() {
    const playerSelect = $('#rights-player');
    const previous = Number(playerSelect.value);
    playerSelect.replaceChildren();
    (state.data?.players || []).forEach((player) => {
        const option = document.createElement('option');
        option.value = player.source;
        option.textContent = `#${player.source} · ${player.characterName} (${player.serverName})${player.aceRoot ? ' · ACE-Root' : ''}`;
        option.selected = player.source === previous;
        playerSelect.append(option);
    });

    const permissions = $('#permission-list');
    permissions.replaceChildren();
    (state.data?.permissionDefinitions || []).forEach((definition) => {
        const label = document.createElement('label');
        label.className = 'permission-option';
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.value = definition.id;
        checkbox.className = 'permission-checkbox';
        const details = document.createElement('span');
        details.append(text('strong', definition.label), text('small', definition.description));
        label.append(checkbox, details);
        permissions.append(label);
    });
    fillRightsForPlayer();

    const admins = state.data?.admins || [];
    $('#admin-count').textContent = String(admins.length);
    const list = $('#admin-list');
    list.replaceChildren();
    admins.forEach((admin) => {
        const card = document.createElement('article');
        card.className = 'definition-card';
        const heading = document.createElement('header');
        const title = document.createElement('div');
        title.append(
            text('strong', admin.displayName || 'Unbekannter Admin'),
            text('small', admin.source ? `Online · ID ${admin.source}` : 'Offline')
        );
        heading.append(title, text('span', `${Object.keys(admin.permissions || {}).length} Rechte`, 'count-badge'));
        const labels = (state.data.permissionDefinitions || [])
            .filter((definition) => admin.permissions?.[definition.id])
            .map((definition) => definition.label)
            .join(' · ');
        const footer = document.createElement('footer');
        const revoke = text('button', 'Alle Rechte entziehen', 'mini-button danger');
        revoke.type = 'button';
        revoke.addEventListener('click', () => confirmAction(revoke, () => post('execute', {
            action: 'revokePermissions',
            data: { identifier: admin.identifier }
        })));
        footer.append(revoke);
        card.append(heading, text('small', labels || 'Keine Rechte'), footer);
        list.append(card);
    });
    if (!admins.length) list.append(text('div', 'Keine persistenten Rechteprofile.', 'empty-state'));
}

function applyData(data) {
    state.data = data;
    state.selectedWeather = state.selectedWeather || data.currentWeather;
    if (state.selectedPlayer && !data.players.some((player) => player.source === state.selectedPlayer)) {
        state.selectedPlayer = null;
    }
    $('#weather-transition').max = data.limits?.weatherTransition || 30;
    $('#weather-transition').value = String(data.currentTransition ?? 8);
    $('#transition-value').textContent = `${$('#weather-transition').value}s`;
    $('#money-amount').max = data.limits?.money || 100000;
    $('#item-amount').max = data.limits?.items || 50;
    $('#recipe-output-amount').max = data.limits?.craftingAmount || 100;
    $('#recipe-duration').max = data.limits?.craftingDuration || 30000;
    renderPlayers();
    renderPlayerDetail();
    renderItems();
    renderWeather();
    renderMetrics();
    renderWorldCatalog();
    renderWorldList();
    renderCraftingAdmin();
    renderDataAdmin();
    renderSupportLogs();
    renderRights();
    applyPermissionVisibility();
}

function closeAcp() {
    app.classList.add('hidden');
    post('close');
}

function closeCrafting() {
    craftingUi.classList.add('hidden');
    state.craftSession = null;
    state.craftingBusy = false;
    post('closeCrafting');
}

function playerAction(action, extra = {}) {
    if (!state.selectedPlayer) return showToast('Wähle zuerst einen Spieler aus.');
    post('execute', { action, data: { target: state.selectedPlayer, ...extra } });
}

function renderPlayerCrafting(data) {
    state.craftSession = data;
    state.craftingBusy = false;
    $('#crafting-title').textContent = data.point?.label || 'Crafting';
    const list = $('#crafting-recipes');
    list.replaceChildren();
    (data.recipes || []).forEach((recipe) => {
        const card = document.createElement('article');
        card.className = 'craft-card';
        card.append(text('h3', recipe.label), text('p', recipe.description || 'Keine Beschreibung'));
        card.append(text('div', `${recipe.outputAmount}× ${recipe.outputLabel}`, 'craft-output'));
        const materials = document.createElement('div');
        materials.className = 'materials';
        let available = true;
        recipe.ingredients.forEach((ingredient) => {
            const row = document.createElement('div');
            const enough = ingredient.have >= ingredient.amount;
            available = available && enough;
            row.className = `material${enough ? '' : ' missing'}`;
            row.append(text('span', ingredient.label), text('strong', `${ingredient.have} / ${ingredient.amount}`));
            materials.append(row);
        });
        const craft = text('button', `Herstellen · ${(recipe.duration / 1000).toFixed(1)}s`, 'button primary full');
        craft.type = 'button';
        craft.disabled = !available;
        craft.addEventListener('click', () => {
            if (state.craftingBusy) return;
            post('craft', { pointId: data.point.id, recipeId: recipe.id });
        });
        card.append(materials, craft);
        list.append(card);
    });
    if (!data.recipes?.length) list.append(text('div', 'An diesem Punkt sind keine Rezepte verfügbar.', 'empty-state'));
}

$$('.nav-button').forEach((button) => button.addEventListener('click', () => choosePage(button.dataset.tab)));
$$('[data-world-tab]').forEach((button) => button.addEventListener('click', () => selectWorldTab(button.dataset.worldTab)));
$$('[data-craft-tab]').forEach((button) => button.addEventListener('click', () => selectCraftAdminTab(button.dataset.craftTab)));
$$('[data-data-tab]').forEach((button) => button.addEventListener('click', () => selectDataAdminTab(button.dataset.dataTab)));

$('#close').addEventListener('click', closeAcp);
$('#refresh').addEventListener('click', () => post('refresh'));
$('#close-crafting').addEventListener('click', closeCrafting);
$('#player-search').addEventListener('input', renderPlayers);
$('#world-search').addEventListener('input', renderWorldList);
$('#support-log-search').addEventListener('input', renderSupportLogs);
$('#support-log-type').addEventListener('change', renderSupportLogs);
$('#data-item-search').addEventListener('input', renderDataItems);
$('#prop-search').addEventListener('input', renderProps);
$('#rights-player').addEventListener('change', fillRightsForPlayer);
$('#weather-transition').addEventListener('input', () => {
    $('#transition-value').textContent = `${$('#weather-transition').value}s`;
});

$('#apply-weather').addEventListener('click', () => post('execute', {
    action: 'setWeather',
    data: { weather: state.selectedWeather, transition: Number($('#weather-transition').value) }
}));
$('#noclip').addEventListener('click', () => post('execute', { action: 'noclip' }));
$('#teleport-coords').addEventListener('click', () => post('execute', {
    action: 'teleportCoords',
    data: {
        x: Number($('#coord-x').value),
        y: Number($('#coord-y').value),
        z: Number($('#coord-z').value),
        w: Number($('#coord-w').value)
    }
}));
$('#give-money').addEventListener('click', () => playerAction('giveMoney', {
    account: $('#money-account').value,
    amount: Number($('#money-amount').value)
}));
$('#give-item').addEventListener('click', () => playerAction('giveItem', {
    item: $('#item-name').value,
    amount: Number($('#item-amount').value)
}));
$$('[data-player-action]').forEach((button) => button.addEventListener('click', () => playerAction(button.dataset.playerAction)));
$('#kick-player').addEventListener('click', () => playerAction('kick', { reason: $('#kick-reason').value }));

$$('.world-position').forEach((button) => button.addEventListener('click', async () => {
    const kind = button.dataset.kind;
    const response = await post('capturePosition', { kind });
    if (!response.ok || !response.coords) return showToast('Position konnte nicht erfasst werden.');
    state.worldPositions[kind] = response.coords;
    $(`#${kind}-position`).textContent = formatCoords(response.coords);
}));

$('#capture-door').addEventListener('click', async () => {
    const response = await post('captureDoor');
    if (!response.ok || !response.door) return showToast(response.error || 'Keine Tür erfasst.');
    state.capturedDoor = response.door;
    $('#door-position').textContent = `Hash ${response.door.modelHash} · ${formatCoords(response.door)}`;
});

$('#npc-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const coords = state.worldPositions.npc;
    if (!coords) return showToast('Erfasse zuerst eine Position.');
    post('worldCreate', {
        kind: 'npc',
        data: {
            label: $('#npc-label').value,
            model: $('#npc-model').value,
            scenario: $('#npc-scenario').value,
            ...coords
        }
    });
});

$('#storage-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const coords = state.worldPositions.storage;
    if (!coords) return showToast('Erfasse zuerst eine Position.');
    post('worldCreate', {
        kind: 'storage',
        data: {
            label: $('#storage-label').value,
            type: $('#storage-type').value,
            capacity: Number($('#storage-capacity').value),
            accessJob: $('#storage-job').value,
            radius: Number($('#storage-radius').value),
            ...coords
        }
    });
});

$('#door-form').addEventListener('submit', (event) => {
    event.preventDefault();
    if (!state.capturedDoor) return showToast('Visiere zuerst eine Tür an.');
    post('worldCreate', {
        kind: 'door',
        data: {
            label: $('#door-label').value,
            accessJob: $('#door-job').value,
            radius: Number($('#door-radius').value),
            locked: $('#door-locked').checked,
            ...state.capturedDoor
        }
    });
});

$('#add-ingredient').addEventListener('click', () => {
    const maximum = state.data?.limits?.craftingIngredients || 8;
    if ($$('.ingredient-row').length >= maximum) return showToast(`Maximal ${maximum} Zutaten.`);
    addIngredientRow();
});

$('#recipe-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const ingredients = $$('.ingredient-row').map((row) => ({
        item: $('.ingredient-item', row).value,
        amount: Number($('.ingredient-amount', row).value)
    }));
    post('execute', {
        action: 'createRecipe',
        data: {
            label: $('#recipe-label').value,
            description: $('#recipe-description').value,
            outputItem: $('#recipe-output').value,
            outputAmount: Number($('#recipe-output-amount').value),
            duration: Number($('#recipe-duration').value),
            ingredients
        }
    });
});

$('#capture-craft-point').addEventListener('click', async () => {
    const response = await post('capturePosition', { kind: 'crafting' });
    if (!response.ok || !response.coords) return showToast('Position konnte nicht erfasst werden.');
    state.craftPointPosition = response.coords;
    $('#craft-point-position').textContent = formatCoords(response.coords);
});

$('#craft-point-form').addEventListener('submit', (event) => {
    event.preventDefault();
    if (!state.craftPointPosition) return showToast('Erfasse zuerst eine Position.');
    const recipeIds = $$('#point-recipe-options input:checked').map((input) => Number(input.value));
    post('execute', {
        action: 'createCraftingPoint',
        data: {
            label: $('#craft-point-label').value,
            accessJob: $('#craft-point-job').value,
            radius: Number($('#craft-point-radius').value),
            recipeIds,
            ...state.craftPointPosition
        }
    });
});

$('#rights-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const target = state.data?.players?.find((player) => player.source === Number($('#rights-player').value));
    if (target?.aceRoot) return showToast('ACE-Rootrechte werden in der server.cfg verwaltet.');
    const permissions = {};
    $$('.permission-checkbox').forEach((checkbox) => {
        permissions[checkbox.value] = checkbox.checked;
    });
    post('execute', {
        action: 'setPermissions',
        data: { target: Number($('#rights-player').value), permissions }
    });
});

$('#creator-unique').addEventListener('change', () => {
    if ($('#creator-unique').checked) {
        $('#creator-max-stack').value = '1';
        $('#creator-max-stack').disabled = true;
    } else {
        $('#creator-max-stack').disabled = false;
    }
});

$('#item-creator-form').addEventListener('submit', (event) => {
    event.preventDefault();
    let metadata;
    try {
        metadata = JSON.parse($('#creator-metadata').value || '{}');
        if (!metadata || Array.isArray(metadata) || typeof metadata !== 'object') throw new Error('object');
    } catch {
        return showToast('Die Standard-Metadaten müssen ein gültiges JSON-Objekt sein.');
    }
    post('execute', {
        action: 'createItem',
        data: {
            name: $('#creator-name').value,
            label: $('#creator-label').value,
            description: $('#creator-description').value,
            category: $('#creator-category').value,
            rarity: $('#creator-rarity').value,
            maxStack: Number($('#creator-max-stack').value),
            weight: Number($('#creator-weight').value),
            prop: $('#creator-prop').value,
            image: $('#creator-image').value,
            metadata,
            usable: $('#creator-usable').checked,
            consumable: $('#creator-consumable').checked,
            unique: $('#creator-unique').checked,
            tradable: $('#creator-tradable').checked
        }
    });
});

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' && event.key !== 'F2') return;
    if (!craftingUi.classList.contains('hidden')) closeCrafting();
    else if (!app.classList.contains('hidden')) closeAcp();
});

window.addEventListener('message', ({ data }) => {
    if (!data?.action) return;
    if (data.action === 'open') {
        craftingUi.classList.add('hidden');
        app.classList.remove('hidden');
        applyData(data.data);
    } else if (data.action === 'refresh') {
        applyData(data.data);
    } else if (data.action === 'result') {
        showToast(data.message, data.success);
    } else if (data.action === 'worldData') {
        if (state.data) {
            state.data.worldBuilder = data.data;
            renderWorldCatalog();
            renderWorldList();
            renderMetrics();
        }
    } else if (data.action === 'noclipState') {
        state.noclip = data.enabled === true;
        $('#noclip').classList.toggle('active', state.noclip);
        $('#noclip').textContent = state.noclip ? 'Noclip aktiv' : 'Noclip';
    } else if (data.action === 'openCrafting') {
        app.classList.add('hidden');
        craftingUi.classList.remove('hidden');
        renderPlayerCrafting(data.data);
    } else if (data.action === 'craftingBusy') {
        state.craftingBusy = true;
        const progress = $('#crafting-progress');
        progress.style.setProperty('--duration', `${data.data?.duration || 1000}ms`);
        progress.classList.remove('hidden');
        $$('#crafting-recipes button').forEach((button) => { button.disabled = true; });
    } else if (data.action === 'craftResult') {
        state.craftingBusy = false;
        $('#crafting-progress').classList.add('hidden');
        showToast(data.message, data.success);
    } else if (data.action === 'craftPrompt') {
        $('#craft-prompt').classList.toggle('hidden', data.visible !== true);
        $('#craft-prompt kbd').textContent = data.key || 'E';
        $('#craft-prompt-label').textContent = data.label || '';
    } else if (data.action === 'captureHint') {
        $('#capture-hint').classList.toggle('hidden', data.visible !== true);
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        craftingUi.classList.add('hidden');
    }
});

const mockData = {
    selfId: 4,
    permissions: { access: true, players: true, economy: true, weather: true, world: true, crafting: true, data: true, support: true, rights: true },
    permissionDefinitions: [
        { id: 'access', label: 'ACP-Zugriff', description: 'Darf das Administrations-Control-Panel öffnen.' },
        { id: 'players', label: 'Spielerverwaltung', description: 'Teleport, Heilen, Wiederbeleben, Einfrieren, Kick und Noclip.' },
        { id: 'economy', label: 'Wirtschaft', description: 'Darf Geld und Items vergeben.' },
        { id: 'weather', label: 'Wetter', description: 'Darf das globale Wetter konfigurieren.' },
        { id: 'world', label: 'World Builder', description: 'Darf NPCs, Storages und Türen verwalten.' },
        { id: 'crafting', label: 'Crafting', description: 'Darf Rezepte und Crafting-Punkte verwalten.' },
        { id: 'data', label: 'Data Admin', description: 'Darf Datenbank-Items erstellen und löschen.' },
        { id: 'support', label: 'Support Admin', description: 'Darf Verbindungs-, Spawn-, Schadens- und Tötungslogs einsehen.' },
        { id: 'rights', label: 'Rechteverwaltung', description: 'Darf ACP-Rechte verteilen und entziehen.' }
    ],
    players: [
        { source: 4, serverName: 'Hermion1337', characterName: 'Arthur Masterson', characterId: 3, job: 'sheriff', jobGrade: 1, cash: 850, bank: 4250, ping: 28, health: 200, itemCount: 14, frozen: false, acpGranted: true, permissions: { access: true, rights: true, world: true, crafting: true } },
        { source: 12, serverName: 'EliasM', characterName: 'Elias Mercer', characterId: 8, job: 'unemployed', jobGrade: 0, cash: 75, bank: 310, ping: 51, health: 143, itemCount: 5, frozen: false, permissions: {} },
        { source: 27, serverName: 'ClaraB', characterName: 'Clara Bennett', characterId: 11, job: 'sheriff', jobGrade: 0, cash: 215, bank: 970, ping: 37, health: 0, itemCount: 9, frozen: true, permissions: {} }
    ],
    items: [
        { name: 'bandage', label: 'Verband', description: 'Medizinischer Verband.', category: 'medical', rarity: 'common', maxStack: 10, weight: 120, usable: true, consumable: true, unique: false, tradable: true, prop: 'p_cs_bandage01x', protected: true },
        { name: 'bread', label: 'Brot', description: 'Ein einfacher Reiseproviant.', category: 'food', rarity: 'common', maxStack: 20, weight: 300, usable: true, consumable: true, unique: false, tradable: true, prop: 'p_bread_06x', protected: true },
        { name: 'lockpick', label: 'Dietrich', description: 'Werkzeug für Schlösser.', category: 'tool', rarity: 'uncommon', maxStack: 10, weight: 50, usable: true, consumable: false, unique: false, tradable: true, prop: 'p_lockpick01x', protected: false },
        { name: 'water', label: 'Wasserflasche', description: 'Sauberes Trinkwasser.', category: 'drink', rarity: 'common', maxStack: 20, weight: 500, usable: true, consumable: true, unique: false, tradable: true, prop: 'p_canteen01x', protected: true }
    ],
    props: [
        { label: 'Keine Prop-Zuordnung', model: '', category: 'Allgemein' },
        { label: 'Bierflasche', model: 'p_bottlebeer01x', category: 'Getränke' },
        { label: 'Brotlaib', model: 'p_bread_06x', category: 'Nahrung' },
        { label: 'Verband', model: 'p_cs_bandage01x', category: 'Medizin' },
        { label: 'Hammer', model: 'p_hammer01x', category: 'Werkzeuge' },
        { label: 'Laterne', model: 'p_lantern09x', category: 'Ausrüstung' },
        { label: 'Goldbarren', model: 'p_goldbar01x', category: 'Wertsachen' }
    ],
    weathers: [
        { id: 'sunny', label: 'Sonnig', description: 'Klarer Himmel und warmes Licht.' },
        { id: 'overcast', label: 'Bewölkt', description: 'Dichte Wolkendecke ohne Gewitter.' },
        { id: 'fog', label: 'Nebel', description: 'Starker Bodennebel mit geringer Sicht.' },
        { id: 'thunderstorm', label: 'Gewitter', description: 'Starkregen, Wind und Blitze.' }
    ],
    currentWeather: 'sunny',
    currentTransition: 8,
    admins: [
        { identifier: 'license:preview', displayName: 'Hermion1337', source: 4, permissions: { access: true, rights: true, world: true, crafting: true } }
    ],
    worldBuilder: {
        models: [{ model: 'u_m_m_valgenstoreowner_01', label: 'Händler – Valentine' }],
        scenarios: [{ scenario: '', label: 'Nur stehen' }, { scenario: 'WORLD_HUMAN_SMOKING', label: 'Rauchen' }],
        limits: { storageCapacity: 1000, storageRadius: 5 },
        definitions: {
            npcs: [{ id: 1, label: 'Bahnhofsvorsteher', model: 'u_m_m_rhdtrainstationworker_01', scenario: 'GENERIC_STANDING_SCENARIO', x: -180.2, y: 627.1, z: 114.1, heading: 92 }],
            storages: [{ id: 2, label: 'Sheriff-Waffenkammer', type: 'global', capacity: 250, accessJob: 'sheriff', x: -278.1, y: 807.2, z: 119.4, heading: 0 }],
            doors: [{ id: 3, label: 'Sheriff-Haupteingang', modelHash: 123456789, locked: true, accessJob: 'sheriff', x: -275.8, y: 804.5, z: 119.4, heading: 180 }]
        }
    },
    crafting: {
        recipes: [
            { id: 1, label: 'Verband herstellen', description: 'Ein sauberer medizinischer Verband.', outputItem: 'bandage', outputAmount: 1, duration: 2500, ingredients: [{ item: 'bread', amount: 2 }] },
            { id: 2, label: 'Dietrich fertigen', description: 'Ein Werkzeug für einfache Schlösser.', outputItem: 'lockpick', outputAmount: 1, duration: 4500, ingredients: [{ item: 'bandage', amount: 1 }] }
        ],
        points: [{ id: 1, label: 'Werkbank Valentine', radius: 2, accessJob: null, recipeIds: [1, 2], x: -274.1, y: 810.2, z: 119.3, heading: 80 }]
    },
    support: {
        retentionDays: 30,
        limit: 500,
        logs: [
            { id: 104, type: 'killed_by', actorSource: 4, actorCharacterId: 3, actorIdentifier: 'license:attacker', actorName: 'Arthur Masterson', targetSource: 12, targetCharacterId: 8, targetIdentifier: 'license:victim', targetName: 'Elias Mercer', damage: 88, weaponHash: '3676417221', details: { willKill: true, hitComponent: 2 }, createdAt: '2026-07-25 21:44:13' },
            { id: 103, type: 'damage_dealt', actorSource: 4, actorCharacterId: 3, actorIdentifier: 'license:attacker', actorName: 'Arthur Masterson', targetSource: 12, targetCharacterId: 8, targetIdentifier: 'license:victim', targetName: 'Elias Mercer', damage: 32, weaponHash: '3676417221', details: { willKill: false, hitComponent: 3 }, createdAt: '2026-07-25 21:44:11' },
            { id: 102, type: 'player_spawn', actorSource: 12, actorCharacterId: 8, actorIdentifier: 'license:victim', actorName: 'Elias Mercer', details: { job: 'unemployed' }, createdAt: '2026-07-25 21:40:02' },
            { id: 101, type: 'connection', actorSource: 12, actorIdentifier: 'license:victim', actorName: 'EliasM', details: { phase: 'playerConnecting' }, createdAt: '2026-07-25 21:39:43' }
        ]
    },
    limits: { money: 100000, items: 50, weatherTransition: 30, craftingAmount: 100, craftingIngredients: 8, craftingDuration: 30000 }
};

if (preview) {
    if (preview === 'playercraft') {
        craftingUi.classList.remove('hidden');
        renderPlayerCrafting({
            point: { id: 1, label: 'Werkbank Valentine' },
            recipes: [{
                id: 1,
                label: 'Verband herstellen',
                description: 'Ein sauberer medizinischer Verband für unterwegs.',
                outputLabel: 'Verband',
                outputAmount: 1,
                duration: 2500,
                ingredients: [
                    { item: 'bread', label: 'Leinenstoff', amount: 2, have: 5 },
                    { item: 'water', label: 'Alkohol', amount: 1, have: 1 }
                ]
            }]
        });
    } else {
        app.classList.remove('hidden');
        applyData(mockData);
        if (['players', 'support', 'world', 'crafting', 'data', 'rights'].includes(preview)) choosePage(preview);
    }
}

addIngredientRow();
