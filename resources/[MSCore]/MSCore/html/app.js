const app = document.getElementById('app');
const loading = document.getElementById('loading');
const grid = document.getElementById('characters');
const selectionPreview = document.getElementById('selection-preview');
const selectionPreviewName = document.getElementById('selection-preview-name');
const selectionPreviewProfile = document.getElementById('selection-preview-profile');
const slotCount = document.getElementById('slot-count');
const closeButton = document.getElementById('close');
const creator = document.getElementById('creator');
const creatorForm = document.getElementById('creator-form');
const cancelCreate = document.getElementById('cancel-create');
const submitCreate = document.getElementById('submit-create');
const firstname = document.getElementById('firstname');
const lastname = document.getElementById('lastname');
const nickname = document.getElementById('nickname');
const description = document.getElementById('description');
const birthdate = document.getElementById('birthdate');
const headInput = document.getElementById('head');
const bodyInput = document.getElementById('body-shape');
const hairInput = document.getElementById('hair');
const beardInput = document.getElementById('beard');
const eyesInput = document.getElementById('eyes');
const heightInput = document.getElementById('height');
const beardField = document.getElementById('beard-field');
const headValue = document.getElementById('head-value');
const bodyValue = document.getElementById('body-value');
const hairValue = document.getElementById('hair-value');
const beardValue = document.getElementById('beard-value');
const eyesValue = document.getElementById('eyes-value');
const heightValue = document.getElementById('height-value');
const outfitOptions = document.getElementById('outfit-options');
const rotateLeft = document.getElementById('rotate-left');
const rotateRight = document.getElementById('rotate-right');
const creatorZoom = document.getElementById('creator-zoom');
const confirmation = document.getElementById('confirmation');
const confirmationText = document.getElementById('confirmation-text');
const cancelDelete = document.getElementById('cancel-delete');
const confirmDelete = document.getElementById('confirm-delete');
const creationConfirmation = document.getElementById('creation-confirmation');
const creationSummary = document.getElementById('creation-summary');
const cancelCreationConfirm = document.getElementById('cancel-creation-confirm');
const confirmCreation = document.getElementById('confirm-creation');
const creationLoading = document.getElementById('creation-loading');
const toast = document.getElementById('toast');

let characters = [];
let maxCharacters = 3;
let activeCharacterId = null;
let pendingDelete = null;
let pendingCreation = null;
let busy = false;
let previewTimer = null;
let zoomTimer = null;
let selectionPreviewTimer = null;
const appearanceKeys = ['head', 'body', 'hair', 'beard', 'eyes', 'height'];
const appearanceInputs = {
    head: headInput,
    body: bodyInput,
    hair: hairInput,
    beard: beardInput,
    eyes: eyesInput,
    height: heightInput
};
const appearanceOutputs = {
    head: headValue,
    body: bodyValue,
    hair: hairValue,
    beard: beardValue,
    eyes: eyesValue,
    height: heightValue
};
let creatorSettings = {
    enabled: true,
    defaults: {
        sex: 'male',
        head: 1,
        body: 1,
        hair: 1,
        beard: 1,
        eyes: 1,
        height: 2,
        outfit: 'frontier'
    },
    options: { male: {}, female: {} },
    profile: { nicknameMaxLength: 32, descriptionMaxLength: 280 },
    outfits: []
};

const post = async (endpoint, body = {}) => {
    if (typeof GetParentResourceName !== 'function') return { ok: true };
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    });
    return response.json();
};

const requestFocus = async centerCursor => {
    window.focus();
    try {
        await post('requestFocus', { centerCursor: centerCursor === true });
    } catch {
        // Die lokale HTML-Vorschau besitzt keinen NUI-Callback.
    }
};

const focusFirstname = () => {
    requestAnimationFrame(() => {
        firstname.focus({ preventScroll: true });
        firstname.select();
    });
};

