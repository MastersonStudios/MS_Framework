const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const state = {
    open: false,
    data: null,
    selectedItem: null,
    contextItem: null,
    modalAction: null,
    drag: null
};

const app = $('#app');
const inventoryGrid = $('#inventory-grid');
const contextMenu = $('#context-menu');
const modalBackdrop = $('#modal-backdrop');

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'MS_Inventory';

async function nui(name, data = {}) {
    if (typeof GetParentResourceName !== 'function') {
        if (name === 'close') closeUi();
        return { ok: true };
    }

    try {
        const response = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (_) {
        toast('Die Spielschnittstelle antwortet nicht.', false);
        return { ok: false };
    }
}

function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
}

function formatWeight(grams) {
    const value = Number(grams) || 0;
    if (value < 1000) return `${Math.round(value)} g`;
    return `${(value / 1000).toLocaleString('de-DE', { maximumFractionDigits: 2 })} kg`;
}

function itemGlyph(item) {
    const label = String(item?.label || item?.name || '?').trim();
    return label.slice(0, 2);
}

function rarityColor(rarity) {
    return {
        uncommon: '#79a18a',
        rare: '#7395bf',
        epic: '#9b77b7',
        legendary: '#d3a348'
    }[rarity] || '#a9956c';
}

function allStacks(items) {
    const stacks = [];
    for (const item of items || []) {
        let remaining = Math.max(0, Math.floor(Number(item.amount) || 0));
        const maxStack = Math.max(1, Math.floor(Number(item.maxStack) || 1));
        let stackIndex = 0;
        while (remaining > 0) {
            stacks.push({
                item,
                amount: Math.min(maxStack, remaining),
                stackIndex
            });
            remaining -= maxStack;
            stackIndex += 1;
        }
    }
    return stacks;
}

function selectItem(item) {
    state.selectedItem = item || null;
    renderDetails();
    $$('.item-card').forEach((card) => {
        card.classList.toggle('is-selected', card.dataset.item === state.selectedItem?.name);
    });
}

function makeItemCard(stack) {
    const { item, amount } = stack;
    const card = document.createElement('article');
    card.className = 'item-card';
    card.dataset.item = item.name;
    card.style.setProperty('--rarity', rarityColor(item.rarity));
    card.draggable = Boolean(item.metadata?.clothingSlot);
    card.title = item.metadata?.clothingSlot
        ? `${item.label} – auf den passenden Outfit-Slot ziehen`
        : item.label;

    const topLine = document.createElement('div');
    topLine.className = 'item-topline';

    const glyph = document.createElement('span');
    glyph.className = 'item-glyph';
    glyph.textContent = itemGlyph(item);

    const amountLabel = document.createElement('strong');
    amountLabel.className = 'item-amount';
    amountLabel.textContent = `${amount}×`;
    topLine.append(glyph, amountLabel);

    if (item.metadata?.clothingSlot) {
        const clothingTag = document.createElement('span');
        clothingTag.className = 'clothing-tag';
        clothingTag.textContent = 'OUTFIT';
        card.append(clothingTag);
    }

    const name = document.createElement('h3');
    name.textContent = item.label || item.name;
    const category = document.createElement('small');
    category.textContent = item.category || 'Gegenstand';
    card.append(topLine, name, category);

    card.addEventListener('click', () => selectItem(item));
    card.addEventListener('contextmenu', (event) => {
        event.preventDefault();
        selectItem(item);
        openContextMenu(event.clientX, event.clientY, item);
    });
    card.addEventListener('dragstart', (event) => {
        if (!item.metadata?.clothingSlot) {
            event.preventDefault();
            return;
        }
        state.drag = {
            type: 'inventory',
            item: item.name,
            slot: item.metadata.clothingSlot
        };
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', item.name);
        requestAnimationFrame(() => card.classList.add('is-dragging'));
    });
    card.addEventListener('dragend', () => {
        card.classList.remove('is-dragging');
        clearDragState();
    });
    return card;
}

