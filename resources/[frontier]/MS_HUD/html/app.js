const hud = document.getElementById('hud');
const positions = new Set(['bottom-right', 'bottom-left', 'top-right', 'top-left']);
const orientations = new Set(['horizontal', 'vertical']);
const statusElements = Object.fromEntries(
    [...document.querySelectorAll('[data-status]')].map((element) => [element.dataset.status, element])
);

const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));

function setProgress(name, value, minimum, maximum, display, critical = false) {
    const element = statusElements[name];
    if (!element) return;
    const safeMinimum = Number(minimum) || 0;
    const safeMaximum = Math.max(safeMinimum + 1, Number(maximum) || 100);
    const safeValue = clamp(Number(value) || 0, safeMinimum, safeMaximum);
    const percent = ((safeValue - safeMinimum) / (safeMaximum - safeMinimum)) * 100;
    const track = element.querySelector('.status__track');

    element.querySelector('.status__fill').style.width = `${percent}%`;
    element.querySelector('.status__value').textContent = display;
    element.classList.toggle('is-critical', critical === true);
    track.setAttribute('aria-valuemin', String(safeMinimum));
    track.setAttribute('aria-valuemax', String(safeMaximum));
    track.setAttribute('aria-valuenow', String(Math.round(safeValue)));
}

function configure(config = {}) {
    const position = positions.has(config.position) ? config.position : 'bottom-right';
    const orientation = orientations.has(config.orientation) ? config.orientation : 'horizontal';

    for (const entry of positions) hud.classList.remove(`hud--${entry}`);
    for (const entry of orientations) hud.classList.remove(`hud--${entry}`);
    hud.classList.add(`hud--${position}`, `hud--${orientation}`);
    hud.classList.toggle('hide-labels', config.showLabels === false);
    hud.classList.toggle('hide-values', config.showValues === false);

    document.documentElement.style.setProperty(
        '--hud-offset-x',
        `${clamp(Number(config.offsetX) || 0, 0, 500)}px`
    );
    document.documentElement.style.setProperty(
        '--hud-offset-y',
        `${clamp(Number(config.offsetY) || 0, 0, 500)}px`
    );
    document.documentElement.style.setProperty(
        '--hud-scale',
        String(clamp(Number(config.scale) || 1, 0.5, 2))
    );

    for (const [name, label] of Object.entries(config.labels || {})) {
        const element = statusElements[name];
        if (element && typeof label === 'string') {
            element.querySelector('.status__label').textContent = label;
        }
    }
}

function update(status = {}) {
    const health = status.health || {};
    const needs = status.needs || {};
    const temperature = status.temperature || {};
    const healthPercent = clamp(Number(health.percent) || 0, 0, 100);
    const needRange = Math.max(1, (Number(needs.maximum) || 100) - (Number(needs.minimum) || 0));
    const hungerPercent = ((Number(needs.hunger) || 0) - (Number(needs.minimum) || 0)) / needRange * 100;
    const thirstPercent = ((Number(needs.thirst) || 0) - (Number(needs.minimum) || 0)) / needRange * 100;

    setProgress(
        'health',
        healthPercent,
        0,
        100,
        `${Math.round(healthPercent)}%`,
        healthPercent <= (Number(health.criticalThreshold) || 25)
    );
    setProgress(
        'hunger',
        hungerPercent,
        0,
        100,
        `${Math.round(clamp(hungerPercent, 0, 100))}%`,
        Number(needs.hunger) <= Number(needs.criticalThreshold)
    );
    setProgress(
        'thirst',
        thirstPercent,
        0,
        100,
        `${Math.round(clamp(thirstPercent, 0, 100))}%`,
        Number(needs.thirst) <= Number(needs.criticalThreshold)
    );
    setProgress(
        'temperature',
        temperature.value,
        temperature.minimum,
        temperature.maximum,
        `${Number(temperature.value || 0).toFixed(1)} ${temperature.unit || '°C'}`
    );

    const temperatureElement = statusElements.temperature;
    temperatureElement.classList.toggle('is-cold', temperature.cold === true);
    temperatureElement.classList.toggle('is-hot', temperature.hot === true);
}

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'configure') return configure(data.config);
    if (data.action === 'visibility') {
        hud.classList.toggle('is-visible', data.visible === true);
        return;
    }
    if (data.action === 'reset') {
        hud.classList.remove('is-visible');
        return;
    }
    if (data.action === 'update') update(data.status);
});
