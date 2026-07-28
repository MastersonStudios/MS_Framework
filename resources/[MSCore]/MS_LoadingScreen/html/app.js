(() => {
    'use strict';

    const defaults = {
        brand: 'MASTERSON STUDIOS',
        serverName: 'MSCORE · REDM',
        eyebrow: 'WILLKOMMEN IM WESTEN',
        title: 'Deine Geschichte wartet.',
        subtitle: 'Die Verbindung zum Server wird vorbereitet.',
        tips: ['Nach der Charaktererstellung startest du am Bahnhof von Valentine.'],
        tipIntervalMs: 6000
    };
    const config = { ...defaults, ...(window.MS_LOADING_CONFIG || {}) };
    const elements = {
        brand: document.querySelector('#brandName'),
        serverName: document.querySelector('#serverName'),
        eyebrow: document.querySelector('#eyebrow'),
        title: document.querySelector('#screenTitle'),
        subtitle: document.querySelector('#screenSubtitle'),
        tip: document.querySelector('#tipText'),
        status: document.querySelector('#loadingStatus'),
        percent: document.querySelector('#progressPercent'),
        track: document.querySelector('#progressTrack'),
        fill: document.querySelector('#progressFill')
    };

    let renderedProgress = 0;
    let tipIndex = 0;

    const clamp = value => Math.min(Math.max(Number(value) || 0, 0), 1);

    const renderProgress = fraction => {
        renderedProgress = Math.max(renderedProgress, clamp(fraction));
        const percent = Math.round(renderedProgress * 100);
        elements.fill.style.width = `${percent}%`;
        elements.percent.textContent = `${percent}%`;
        elements.track.setAttribute('aria-valuenow', String(percent));
    };

    const setStatus = value => {
        if (typeof value === 'string' && value.trim()) {
            elements.status.textContent = value;
        }
    };

    const handleLoadingEvent = payload => {
        if (!payload || typeof payload.eventName !== 'string') return;
        switch (payload.eventName) {
            case 'loadProgress':
                renderProgress(payload.loadFraction);
                setStatus(Number(payload.loadFraction) >= 0.99
                    ? 'Charakterauswahl wird geöffnet'
                    : 'Spielwelt wird geladen');
                break;
            case 'startInitFunction':
            case 'startInitFunctionOrder':
                setStatus('Ressourcen werden vorbereitet');
                break;
            case 'initFunctionInvoking':
                setStatus('Ressourcen werden gestartet');
                break;
            case 'startDataFileEntries':
                setStatus('Spieldaten werden eingelesen');
                break;
            case 'performMapLoadFunction':
                setStatus('Karte wird aufgebaut');
                break;
            default:
                break;
        }
    };

    const rotateTip = () => {
        if (!Array.isArray(config.tips) || config.tips.length < 2) return;
        tipIndex = (tipIndex + 1) % config.tips.length;
        elements.tip.classList.add('changing');
        window.setTimeout(() => {
            elements.tip.textContent = String(config.tips[tipIndex]);
            elements.tip.classList.remove('changing');
        }, 180);
    };

    elements.brand.textContent = config.brand;
    elements.serverName.textContent = config.serverName;
    elements.eyebrow.textContent = config.eyebrow;
    elements.title.textContent = config.title;
    elements.subtitle.textContent = config.subtitle;
    elements.tip.textContent = Array.isArray(config.tips) && config.tips.length
        ? String(config.tips[0])
        : defaults.tips[0];

    window.addEventListener('message', event => handleLoadingEvent(event.data));
    renderProgress(0);
    window.setInterval(rotateTip, Math.max(Number(config.tipIntervalMs) || 6000, 2500));
})();