function renderInventory() {
    inventoryGrid.replaceChildren();
    const stacks = allStacks(state.data?.items);
    const configuredSlots = Math.max(1, Math.floor(Number(state.data?.limits?.slots) || 30));
    const renderSlots = Math.max(configuredSlots, stacks.length);

    for (let index = 0; index < renderSlots; index += 1) {
        const slot = document.createElement('div');
        slot.className = `inventory-slot${stacks[index] ? '' : ' is-empty'}`;
        slot.dataset.index = String(index + 1).padStart(2, '0');
        if (stacks[index]) slot.append(makeItemCard(stacks[index]));
        inventoryGrid.append(slot);
    }

    const amount = (state.data?.items || []).reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
    $('#item-count').textContent = `${amount} ${amount === 1 ? 'Gegenstand' : 'Gegenstände'}`;
}

function renderCapacity() {
    const usage = state.data?.usage || {};
    const limits = state.data?.limits || {};
    const slots = Number(usage.slots) || 0;
    const maxSlots = Math.max(1, Number(limits.slots) || Number(usage.maxSlots) || 1);
    const weight = Number(usage.weight) || 0;
    const maxWeight = Math.max(0, Number(limits.maxWeight) || Number(usage.maxWeight) || 0);

    $('#slot-usage').textContent = `${slots} / ${maxSlots}`;
    $('#weight-usage').textContent = `${formatWeight(weight)} / ${formatWeight(maxWeight)}`;
    updateMeter($('#slot-meter'), slots, maxSlots);
    updateMeter($('#weight-meter'), weight, maxWeight);
}

function updateMeter(element, value, maximum) {
    const percentage = maximum > 0 ? (value / maximum) * 100 : (value > 0 ? 100 : 0);
    element.style.width = `${clamp(percentage, 0, 100)}%`;
    element.classList.toggle('is-over', value > maximum);
}

function renderDetails() {
    const item = state.selectedItem;
    $('#details-empty').classList.toggle('is-hidden', Boolean(item));
    $('#item-details').classList.toggle('is-hidden', !item);
    if (!item) return;

    $('#detail-icon').textContent = itemGlyph(item);
    $('#detail-category').textContent = String(item.category || 'Gegenstand').toUpperCase();
    $('#detail-name').textContent = item.label || item.name;
    $('#detail-description').textContent = item.description || 'Für diesen Gegenstand ist keine Beschreibung hinterlegt.';
    $('#detail-amount').textContent = `${Number(item.amount) || 0}×`;
    $('#detail-weight').textContent = formatWeight((Number(item.weight) || 0) * (Number(item.amount) || 0));
    $('#detail-stack').textContent = String(Number(item.maxStack) || 1);
    $('#detail-status').textContent = item.metadata?.clothingSlot
        ? 'Bekleidung'
        : (item.usable ? 'Benutzbar' : 'Gegenstand');
}