const showError = message => {
    toast.textContent = message || 'Ein unbekannter Fehler ist aufgetreten.';
    toast.classList.remove('hidden');
    clearTimeout(showError.timer);
    showError.timer = setTimeout(() => toast.classList.add('hidden'), 4500);
};

const setBusy = value => {
    busy = value;
    submitCreate.disabled = value;
    confirmDelete.disabled = value;
    confirmCreation.disabled = value;
    grid.querySelectorAll('button').forEach(button => { button.disabled = value; });
    creatorForm.querySelectorAll('input, textarea, button').forEach(control => { control.disabled = value; });
    document.querySelectorAll('.preview-panel button, .preview-panel input')
        .forEach(control => { control.disabled = value; });
};

const selectedSex = () =>
    creatorForm.querySelector('input[name="sex"]:checked')?.value === 'female' ? 'female' : 'male';

const selectedOutfit = () =>
    creatorForm.querySelector('input[name="outfit"]:checked')?.value || creatorSettings.defaults.outfit;

const currentAppearance = () => {
    const appearance = {
        sex: selectedSex(),
        outfit: selectedOutfit()
    };
    appearanceKeys.forEach(key => {
        appearance[key] = Number(appearanceInputs[key].value || 1);
    });
    return appearance;
};

const updateRangeLabels = () => {
    const options = creatorSettings.options[selectedSex()] || {};
    appearanceKeys.forEach(key => {
        const labels = Array.isArray(options[key]) ? options[key] : [];
        const index = Math.max(0, Number(appearanceInputs[key].value || 1) - 1);
        appearanceOutputs[key].textContent = labels[index] || `Option ${index + 1}`;
    });
};

const updateAppearanceLimits = () => {
    const options = creatorSettings.options[selectedSex()] || {};
    appearanceKeys.forEach(key => {
        const labels = Array.isArray(options[key]) ? options[key] : [];
        const input = appearanceInputs[key];
        input.max = Math.max(1, labels.length);
        input.value = Math.min(Number(input.value || 1), Number(input.max));
    });
    beardField.classList.toggle('hidden', selectedSex() === 'female');
    updateRangeLabels();
};

const renderOutfits = () => {
    outfitOptions.replaceChildren();
    creatorSettings.outfits.forEach(outfit => {
        const label = makeElement('label', 'outfit-card');
        const input = document.createElement('input');
        const copy = makeElement('span', 'outfit-copy');
        input.type = 'radio';
        input.name = 'outfit';
        input.value = outfit.key;
        input.checked = outfit.key === creatorSettings.defaults.outfit;
        copy.append(
            makeElement('strong', '', outfit.label || outfit.key),
            makeElement('small', '', outfit.description || '')
        );
        label.append(input, copy);
        outfitOptions.append(label);
    });
};

const configureCreator = settings => {
    if (settings && typeof settings === 'object') {
        creatorSettings = {
            enabled: settings.enabled !== false,
            defaults: { ...creatorSettings.defaults, ...(settings.defaults || {}) },
            options: { ...creatorSettings.options, ...(settings.options || {}) },
            profile: { ...creatorSettings.profile, ...(settings.profile || {}) },
            outfits: Array.isArray(settings.outfits) ? settings.outfits : []
        };
    }
    nickname.maxLength = Number(creatorSettings.profile.nicknameMaxLength || 32);
    description.maxLength = Number(creatorSettings.profile.descriptionMaxLength || 280);
    renderOutfits();
};

const resetCreatorForm = () => {
    creatorForm.reset();
    const defaults = creatorSettings.defaults;
    const sex = defaults.sex === 'female' ? 'female' : 'male';
    const sexInput = creatorForm.querySelector(`input[name="sex"][value="${sex}"]`);
    if (sexInput) sexInput.checked = true;
    appearanceKeys.forEach(key => {
        appearanceInputs[key].value = Number(defaults[key] || 1);
    });
    const outfit = creatorForm.querySelector(
        `input[name="outfit"][value="${CSS.escape(String(defaults.outfit || ''))}"]`
    );
    if (outfit) outfit.checked = true;
    creatorZoom.value = 50;
    updateAppearanceLimits();
};

