const finale = document.getElementById('finale');
const title = document.getElementById('finale-title');
const subtitle = document.getElementById('finale-subtitle');
const characterName = document.getElementById('character-name');
const caption = document.getElementById('caption');
const thresholdLine = document.getElementById('threshold-line');
const riskToast = document.getElementById('risk-toast');
const riskValue = document.getElementById('risk-value');
const riskIncrease = document.getElementById('risk-increase');

let toastTimer = null;

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'risk') {
        riskValue.textContent = `${Number(data.risk) || 0} %`;
        riskIncrease.textContent = `+${Number(data.increase) || 0} %`;
        riskToast.classList.add('visible');
        window.clearTimeout(toastTimer);
        toastTimer = window.setTimeout(() => riskToast.classList.remove('visible'), 6500);
        return;
    }

    if (data.action === 'finaleStart') {
        title.textContent = data.title || 'Das Ende eines Weges';
        subtitle.textContent = data.subtitle || '';
        characterName.textContent = data.characterName || '';
        caption.textContent = '';
        thresholdLine.textContent =
            `TODESRISIKO ${Number(data.risk) || 0} % · SCHWELLWERT ${Number(data.threshold) || 60} %`;
        finale.classList.toggle('test', data.test === true);
        finale.classList.add('visible');
        finale.setAttribute('aria-hidden', 'false');
        riskToast.classList.remove('visible');
        return;
    }

    if (data.action === 'caption') {
        caption.textContent = data.text || '';
        return;
    }

    if (data.action === 'finaleEnd') {
        finale.classList.remove('visible', 'test');
        finale.setAttribute('aria-hidden', 'true');
        caption.textContent = '';
    }
});
