const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'MS_Trains';

const app = document.getElementById('app');
const prompt = document.getElementById('prompt');
const promptKey = document.getElementById('prompt-key');
const promptLabel = document.getElementById('prompt-label');
const drivingHud = document.getElementById('driving-hud');
const stationLabel = document.getElementById('station-label');
const stationRegion = document.getElementById('station-region');
const activeCount = document.getElementById('active-count');
const activeLimit = document.getElementById('active-limit');
const catalogCount = document.getElementById('catalog-count');
const trainList = document.getElementById('train-list');
const noActive = document.getElementById('no-active');
const activeTrain = document.getElementById('active-train');
const activeTrainLabel = document.getElementById('active-train-label');
const activeStationLabel = document.getElementById('active-station-label');
const returnCommand = document.getElementById('return-command');
const toast = document.getElementById('toast');

let menuData = null;
let reverseDirection = false;
let busy = false;
let toastTimer = null;

const fallbackData = {
    station: {
        id: 'valentine',
        label: 'Valentine Bahnhof',
        region: 'The Heartlands',
        defaultDirection: false
    },
    trains: [
        {
            id: 'passenger',
            label: 'Personenzug',
            description: 'Klassischer Reisezug mit mehreren Personenwagen.',
            maxSpeed: 18
        },
        {
            id: 'pacific_union',
            label: 'Pacific Union',
            description: 'Grüner Langstrecken-Personenzug der Pacific Union.',
            maxSpeed: 16
        },
        {
            id: 'industry',
            label: 'Industriezug',
            description: 'Schwerer Zug für Güter- und Arbeitseinsätze.',
            maxSpeed: 13
        }
    ],
    active: null,
    settings: {
        returnCommand: 'trainreturn',
        maxActiveTrains: 8,
        activeTrains: 2
    }
};

async function post(action, data = {}) {
    if (typeof GetParentResourceName !== 'function') return { ok: true };
    try {
        const response = await fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (_) {
        return { ok: false };
    }
}

function showToast(message, success = true) {
    clearTimeout(toastTimer);
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.classList.toggle('is-error', !success);
    toast.classList.add('is-visible');
    toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 3400);
}

function currentDirection() {
    const configured = menuData?.station?.defaultDirection === true;
    return reverseDirection ? !configured : configured;
}

function setBusy(value) {
    busy = value === true;
    trainList.querySelectorAll('button').forEach((button) => {
        button.disabled = busy || Boolean(menuData?.active);
    });
}

function createTrainCard(train) {
    const card = document.createElement('article');
    card.className = 'train-card';

    const icon = document.createElement('span');
    icon.className = 'train-card__icon';
    icon.textContent = 'M';

    const copy = document.createElement('div');
    copy.className = 'train-card__copy';
    const heading = document.createElement('h3');
    heading.textContent = train.label;
    const description = document.createElement('p');
    description.textContent = train.description;
    const speed = document.createElement('small');
    speed.textContent = `Höchstgeschwindigkeit ${Math.round(Number(train.maxSpeed) * 3.6)} km/h`;
    copy.append(heading, description, speed);

    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = menuData?.active ? 'Zug bereits aktiv' : 'Bereitstellen';
    button.disabled = busy || Boolean(menuData?.active);
    button.addEventListener('click', async () => {
        if (busy || menuData?.active) return;
        setBusy(true);
        const response = await post('spawn', {
            trainId: train.id,
            direction: currentDirection()
        });
        if (!response?.ok) {
            setBusy(false);
            showToast('Die Anfrage konnte nicht gesendet werden.', false);
        }
    });

    card.append(icon, copy, button);
    return card;
}

function renderDirection() {
    document.querySelectorAll('[data-direction]').forEach((button) => {
        const selected = reverseDirection
            ? button.dataset.direction === 'reverse'
            : button.dataset.direction === 'default';
        button.classList.toggle('is-active', selected);
    });
}

function render() {
    const settings = menuData?.settings ?? {};
    stationLabel.textContent = menuData?.station?.label ?? 'Bahnhof';
    stationRegion.textContent = menuData?.station?.region ?? 'Unbekannte Region';
    activeCount.textContent = String(Number(settings.activeTrains ?? 0));
    activeLimit.textContent = String(Number(settings.maxActiveTrains ?? 0));

    const trains = Array.isArray(menuData?.trains) ? menuData.trains : [];
    catalogCount.textContent = `${trains.length} ${trains.length === 1 ? 'Modell' : 'Modelle'}`;
    trainList.replaceChildren(...trains.map(createTrainCard));

    const active = menuData?.active;
    noActive.hidden = Boolean(active);
    activeTrain.hidden = !active;
    if (active) {
        activeTrainLabel.textContent = active.trainLabel;
        activeStationLabel.textContent = `Bereitgestellt in ${active.stationLabel}`;
    }
    returnCommand.textContent = `/${settings.returnCommand ?? 'trainreturn'}`;
    renderDirection();
}

function open(data) {
    menuData = data && typeof data === 'object' ? data : fallbackData;
    reverseDirection = false;
    busy = false;
    app.classList.add('is-open');
    app.setAttribute('aria-hidden', 'false');
    prompt.classList.remove('is-visible');
    render();
}

function close() {
    app.classList.remove('is-open');
    app.setAttribute('aria-hidden', 'true');
    menuData = null;
    busy = false;
}

document.querySelectorAll('[data-direction]').forEach((button) => {
    button.addEventListener('click', () => {
        reverseDirection = button.dataset.direction === 'reverse';
        renderDirection();
    });
});

document.getElementById('close-button').addEventListener('click', () => post('close'));
document.getElementById('return-button').addEventListener('click', () => post('returnTrain'));

window.addEventListener('message', (event) => {
    const message = event.data ?? {};
    if (message.action === 'open') {
        open(message.data);
    } else if (message.action === 'close') {
        close();
    } else if (message.action === 'result') {
        setBusy(false);
        showToast(message.message, message.success === true);
    } else if (message.action === 'prompt') {
        promptKey.textContent = message.key || 'E';
        promptLabel.textContent = message.label || 'Bahnhof';
        prompt.classList.toggle('is-visible', message.visible === true);
        prompt.setAttribute('aria-hidden', message.visible === true ? 'false' : 'true');
    } else if (message.action === 'driving') {
        drivingHud.classList.toggle('is-visible', message.visible === true);
        drivingHud.setAttribute('aria-hidden', message.visible === true ? 'false' : 'true');
        if (message.visible === true) {
            document.getElementById('hud-train').textContent = message.train || 'Zug';
            document.getElementById('hud-direction').textContent = message.direction || 'Vorwärts';
            document.getElementById('hud-speed').textContent = String(Number(message.speed ?? 0));
            document.getElementById('hud-state').textContent = message.driver
                ? 'Du führst den Zug'
                : 'Zug angehalten – steige am Führerstand ein';
            const ratio = Math.max(0, Math.min(
                100,
                (Number(message.speed ?? 0) / Math.max(1, Number(message.maxSpeed ?? 1))) * 100
            ));
            document.getElementById('hud-speed-bar').style.width = `${ratio}%`;
        }
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && app.classList.contains('is-open')) post('close');
});

if (typeof GetParentResourceName !== 'function') open(fallbackData);