const queueAppearancePreview = () => {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(async () => {
        try {
            const result = await post('previewAppearance', { appearance: currentAppearance() });
            if (!result.ok) showError(result.error);
        } catch {
            showError('Die Charaktervorschau konnte nicht aktualisiert werden.');
        }
    }, 70);
};

const closeCreator = async () => {
    clearTimeout(previewTimer);
    clearTimeout(zoomTimer);
    creator.classList.add('hidden');
    creationConfirmation.classList.add('hidden');
    creationLoading.classList.add('hidden');
    app.classList.remove('creator-mode');
    pendingCreation = null;
    try {
        await post('cancelCreator');
    } catch {
        // Beim Schließen der Resource kann der Callback bereits entfernt sein.
    }
    resetCreatorForm();
    previewCharacter(characters[0]);
};

const openCreator = async () => {
    if (busy || creatorSettings.enabled === false) {
        if (creatorSettings.enabled === false) showError('Der Charakter-Creator ist deaktiviert.');
        return;
    }
    resetCreatorForm();
    clearTimeout(selectionPreviewTimer);
    selectionPreview.classList.add('hidden');
    creationConfirmation.classList.add('hidden');
    creationLoading.classList.add('hidden');
    pendingCreation = null;
    app.classList.remove('selection-preview-mode');
    creator.classList.remove('hidden');
    app.classList.add('creator-mode');
    void requestFocus(false);
    try {
        const result = await post('beginCreator', { appearance: currentAppearance() });
        if (!result.ok) {
            await closeCreator();
            return showError(result.error);
        }
    } catch {
        await closeCreator();
        return showError('Die Charaktervorschau konnte nicht gestartet werden.');
    }
    focusFirstname();
};

const displayDate = value => {
    if (!value) return 'Kein Geburtsdatum';
    const text = String(value).slice(0, 10);
    const [year, month, day] = text.split('-');
    return year && month && day ? `${day}.${month}.${year}` : text;
};

const previewCharacter = character => {
    clearTimeout(selectionPreviewTimer);
    if (!character) {
        selectionPreview.classList.add('hidden');
        app.classList.remove('selection-preview-mode');
        return;
    }

    app.classList.add('selection-preview-mode');
    selectionPreview.classList.remove('hidden');
    selectionPreviewName.textContent = character.nickname
        ? `${character.firstname} „${character.nickname}“ ${character.lastname}`
        : `${character.firstname} ${character.lastname}`;
    selectionPreviewProfile.textContent = character.description
        || `${character.job || 'unemployed'} · Rang ${character.job_grade || 0}`;

    selectionPreviewTimer = setTimeout(async () => {
        try {
            const result = await post('previewSelectedCharacter', {
                sex: character.sex,
                appearance: character.appearance || {}
            });
            if (!result.ok) {
                selectionPreview.classList.add('hidden');
                app.classList.remove('selection-preview-mode');
            }
        } catch {
            selectionPreview.classList.add('hidden');
            app.classList.remove('selection-preview-mode');
        }
    }, 80);
};

const makeElement = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
};

const selectCharacter = async id => {
    if (busy) return;
    setBusy(true);
    try {
        const result = await post('selectCharacter', { id });
        if (!result.ok) showError(result.error);
    } catch {
        showError('Die Auswahl konnte nicht übertragen werden.');
    } finally {
        setBusy(false);
    }
};

const requestDelete = character => {
    pendingDelete = character;
    confirmationText.textContent =
        `${character.firstname} ${character.lastname} und der gesamte Spielfortschritt werden gelöscht.`;
    confirmation.classList.remove('hidden');
};