function renderOutfit() {
    const container = $('#outfit-slots');
    container.replaceChildren();
    const outfit = state.data?.outfit || {};
    const slots = state.data?.outfitSlots || [];
    let equippedCount = 0;

    for (const slot of slots) {
        const equipped = outfit[slot.key];
        if (equipped) equippedCount += 1;

        const row = document.createElement('div');
        row.className = 'outfit-slot';
        row.dataset.slot = slot.key;

        const icon = document.createElement('span');
        icon.className = 'slot-icon';
        icon.textContent = String(slot.icon || slot.label || slot.key).slice(0, 3);

        const copy = document.createElement('div');
        copy.className = 'slot-copy';
        const slotLabel = document.createElement('small');
        slotLabel.textContent = slot.label || slot.key;
        const itemLabel = document.createElement('strong');
        itemLabel.textContent = equipped?.label || 'Nicht belegt';
        itemLabel.classList.toggle('slot-empty', !equipped);
        copy.append(slotLabel, itemLabel);

        row.append(icon, copy);

        if (equipped) {
            const remove = document.createElement('button');
            remove.className = 'unequip-button';
            remove.type = 'button';
            remove.title = 'Ablegen';
            remove.setAttribute('aria-label', `${equipped.label} ablegen`);
            remove.textContent = '×';
            remove.addEventListener('click', () => nui('unequip', { slot: slot.key }));
            row.append(remove);
            row.draggable = true;
            row.addEventListener('dragstart', (event) => {
                state.drag = { type: 'outfit', slot: slot.key, item: equipped.name };
                event.dataTransfer.effectAllowed = 'move';
                event.dataTransfer.setData('text/plain', equipped.name);
                requestAnimationFrame(() => row.classList.add('is-dragging'));
            });
            row.addEventListener('dragend', () => {
                row.classList.remove('is-dragging');
                clearDragState();
            });
        }

        row.addEventListener('dragover', (event) => {
            if (!state.drag || state.drag.type !== 'inventory') return;
            event.preventDefault();
            event.dataTransfer.dropEffect = 'move';
            row.classList.toggle('is-compatible', state.drag.slot === slot.key);
            row.classList.toggle('is-incompatible', state.drag.slot !== slot.key);
        });
        row.addEventListener('dragleave', () => {
            row.classList.remove('is-compatible', 'is-incompatible');
        });
        row.addEventListener('drop', (event) => {
            event.preventDefault();
            const drag = state.drag;
            clearDragState();
            if (!drag || drag.type !== 'inventory') return;
            if (drag.slot !== slot.key) {
                toast('Dieses Kleidungsstück passt nicht in den gewählten Slot.', false);
                return;
            }
            nui('equip', { item: drag.item, slot: slot.key });
        });

        container.append(row);
    }
    $('#outfit-count').textContent = equippedCount;
}

function renderAll() {
    if (!state.data) return;
    $('#player-name').textContent = state.data.player?.name || 'Reisender';
    $('#player-id').textContent = `ID ${state.data.player?.source ?? '—'}`;

    if (state.selectedItem) {
        state.selectedItem = (state.data.items || []).find((item) => item.name === state.selectedItem.name) || null;
    }
    renderCapacity();
    renderInventory();
    renderDetails();
    renderOutfit();
}

function switchTab(tabName) {
    $$('.side-tab').forEach((tab) => tab.classList.toggle('is-active', tab.dataset.tab === tabName));
    $$('.side-panel').forEach((panel) => panel.classList.remove('is-active'));
    $(`#${tabName}-panel`)?.classList.add('is-active');
}

function openUi(data) {
    state.open = true;
    state.data = data;
    app.classList.remove('is-hidden');
    app.setAttribute('aria-hidden', 'false');
    closeContextMenu();
    closeModal();
    renderAll();
}

function closeUi() {
    state.open = false;
    state.data = null;
    state.selectedItem = null;
    app.classList.add('is-hidden');
    app.setAttribute('aria-hidden', 'true');
    closeContextMenu();
    closeModal();
}

function openContextMenu(x, y, item) {
    state.contextItem = item;
    $('#context-item-name').textContent = item.label || item.name;
    $('#context-item-amount').textContent = `${Number(item.amount) || 0}×`;

    $('[data-context-action="give"]').disabled = !item.tradable;
    $('[data-context-action="discard"]').disabled = state.data?.allowDiscard !== true;
    $('[data-context-action="use"]').disabled = !item.usable;

    contextMenu.classList.remove('is-hidden');
    const rect = contextMenu.getBoundingClientRect();
    contextMenu.style.left = `${clamp(x, 8, window.innerWidth - rect.width - 8)}px`;
    contextMenu.style.top = `${clamp(y, 8, window.innerHeight - rect.height - 8)}px`;
}

function closeContextMenu() {
    contextMenu.classList.add('is-hidden');
    state.contextItem = null;
}

