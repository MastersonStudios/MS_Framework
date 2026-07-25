const jail = document.getElementById('jail');
const time = document.getElementById('time');
const reason = document.getElementById('reason');
const positions = new Set(['top-center', 'top-left', 'top-right']);

function formatTime(rawSeconds) {
    const seconds = Math.max(0, Math.floor(Number(rawSeconds) || 0));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainder = seconds % 60;
    return hours > 0
        ? `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`
        : `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`;
}

function configure(config = {}) {
    const position = positions.has(config.position) ? config.position : 'top-center';
    for (const entry of positions) jail.classList.remove(`jail--${entry}`);
    jail.classList.add(`jail--${position}`);

    const offsetY = Math.max(0, Math.min(500, Number(config.offsetY) || 0));
    const scale = Math.max(0.5, Math.min(2, Number(config.scale) || 1));
    document.documentElement.style.setProperty('--offset-y', `${offsetY}px`);
    document.documentElement.style.setProperty('--jail-scale', String(scale));
}

function applyState(state = {}) {
    time.textContent = formatTime(state.remainingSeconds);
    reason.textContent = String(state.reason || 'Keine Begründung angegeben.');
}

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    if (data.action === 'configure') return configure(data.config);
    if (data.action === 'visibility') {
        jail.classList.toggle('is-visible', data.visible === true);
        return;
    }
    if (data.action === 'jailed') return applyState(data.state);
    if (data.action === 'tick') {
        time.textContent = formatTime(data.remainingSeconds);
        return;
    }
    if (data.action === 'reset') {
        jail.classList.remove('is-visible');
        time.textContent = '00:00';
        reason.textContent = 'Keine Begründung angegeben.';
    }
});