const renderCharacters = () => {
    grid.replaceChildren();
    slotCount.textContent = `${characters.length} / ${maxCharacters} Charaktere`;

    characters.forEach((character, index) => {
        const card = makeElement('article', 'character-card');
        card.tabIndex = 0;
        card.setAttribute('role', 'button');
        if (Number(character.id) === Number(activeCharacterId)) card.classList.add('active');
        card.addEventListener('mouseenter', () => previewCharacter(character));
        card.addEventListener('focus', () => previewCharacter(character));
        card.addEventListener('click', () => selectCharacter(character.id));
        card.addEventListener('keydown', event => {
            if (event.key === 'Enter' || event.key === ' ') selectCharacter(character.id);
        });

        card.append(
            makeElement('span', 'card-index', `CHARAKTER ${String(index + 1).padStart(2, '0')}`),
            makeElement(
                'h2',
                'character-name',
                character.nickname
                    ? `${character.firstname} „${character.nickname}“ ${character.lastname}`
                    : `${character.firstname} ${character.lastname}`
            ),
            makeElement(
                'div',
                'character-meta',
                `${character.sex === 'female' ? 'Weiblich' : 'Männlich'} · ${displayDate(character.date_of_birth)}\n${character.job || 'unemployed'} · Rang ${character.job_grade || 0}`
            )
        );

        const money = makeElement('div', 'money');
        money.append(
            makeElement('span', '', `$${Number(character.cash || 0)} Bargeld`),
            makeElement('span', '', `$${Number(character.bank || 0)} Bank`)
        );
        card.append(money);

        if (Number(character.id) !== Number(activeCharacterId)) {
            const remove = makeElement('button', 'delete-character', 'Löschen');
            remove.type = 'button';
            remove.addEventListener('click', event => {
                event.stopPropagation();
                requestDelete(character);
            });
            card.append(remove);
        } else {
            card.append(makeElement('span', 'delete-character', 'Aktiv'));
        }
        grid.append(card);
    });

    if (characters.length < maxCharacters) {
        const createCard = makeElement('button', 'character-card new-card');
        createCard.type = 'button';
        createCard.append(
            makeElement('span', 'plus', '+'),
            makeElement('strong', '', 'Neuer Charakter'),
            makeElement('small', '', 'Eine neue Geschichte beginnen')
        );
        createCard.addEventListener('click', openCreator);
        grid.append(createCard);
    }

    previewCharacter(characters[0]);
};

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'close') {
        clearTimeout(selectionPreviewTimer);
        app.classList.add('hidden');
        app.classList.remove('creator-mode');
        app.classList.remove('selection-preview-mode');
        creator.classList.add('hidden');
        creationConfirmation.classList.add('hidden');
        creationLoading.classList.add('hidden');
        selectionPreview.classList.add('hidden');
        confirmation.classList.add('hidden');
        pendingCreation = null;
        return;
    }

    app.classList.remove('hidden');
    if (data.action === 'loading') {
        loading.classList.remove('hidden');
        grid.classList.add('hidden');
        return;
    }
    if (data.action === 'error') {
        showError(data.message);
        return;
    }
    if (data.action !== 'open') return;

    characters = Array.isArray(data.characters) ? data.characters : [];
    maxCharacters = Number(data.maxCharacters || 3);
    activeCharacterId = data.activeCharacterId || null;
    birthdate.min = data.minBirthDate || '';
    birthdate.max = data.maxBirthDate || '';
    configureCreator(data.creator);
    closeButton.classList.toggle('hidden', !data.canClose);
    renderCharacters();
    loading.classList.add('hidden');
    grid.classList.remove('hidden');
    void requestFocus(true);
});

creatorForm.addEventListener('submit', async event => {
    event.preventDefault();
    if (busy) return;
    const form = new FormData(creatorForm);
    pendingCreation = {
        firstname: String(form.get('firstname') || '').trim(),
        lastname: String(form.get('lastname') || '').trim(),
        nickname: String(form.get('nickname') || '').trim(),
        description: String(form.get('description') || '').trim(),
        dateOfBirth: form.get('dateOfBirth'),
        sex: form.get('sex'),
        appearance: currentAppearance()
    };
    const displayName = pendingCreation.nickname
        ? `${pendingCreation.firstname} „${pendingCreation.nickname}“ ${pendingCreation.lastname}`
        : `${pendingCreation.firstname} ${pendingCreation.lastname}`;
    const sexLabel = pendingCreation.sex === 'female' ? 'Weiblich' : 'Männlich';
    creationSummary.textContent =
        `${displayName} · ${pendingCreation.dateOfBirth || 'Kein Geburtsdatum'} · ${sexLabel}`;
    creationConfirmation.classList.remove('hidden');
    confirmCreation.focus();
});

