const state = {
    characters: [],
    maximumCharacters: 1,
    selectedId: null,
    allowDelete: true,
    outfits: [],
    text: {},
    sex: 'male',
    deleting: false,
    busy: false
};

const element = (id) => document.getElementById(id);
const app = element('app');
const selectionView = element('selectionView');
const creatorView = element('creatorView');
const characterList = element('characterList');
const emptyState = element('emptyState');
const details = element('characterDetails');
const status = element('status');

async function nui(endpoint, payload = {}) {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        });
        return await response.json();
    } catch (error) {
        return { ok: false, error: 'Die Verbindung zur Resource wurde unterbrochen.' };
    }
}

function text(key, fallback) {
    return state.text[key] || fallback;
}

function setStatus(message = '', isLoading = false) {
    status.textContent = message;
    status.classList.toggle('loading', isLoading);
}

function setBusy(value) {
    state.busy = value;
    document.querySelectorAll('button, input, select, textarea').forEach((control) => {
        control.disabled = value;
    });
    if (!value) updateActionAvailability();
}

function money(value) {
    return new Intl.NumberFormat('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(value) || 0);
}

function selectedCharacter() {
    return state.characters.find((character) => Number(character.id) === Number(state.selectedId));
}

function updateDetails() {
    const character = selectedCharacter();
    details.classList.toggle('hidden', !character);
    if (!character) return;

    element('detailName').textContent = `${character.firstname} ${character.lastname}`;
    element('detailJob').textContent = character.jobLabel || character.job || 'Arbeitslos';
    element('detailBirth').textContent = character.dateOfBirth || '—';
    element('detailMoney').textContent = `$ ${money(character.money)}`;
    const metadata = character.metadata && typeof character.metadata === 'object' ? character.metadata : {};
    element('detailDescription').textContent = metadata.description || '';
}

function updateActionAvailability() {
    const hasSelection = Boolean(selectedCharacter());
    element('playButton').disabled = state.busy || !hasSelection;
    element('deleteButton').disabled = state.busy || !hasSelection || !state.allowDelete;
    element('createButton').disabled = state.busy || state.characters.length >= state.maximumCharacters;
    element('saveButton').disabled = state.busy;
    element('backButton').disabled = state.busy || state.characters.length === 0;
}

function renderCharacters() {
    characterList.innerHTML = '';
    emptyState.classList.toggle('hidden', state.characters.length > 0);
    element('slotCount').textContent = `${state.characters.length} / ${state.maximumCharacters}`;

    for (const character of state.characters) {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = `character-card${Number(character.id) === Number(state.selectedId) ? ' active' : ''}`;
        card.innerHTML = `<span><strong></strong><span class="card-job"></span></span><span class="card-id"></span>`;
        card.querySelector('strong').textContent = `${character.firstname} ${character.lastname}`;
        card.querySelector('.card-job').textContent = character.jobLabel || character.job || 'Arbeitslos';
        card.querySelector('.card-id').textContent = String(character.id).padStart(2, '0');
        card.addEventListener('click', () => chooseCharacter(character.id));
        characterList.appendChild(card);
    }
    updateDetails();
    updateActionAvailability();
}

async function chooseCharacter(characterId) {
    if (state.busy) return;
    state.selectedId = Number(characterId);
    state.deleting = false;
    element('deleteButton').classList.remove('confirming');
    element('deleteButton').textContent = text('delete', 'Löschen');
    renderCharacters();
    const result = await nui('previewCharacter', { characterId: state.selectedId });
    if (!result.ok) setStatus(result.error || 'Vorschau konnte nicht geladen werden.');
}

function fillText() {
    const mappings = {
        title: 'title', subtitle: 'subtitle', slots: 'slotsLabel', empty: 'emptyState',
        create: 'createButton', play: 'playButton', delete: 'deleteButton', back: 'backButton',
        save: 'saveButton', firstname: 'firstnameLabel', lastname: 'lastnameLabel',
        dateOfBirth: 'birthLabel', sex: 'sexLabel', male: 'maleButton', female: 'femaleButton',
        outfit: 'outfitLabel', description: 'descriptionLabel', money: 'moneyLabel'
    };
    for (const [key, id] of Object.entries(mappings)) {
        if (state.text[key]) element(id).textContent = state.text[key];
    }
    element('rotateLeft').setAttribute('aria-label', text('rotateLeft', 'Nach links drehen'));
    element('rotateRight').setAttribute('aria-label', text('rotateRight', 'Nach rechts drehen'));
}

function showSelection() {
    creatorView.classList.add('hidden');
    selectionView.classList.remove('hidden');
    setStatus('');
    if (!state.selectedId && state.characters[0]) state.selectedId = Number(state.characters[0].id);
    renderCharacters();
    if (state.selectedId) chooseCharacter(state.selectedId);
}

function currentAppearance() {
    return {
        sex: state.sex,
        outfitPreset: Number(element('outfitPreset').value)
    };
}

async function previewCreator() {
    const result = await nui('previewAppearance', currentAppearance());
    if (!result.ok) setStatus(result.error || 'Vorschau konnte nicht geladen werden.');
}

function showCreator(reset = false) {
    selectionView.classList.add('hidden');
    creatorView.classList.remove('hidden');
    setStatus('');
    if (reset) {
        element('creatorForm').reset();
        state.sex = 'male';
        element('maleButton').classList.add('active');
        element('femaleButton').classList.remove('active');
        if (state.outfits[0]) element('outfitPreset').value = String(state.outfits[0].id);
    }
    updateActionAvailability();
    previewCreator();
}

function configureOutfits() {
    const select = element('outfitPreset');
    select.innerHTML = '';
    for (const preset of state.outfits) {
        const option = document.createElement('option');
        option.value = preset.id;
        option.textContent = preset.label;
        select.appendChild(option);
    }
}

function open(payload) {
    state.characters = Array.isArray(payload.characters) ? payload.characters : [];
    state.maximumCharacters = Number(payload.maximumCharacters) || 1;
    state.allowDelete = payload.allowDelete !== false;
    state.outfits = Array.isArray(payload.outfits) ? payload.outfits : [];
    state.text = payload.text || {};
    state.selectedId = state.characters[0] ? Number(state.characters[0].id) : null;
    state.deleting = false;
    state.busy = false;
    element('dateOfBirth').min = payload.minimumDate || '';
    element('dateOfBirth').max = payload.maximumDate || '';
    configureOutfits();
    fillText();
    app.classList.add('visible');
    app.setAttribute('aria-hidden', 'false');
    if (payload.startInCreator || state.characters.length === 0) showCreator(true);
    else showSelection();
}

function close() {
    app.classList.remove('visible');
    app.setAttribute('aria-hidden', 'true');
    setStatus('');
    state.busy = false;
}

window.addEventListener('message', (event) => {
    if (event.data?.action === 'open') open(event.data);
    if (event.data?.action === 'close') close();
});

element('createButton').addEventListener('click', () => showCreator(true));
element('backButton').addEventListener('click', showSelection);
element('outfitPreset').addEventListener('change', previewCreator);

for (const button of [element('maleButton'), element('femaleButton')]) {
    button.addEventListener('click', () => {
        state.sex = button.dataset.sex;
        element('maleButton').classList.toggle('active', state.sex === 'male');
        element('femaleButton').classList.toggle('active', state.sex === 'female');
        previewCreator();
    });
}

element('rotateLeft').addEventListener('click', () => nui('rotate', { delta: -15 }));
element('rotateRight').addEventListener('click', () => nui('rotate', { delta: 15 }));

element('playButton').addEventListener('click', async () => {
    const character = selectedCharacter();
    if (!character || state.busy) return;
    setBusy(true);
    setStatus(text('loading', 'Wird verarbeitet …'), true);
    const result = await nui('selectCharacter', { characterId: character.id });
    if (!result.ok) {
        setBusy(false);
        setStatus(result.error || 'Charakter konnte nicht geladen werden.');
    }
});

element('deleteButton').addEventListener('click', async () => {
    const character = selectedCharacter();
    if (!character || state.busy || !state.allowDelete) return;
    if (!state.deleting) {
        state.deleting = true;
        element('deleteButton').classList.add('confirming');
        element('deleteButton').textContent = text('deleteConfirm', 'Wirklich löschen?');
        window.setTimeout(() => {
            state.deleting = false;
            element('deleteButton').classList.remove('confirming');
            element('deleteButton').textContent = text('delete', 'Löschen');
        }, 4000);
        return;
    }

    setBusy(true);
    setStatus(text('loading', 'Wird verarbeitet …'), true);
    const result = await nui('deleteCharacter', { characterId: character.id });
    state.deleting = false;
    if (!result.ok) {
        setBusy(false);
        setStatus(result.error || 'Charakter konnte nicht gelöscht werden.');
    }
});

element('creatorForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    if (state.busy) return;
    setBusy(true);
    setStatus(text('loading', 'Wird verarbeitet …'), true);
    const payload = {
        firstname: element('firstname').value.trim(),
        lastname: element('lastname').value.trim(),
        dateOfBirth: element('dateOfBirth').value,
        sex: state.sex,
        description: element('description').value.trim(),
        appearance: currentAppearance()
    };
    const result = await nui('createCharacter', payload);
    if (!result.ok) {
        setBusy(false);
        setStatus(result.error || 'Charakter konnte nicht erstellt werden.');
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !creatorView.classList.contains('hidden') && state.characters.length > 0 && !state.busy) {
        showSelection();
    }
});