function openActionModal(action, item) {
    state.modalAction = action;
    state.contextItem = item;
    const isGive = action === 'give';
    $('#modal-title').textContent = isGive ? 'Item übergeben' : 'Item wegwerfen';
    $('#modal-description').textContent = `${item.label || item.name} – wähle die gewünschte Menge.`;
    $('#target-field').classList.toggle('is-hidden', !isGive);
    $('#modal-confirm').textContent = isGive ? 'Übergeben' : 'Wegwerfen';

    const maximum = Math.max(1, Math.min(
        Number(item.amount) || 1,
        Number(state.data?.maxActionAmount) || 100
    ));
    const amountInput = $('#amount-input');
    amountInput.max = String(maximum);
    amountInput.value = '1';

    const targetSelect = $('#target-select');
    targetSelect.replaceChildren();
    for (const player of state.data?.nearbyPlayers || []) {
        const option = document.createElement('option');
        option.value = String(player.source);
        option.textContent = `${player.name} (ID ${player.source})`;
        targetSelect.append(option);
    }
    if (isGive && !targetSelect.options.length) {
        const option = document.createElement('option');
        option.value = '';
        option.textContent = 'Kein Spieler in der Nähe';
        targetSelect.append(option);
    }

    modalBackdrop.classList.remove('is-hidden');
    amountInput.focus();
    amountInput.select();
}

function closeModal() {
    modalBackdrop.classList.add('is-hidden');
    state.modalAction = null;
}

function confirmModal() {
    const item = state.contextItem;
    const action = state.modalAction;
    if (!item || !action) return closeModal();

    const amount = Math.floor(Number($('#amount-input').value));
    const maximum = Number($('#amount-input').max) || 1;
    if (!Number.isInteger(amount) || amount < 1 || amount > maximum) {
        toast(`Bitte eine Menge zwischen 1 und ${maximum} angeben.`, false);
        return;
    }

    if (action === 'give') {
        const target = Number($('#target-select').value);
        if (!Number.isInteger(target) || target < 1) {
            toast('Es befindet sich kein Empfänger in deiner Nähe.', false);
            return;
        }
        nui('give', { item: item.name, amount, target });
    } else {
        nui('discard', { item: item.name, amount });
    }
    closeModal();
}

function clearDragState() {
    state.drag = null;
    inventoryGrid.classList.remove('is-drop-target');
    $$('.outfit-slot').forEach((slot) => slot.classList.remove('is-compatible', 'is-incompatible'));
}

function toast(message, success = true) {
    if (!message) return;
    const element = document.createElement('div');
    element.className = `toast${success ? '' : ' is-error'}`;
    element.textContent = message;
    $('#toast-region').append(element);
    window.setTimeout(() => element.remove(), 3600);
}

$('#close-button').addEventListener('click', () => nui('close'));
$('#refresh-button').addEventListener('click', () => nui('refresh'));
$('#modal-cancel').addEventListener('click', closeModal);
$('#modal-confirm').addEventListener('click', confirmModal);
modalBackdrop.addEventListener('mousedown', (event) => {
    if (event.target === modalBackdrop) closeModal();
});

$$('.side-tab').forEach((tab) => {
    tab.addEventListener('click', () => switchTab(tab.dataset.tab));
});

$$('[data-context-action]').forEach((button) => {
    button.addEventListener('click', () => {
        const action = button.dataset.contextAction;
        const item = state.contextItem;
        if (!item || button.disabled) return;
        closeContextMenu();
        if (action === 'use') nui('use', { item: item.name });
        else openActionModal(action, item);
    });
});