cancelCreationConfirm.addEventListener('click', () => {
    pendingCreation = null;
    creationConfirmation.classList.add('hidden');
    void requestFocus(false);
    focusFirstname();
});

confirmCreation.addEventListener('click', async () => {
    if (!pendingCreation || busy) return;
    const payload = pendingCreation;
    setBusy(true);
    creationConfirmation.classList.add('hidden');
    creator.classList.add('hidden');
    app.classList.remove('creator-mode');
    creationLoading.classList.remove('hidden');
    try {
        const result = await post('createCharacter', payload);
        if (!result.ok) {
            creationLoading.classList.add('hidden');
            creator.classList.remove('hidden');
            app.classList.add('creator-mode');
            void requestFocus(false);
            showError(result.error);
            return;
        }
        resetCreatorForm();
    } catch {
        creationLoading.classList.add('hidden');
        creator.classList.remove('hidden');
        app.classList.add('creator-mode');
        void requestFocus(false);
        showError('Der Charakter konnte nicht erstellt werden.');
    } finally {
        pendingCreation = null;
        setBusy(false);
    }
});

cancelCreate.addEventListener('click', () => { void closeCreator(); });
cancelDelete.addEventListener('click', () => {
    pendingDelete = null;
    confirmation.classList.add('hidden');
});

confirmDelete.addEventListener('click', async () => {
    if (!pendingDelete || busy) return;
    setBusy(true);
    try {
        const result = await post('deleteCharacter', { id: pendingDelete.id });
        if (!result.ok) return showError(result.error);
        characters = result.characters || [];
        pendingDelete = null;
        confirmation.classList.add('hidden');
        renderCharacters();
    } catch {
        showError('Der Charakter konnte nicht gelöscht werden.');
    } finally {
        setBusy(false);
    }
});

closeButton.addEventListener('click', async () => {
    const result = await post('closeCharacters');
    if (!result.ok) showError(result.error);
});

document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!creationConfirmation.classList.contains('hidden')) {
        pendingCreation = null;
        creationConfirmation.classList.add('hidden');
        void requestFocus(false);
        focusFirstname();
    } else if (!confirmation.classList.contains('hidden')) {
        pendingDelete = null;
        confirmation.classList.add('hidden');
    } else if (!creator.classList.contains('hidden')) {
        if (!busy) void closeCreator();
    } else if (!closeButton.classList.contains('hidden')) {
        closeButton.click();
    }
});

firstname.addEventListener('keydown', event => {
    if (event.key === 'Enter') {
        event.preventDefault();
        lastname.focus();
    }
});

lastname.addEventListener('keydown', event => {
    if (event.key === 'Enter') {
        event.preventDefault();
        nickname.focus();
    }
});

nickname.addEventListener('keydown', event => {
    if (event.key === 'Enter') {
        event.preventDefault();
        birthdate.focus();
    }
});

creatorForm.querySelectorAll('input[name="sex"]').forEach(input => {
    input.addEventListener('change', () => {
        updateAppearanceLimits();
        queueAppearancePreview();
    });
});

appearanceKeys.forEach(key => {
    appearanceInputs[key].addEventListener('input', () => {
        updateRangeLabels();
        queueAppearancePreview();
    });
});

outfitOptions.addEventListener('change', queueAppearancePreview);

rotateLeft.addEventListener('click', async () => {
    try {
        const result = await post('rotateCreator', { direction: -1 });
        if (!result.ok) showError(result.error);
    } catch {
        showError('Die Charaktervorschau konnte nicht gedreht werden.');
    }
});

