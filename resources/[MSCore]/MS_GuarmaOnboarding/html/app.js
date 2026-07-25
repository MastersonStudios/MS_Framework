const cinematic = document.getElementById('cinematic');
const cinematicTitle = document.getElementById('cinematic-title');
const cinematicText = document.getElementById('cinematic-text');
const tutorial = document.getElementById('tutorial');
const tutorialProgress = document.getElementById('tutorial-progress');
const stepCount = document.getElementById('step-count');
const tutorialTitle = document.getElementById('tutorial-title');
const tutorialText = document.getElementById('tutorial-text');
const tutorialKey = document.getElementById('tutorial-key');
const distance = document.getElementById('distance');
const adminAlert = document.getElementById('admin-alert');
const alertName = document.getElementById('alert-name');
const alertCommand = document.getElementById('alert-command');
const adminMenu = document.getElementById('admin-menu');
const locations = document.getElementById('locations');
const newcomers = document.getElementById('newcomers');
const closeMenu = document.getElementById('close-menu');

let alertTimer;

const post = async (endpoint, body = {}) => {
    const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    });
    return response.json();
};

const element = (tag, className, text) => {
    const item = document.createElement(tag);
    if (className) item.className = className;
    if (text !== undefined) item.textContent = text;
    return item;
};

const renderAdminMenu = data => {
    locations.replaceChildren();
    newcomers.replaceChildren();

    (data.locations || []).forEach(location => {
        const button = element('button', 'location');
        button.type = 'button';
        button.append(element('strong', '', location.label), element('span', '', 'TELEPORT'));
        button.addEventListener('click', async () => {
            button.disabled = true;
            try {
                await post('adminTeleport', { locationId: location.id });
            } finally {
                button.disabled = false;
            }
        });
        locations.append(button);
    });

    const active = data.newcomers || [];
    if (!active.length) {
        newcomers.append(element('div', 'empty', 'Derzeit befindet sich kein neuer Spieler im Tutorial.'));
    } else {
        active.forEach(player => {
            const row = element('div', 'newcomer');
            row.append(
                element('strong', '', player.characterName || player.name),
                element('span', '', `ID ${player.source} · ${player.stage === 'intro' ? 'Intro' : 'Tutorial'}`)
            );
            newcomers.append(row);
        });
    }
};

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'cinematicStart') {
        cinematic.classList.remove('hidden');
    } else if (data.action === 'cinematicCaption') {
        cinematicTitle.textContent = data.title || '';
        cinematicText.textContent = data.text || '';
    } else if (data.action === 'cinematicEnd') {
        cinematic.classList.add('hidden');
    } else if (data.action === 'tutorialStart') {
        tutorialProgress.style.width = '0%';
        tutorial.classList.remove('hidden');
    } else if (data.action === 'tutorialStep') {
        stepCount.textContent = `${data.index} / ${data.total}`;
        tutorialTitle.textContent = data.title || '';
        tutorialText.textContent = data.text || '';
        tutorialKey.textContent = data.key || '';
    } else if (data.action === 'tutorialDistance') {
        distance.textContent = String(data.distance || 0);
    } else if (data.action === 'tutorialProgress') {
        const total = Number(stepCount.textContent.split('/')[1] || 1);
        tutorialProgress.style.width = `${Math.min((Number(data.index) / total) * 100, 100)}%`;
    } else if (data.action === 'tutorialFinishing') {
        tutorialTitle.textContent = 'Am Hafen angekommen';
        tutorialText.textContent = 'Deine Ankunft wird bestätigt …';
        tutorialKey.textContent = '✓';
        distance.textContent = '0';
        tutorialProgress.style.width = '100%';
    } else if (data.action === 'tutorialComplete' || data.action === 'reset') {
        cinematic.classList.add('hidden');
        tutorial.classList.add('hidden');
    } else if (data.action === 'adminAlert') {
        alertName.textContent = `${data.name} (ID ${data.source})`;
        alertCommand.textContent = `Öffne das Teleportmenü mit ${data.command}`;
        adminAlert.classList.remove('hidden');
        clearTimeout(alertTimer);
        alertTimer = setTimeout(() => adminAlert.classList.add('hidden'), 12000);
    } else if (data.action === 'adminMenu') {
        renderAdminMenu(data);
        adminMenu.classList.remove('hidden');
    } else if (data.action === 'adminMenuClose') {
        adminMenu.classList.add('hidden');
    }
});

closeMenu.addEventListener('click', async () => {
    await post('closeAdminMenu');
});

document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !adminMenu.classList.contains('hidden')) closeMenu.click();
});

const previewMode = new URLSearchParams(window.location.search).get('preview');
if (previewMode === 'admin') {
    window.dispatchEvent(new MessageEvent('message', {
        data: {
            action: 'adminMenu',
            locations: [
                { id: 'beach', label: 'Bahia de la Paz – Strand' },
                { id: 'port', label: 'Guarma – Hafen' },
                { id: 'cinco', label: 'Cinco Torres' },
                { id: 'mansion', label: 'Guarma – Anwesen' }
            ],
            newcomers: [
                { source: 12, characterName: 'Elias Mercer', stage: 'tutorial' },
                { source: 27, characterName: 'Clara Bennett', stage: 'intro' }
            ]
        }
    }));
} else if (previewMode === 'cinematic') {
    window.dispatchEvent(new MessageEvent('message', { data: { action: 'cinematicStart' } }));
    window.dispatchEvent(new MessageEvent('message', {
        data: {
            action: 'cinematicCaption',
            title: 'Der Sturm',
            text: 'Der Himmel zerreißt. Das Schiff verliert seinen Kurs.'
        }
    }));
} else if (previewMode === 'tutorial') {
    window.dispatchEvent(new MessageEvent('message', { data: { action: 'tutorialStart' } }));
    window.dispatchEvent(new MessageEvent('message', {
        data: {
            action: 'tutorialStep',
            index: 2,
            total: 5,
            title: 'Zum Palmenpfad',
            text: 'Halte SHIFT gedrückt und sprinte zum nächsten Wegpunkt.',
            key: 'SHIFT'
        }
    }));
    window.dispatchEvent(new MessageEvent('message', {
        data: { action: 'tutorialDistance', distance: 34 }
    }));
}
