(() => {
    'use strict';

    const defaults = {
        brand: 'MASTERSON STUDIOS',
        serverName: 'MS FRAMEWORK · REDM',
        eyebrow: 'EINE MASTERSON STUDIOS PRODUKTION',
        title: 'RING DANG DOO',
        subtitle: 'Die Grenze wartet auf dich.',
        video: {
            src: 'media/ring_dang_doo.mp4',
            autoplay: true,
            loop: true,
            startMuted: false,
            volume: 0.75
        },
        tips: ['Willkommen an der Grenze.'],
        tipIntervalMs: 6500
    };

    const supplied = window.MS_LOADING_CONFIG || {};
    const config = {
        ...defaults,
        ...supplied,
        video: { ...defaults.video, ...(supplied.video || {}) }
    };

    const elements = {
        video: document.querySelector('#cutscene'),
        brand: document.querySelector('#brandName'),
        serverName: document.querySelector('#serverName'),
        eyebrow: document.querySelector('#eyebrow'),
        title: document.querySelector('#sceneTitle'),
        subtitle: document.querySelector('#sceneSubtitle'),
        soundToggle: document.querySelector('#soundToggle'),
        soundLabel: document.querySelector('#soundLabel'),
        playButton: document.querySelector('#playButton'),
        mediaNotice: document.querySelector('#mediaNotice'),
        tipText: document.querySelector('#tipText'),
        loadingStatus: document.querySelector('#loadingStatus'),
        progressPercent: document.querySelector('#progressPercent'),
        progressTrack: document.querySelector('#progressTrack'),
        progressFill: document.querySelector('#progressFill')
    };

    let muted = Boolean(config.video.startMuted);
    let videoReady = false;
    let videoFailed = false;
    let tipIndex = 0;
    let renderedProgress = 0;

    function clamp(value, minimum, maximum) {
        return Math.min(Math.max(Number(value) || 0, minimum), maximum);
    }

    function applyCopy() {
        elements.brand.textContent = config.brand;
        elements.serverName.textContent = config.serverName;
        elements.eyebrow.textContent = config.eyebrow;
        elements.title.textContent = config.title;
        elements.subtitle.textContent = config.subtitle;

        if (Array.isArray(config.tips) && config.tips.length > 0) {
            elements.tipText.textContent = String(config.tips[0]);
        }
    }

    function updateSoundControl() {
        elements.video.muted = muted;
        elements.video.volume = clamp(config.video.volume, 0, 1);
        elements.soundToggle.dataset.muted = muted ? 'true' : 'false';
        elements.soundToggle.setAttribute('aria-pressed', String(muted));
        elements.soundToggle.setAttribute(
            'aria-label',
            muted ? 'Ton einschalten' : 'Ton stummschalten'
        );
        elements.soundLabel.textContent = muted ? 'Ton aus' : 'Ton an';
    }

    async function startVideo() {
        if (!config.video.src) {
            showFallback();
            return;
        }

        try {
            await elements.video.play();
            elements.playButton.hidden = true;
        } catch (error) {
            if (videoFailed) {
                return;
            }

            if (!muted) {
                muted = true;
                updateSoundControl();

                try {
                    await elements.video.play();
                    elements.playButton.textContent = 'Ton einschalten';
                    elements.playButton.hidden = false;
                    return;
                } catch (mutedError) {
                    // Der sichtbare Startknopf behandelt restriktive Autoplay-Regeln.
                }
            }

            if (videoFailed) {
                return;
            }

            elements.playButton.textContent = 'Video und Ton starten';
            elements.playButton.hidden = false;
        }
    }

    function showVideo() {
        videoFailed = false;
        videoReady = true;
        document.body.classList.add('has-video');
        document.body.classList.remove('video-unavailable');
        elements.mediaNotice.hidden = true;
    }

    function showFallback() {
        videoFailed = true;
        videoReady = false;
        document.body.classList.remove('has-video');
        document.body.classList.add('video-unavailable');
        elements.mediaNotice.hidden = false;
        elements.playButton.hidden = true;
    }

    function configureVideo() {
        videoFailed = false;
        elements.video.loop = Boolean(config.video.loop);
        elements.video.autoplay = Boolean(config.video.autoplay);
        updateSoundControl();

        if (!config.video.src) {
            showFallback();
            return;
        }

        elements.video.addEventListener('loadeddata', showVideo, { once: true });
        elements.video.addEventListener('canplay', showVideo);
        elements.video.addEventListener('error', showFallback, { once: true });
        elements.video.src = String(config.video.src);
        elements.video.load();

        if (config.video.autoplay) {
            startVideo();
        } else {
            elements.playButton.hidden = false;
        }
    }

    function toggleSound() {
        muted = !muted;
        updateSoundControl();

        if (videoReady && elements.video.paused) {
            startVideo();
        }
    }

    function renderProgress(fraction) {
        const safeFraction = clamp(fraction, 0, 1);
        renderedProgress = Math.max(renderedProgress, safeFraction);
        const percent = Math.round(renderedProgress * 100);

        elements.progressFill.style.width = `${percent}%`;
        elements.progressPercent.textContent = `${percent}%`;
        elements.progressTrack.setAttribute('aria-valuenow', String(percent));
    }

    function setStatus(text) {
        if (typeof text === 'string' && text.trim()) {
            elements.loadingStatus.textContent = text;
        }
    }

    function handleLoadingEvent(payload) {
        if (!payload || typeof payload.eventName !== 'string') {
            return;
        }

        switch (payload.eventName) {
            case 'loadProgress':
                renderProgress(payload.loadFraction);
                setStatus(
                    Number(payload.loadFraction) >= 0.99
                        ? 'Fast geschafft'
                        : 'Spielwelt wird geladen'
                );
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
    }

    function rotateTips() {
        if (!Array.isArray(config.tips) || config.tips.length < 2) {
            return;
        }

        tipIndex = (tipIndex + 1) % config.tips.length;
        elements.tipText.classList.add('is-changing');

        window.setTimeout(() => {
            elements.tipText.textContent = String(config.tips[tipIndex]);
            elements.tipText.classList.remove('is-changing');
        }, 220);
    }

    elements.soundToggle.addEventListener('click', toggleSound);
    elements.playButton.addEventListener('click', () => {
        muted = false;
        updateSoundControl();
        startVideo();
    });

    window.addEventListener('keydown', (event) => {
        if (event.key.toLowerCase() === 'm' && !event.repeat) {
            toggleSound();
        }
    });

    window.addEventListener('message', (event) => {
        handleLoadingEvent(event.data);
    });

    applyCopy();
    configureVideo();
    renderProgress(0);
    window.setInterval(rotateTips, Math.max(Number(config.tipIntervalMs) || 6500, 2500));
})();