rotateRight.addEventListener('click', async () => {
    try {
        const result = await post('rotateCreator', { direction: 1 });
        if (!result.ok) showError(result.error);
    } catch {
        showError('Die Charaktervorschau konnte nicht gedreht werden.');
    }
});

creatorZoom.addEventListener('input', () => {
    clearTimeout(zoomTimer);
    zoomTimer = setTimeout(async () => {
        try {
            const result = await post('zoomCreator', { zoom: Number(creatorZoom.value) / 100 });
            if (!result.ok) showError(result.error);
        } catch {
            showError('Der Vorschau-Zoom konnte nicht aktualisiert werden.');
        }
    }, 35);
});

if (new URLSearchParams(window.location.search).has('preview')) {
    window.dispatchEvent(new MessageEvent('message', {
        data: {
            action: 'open',
            maxCharacters: 3,
            activeCharacterId: 1,
            canClose: true,
            minBirthDate: '1800-01-01',
            maxBirthDate: '1905-12-31',
            creator: {
                enabled: true,
                defaults: {
                    sex: 'male',
                    head: 1,
                    body: 1,
                    hair: 1,
                    beard: 1,
                    eyes: 1,
                    height: 2,
                    outfit: 'frontier'
                },
                options: {
                    male: {
                        head: ['Herkunft 01', 'Herkunft 02', 'Herkunft 03'],
                        body: ['Schlank', 'Durchschnittlich', 'Kräftig'],
                        hair: ['Kurz', 'Seitenscheitel', 'Mittellang', 'Lang'],
                        beard: ['Kein Bart', 'Kurzer Bart', 'Vollbart', 'Langer Bart'],
                        eyes: ['Braun', 'Grün', 'Blau', 'Grau'],
                        height: ['Klein', 'Normal', 'Groß']
                    },
                    female: {
                        head: ['Herkunft 01', 'Herkunft 02', 'Herkunft 03'],
                        body: ['Schlank', 'Durchschnittlich', 'Kräftig'],
                        hair: ['Kurz', 'Gebunden', 'Mittellang', 'Lang'],
                        beard: ['Nicht verfügbar'],
                        eyes: ['Braun', 'Grün', 'Blau', 'Grau'],
                        height: ['Klein', 'Normal', 'Groß']
                    }
                },
                profile: { nicknameMaxLength: 32, descriptionMaxLength: 280 },
                outfits: [
                    {
                        key: 'work',
                        label: 'Arbeit',
                        description: 'Schlicht, robust und bereit für den ersten Arbeitstag.'
                    },
                    {
                        key: 'traveler',
                        label: 'Reise',
                        description: 'Ein warmer Mantel für lange Wege durch den Westen.'
                    },
                    {
                        key: 'frontier',
                        label: 'Frontier',
                        description: 'Das vollständige Startoutfit für eine neue Geschichte.'
                    }
                ]
            },
            characters: [
                {
                    id: 1,
                    firstname: 'Arthur',
                    lastname: 'Morgan',
                    nickname: 'Morgan',
                    description: 'Ein erfahrener Revolverheld auf der Suche nach einem neuen Weg.',
                    date_of_birth: '1863-06-22',
                    sex: 'male',
                    appearance: { head: 1, body: 2, hair: 2, beard: 3, eyes: 1, height: 2, outfit: 'frontier' },
                    job: 'sheriff',
                    job_grade: 1,
                    cash: 84,
                    bank: 320
                },
                {
                    id: 2,
                    firstname: 'Sadie',
                    lastname: 'Adler',
                    nickname: '',
                    description: 'Eine entschlossene Reisende aus den Bergen.',
                    date_of_birth: '1874-01-17',
                    sex: 'female',
                    appearance: { head: 2, body: 1, hair: 4, beard: 1, eyes: 3, height: 2, outfit: 'traveler' },
                    job: 'unemployed',
                    job_grade: 0,
                    cash: 42,
                    bank: 175
                }
            ]
        }
    }));
}