document.addEventListener('mousedown', (event) => {
    if (!contextMenu.classList.contains('is-hidden') && !contextMenu.contains(event.target)) {
        closeContextMenu();
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (!modalBackdrop.classList.contains('is-hidden')) return closeModal();
    if (!contextMenu.classList.contains('is-hidden')) return closeContextMenu();
    if (state.open) nui('close');
});

inventoryGrid.addEventListener('dragover', (event) => {
    if (state.drag?.type !== 'outfit') return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    inventoryGrid.classList.add('is-drop-target');
});
inventoryGrid.addEventListener('dragleave', (event) => {
    if (!inventoryGrid.contains(event.relatedTarget)) inventoryGrid.classList.remove('is-drop-target');
});
inventoryGrid.addEventListener('drop', (event) => {
    event.preventDefault();
    const drag = state.drag;
    clearDragState();
    if (drag?.type === 'outfit') nui('unequip', { slot: drag.slot });
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'open') openUi(message.data);
    if (message.action === 'refresh') {
        state.data = message.data;
        renderAll();
    }
    if (message.action === 'result') toast(message.message, message.success === true);
    if (message.action === 'close') closeUi();
});

if (typeof GetParentResourceName !== 'function') {
    openUi({
        player: { source: 12, name: 'Eleanor Masterson' },
        limits: { slots: 30, maxWeight: 30000 },
        usage: { slots: 9, weight: 7850 },
        allowDiscard: true,
        maxActionAmount: 100,
        nearbyPlayers: [
            { source: 7, name: 'Arthur Callahan' },
            { source: 21, name: 'Sadie Brooks' }
        ],
        items: [
            { name: 'water', label: 'Wasserflasche', description: 'Sauberes Trinkwasser.', category: 'Getränk', rarity: 'common', amount: 4, maxStack: 20, weight: 500, usable: true, tradable: true, metadata: {} },
            { name: 'bread', label: 'Brot', description: 'Ein einfacher Reiseproviant.', category: 'Nahrung', rarity: 'common', amount: 3, maxStack: 20, weight: 300, usable: true, tradable: true, metadata: {} },
            { name: 'bandage', label: 'Verband', description: 'Medizinischer Verband zur Wundversorgung.', category: 'Medizin', rarity: 'uncommon', amount: 2, maxStack: 10, weight: 120, usable: true, tradable: true, metadata: {} },
            { name: 'felt_hat', label: 'Filzhut', description: 'Ein schlichter Hut für Reisende.', category: 'Bekleidung', rarity: 'common', amount: 1, maxStack: 1, weight: 450, usable: false, tradable: true, metadata: { clothingSlot: 'hat' } },
            { name: 'duster_coat', label: 'Staubmantel', description: 'Langer Mantel gegen Staub und schlechtes Wetter.', category: 'Bekleidung', rarity: 'rare', amount: 1, maxStack: 1, weight: 1800, usable: false, tradable: true, metadata: { clothingSlot: 'coat' } },
            { name: 'lockpick', label: 'Dietrich', description: 'Werkzeug für Schlösser.', category: 'Werkzeug', rarity: 'uncommon', amount: 3, maxStack: 10, weight: 50, usable: true, tradable: true, metadata: {} }
        ],
        outfit: {
            shirt: { name: 'work_shirt', label: 'Arbeitshemd', category: 'Bekleidung', amount: 1, metadata: { clothingSlot: 'shirt' } },
            pants: { name: 'ranch_pants', label: 'Ranchhose', category: 'Bekleidung', amount: 1, metadata: { clothingSlot: 'pants' } },
            boots: { name: 'worn_boots', label: 'Reitstiefel', category: 'Bekleidung', amount: 1, metadata: { clothingSlot: 'boots' } }
        },
        outfitSlots: [
            { key: 'hat', label: 'Hut', icon: 'HUT' },
            { key: 'shirt', label: 'Hemd', icon: 'HEM' },
            { key: 'vest', label: 'Weste', icon: 'WES' },
            { key: 'coat', label: 'Mantel', icon: 'MAN' },
            { key: 'pants', label: 'Hose', icon: 'HOS' },
            { key: 'boots', label: 'Stiefel', icon: 'STI' },
            { key: 'gloves', label: 'Handschuhe', icon: 'HAN' },
            { key: 'neckwear', label: 'Halstuch', icon: 'HAL' }
        ]
    });
}
