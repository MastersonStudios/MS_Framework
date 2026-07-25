const root = document.getElementById('needs');
const allowedPositions = new Set(['bottom-right', 'bottom-left', 'top-right', 'top-left']);

const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));

function setNeed(name, rawValue, minimum, maximum, criticalThreshold) {
    const element = root.querySelector(`[data-need="${name}"]`);
    if (!element) return;

    const value = clamp(Number(rawValue) || minimum, minimum, maximum);
    const range = Math.max(1, maximum - minimum);
    const percent = clamp(((value - minimum) / range) * 100, 0, 100);
    const rounded = Math.round(percent);
    const track = element.querySelector('.need__track');

    element.querySelector('.need__fill').style.width = `${percent}%`;
    element.querySelector('.need__value').textContent = `${rounded}%`;
    element.classList.toggle('is-critical', value <= criticalThreshold);
    track.setAttribute('aria-valuemin', String(minimum));
    track.setAttribute('aria-valuemax', String(maximum));
    track.setAttribute('aria-valuenow', String(Math.round(value)));
}

function configure(config = {}) {
    const position = allowedPositions.has(config.position) ? config.position : 'bottom-right';
    root.classList.remove(...[...allowedPositions].map((entry) => `needs--${entry}`));
    root.classList.add(`needs--${position}`);
    root.classList.toggle('hide-labels', config.showLabels === false);
    root.classList.toggle('hide-values', config.showValues === false);

    const offsetX = clamp(Number(config.offsetX) || 0, 0, 500);
    const offsetY = clamp(Number(config.offsetY) || 0, 0, 500);
    const scale = clamp(Number(config.scale) || 1, 0.5, 2);
    document.documentElement.style.setProperty('--offset-x', `${offsetX}px`);
    document.documentElement.style.setProperty('--offset-y', `${offsetY}px`);
    document.documentElement.style.setProperty('--hud-scale', String(scale));
}

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;

    if (data.action === 'configure') {
        configure(data.config);
        return;
    }

    if (data.action === 'visibility') {
        root.classList.toggle('is-visible', data.visible === true);
        return;
    }

    if (data.action === 'reset') {
        root.classList.remove('is-visible');
        setNeed('hunger', 100, 0, 100, 20);
        setNeed('thirst', 100, 0, 100, 20);
        return;
    }

    if (data.action === 'update' && data.needs) {
        const minimum = Number(data.needs.minimum) || 0;
        const maximum = Number(data.needs.maximum) || 100;
        const critical = Number(data.needs.criticalThreshold) || 20;
        setNeed('hunger', data.needs.hunger, minimum, maximum, critical);
        setNeed('thirst', data.needs.thirst, minimum, maximum, critical);
    }
});
