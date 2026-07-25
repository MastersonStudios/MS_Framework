const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'MS_Telegrams';

const app = document.getElementById('app');
const prompt = document.getElementById('prompt');
const promptKey = document.getElementById('prompt-key');
const promptLabel = document.getElementById('prompt-label');
const stationLabel = document.getElementById('station-label');
const accountNumber = document.getElementById('account-number');
const accountName = document.getElementById('account-name');
const accountBalance = document.getElementById('account-balance');
const sendPrice = document.getElementById('send-price');
const unreadBadge = document.getElementById('unread-badge');
const mailboxView = document.getElementById('mailbox-view');
const composeView = document.getElementById('compose-view');
const folderTitle = document.getElementById('folder-title');
const messageCount = document.getElementById('message-count');
const messageList = document.getElementById('message-list');
const emptyDetail = document.getElementById('empty-detail');
const detailContent = document.getElementById('detail-content');
const detailDirection = document.getElementById('detail-direction');
const detailName = document.getElementById('detail-name');
const detailNumber = document.getElementById('detail-number');
const detailDate = document.getElementById('detail-date');
const detailSubject = document.getElementById('detail-subject');
const detailBody = document.getElementById('detail-body');
const deleteButton = document.getElementById('delete-button');
const composeForm = document.getElementById('compose-form');
const recipientNumber = document.getElementById('recipient-number');
const subject = document.getElementById('subject');
const body = document.getElementById('body');
const numberHint = document.getElementById('number-hint');
const subjectCount = document.getElementById('subject-count');
const bodyCount = document.getElementById('body-count');
const composeCost = document.getElementById('compose-cost');
const sendButton = document.getElementById('send-button');
const toast = document.getElementById('toast');

let telegramData = null;
let activeFolder = 'inbox';
let selectedMessageId = null;
let toastTimer = null;
let sending = false;

const fallbackData = {
    station: { id: 'valentine', label: 'Valentine Telegrafenamt' },
    account: {
        number: '314159',
        name: 'Arthur Morgan',
        balance: 48,
        moneyAccount: 'cash'
    },
    inbox: [
        {
            id: 1,
            senderNumber: '271828',
            senderName: 'Mary Linton',
            recipientNumber: '314159',
            recipientName: 'Arthur Morgan',
            subject: 'Treffen am Bahnhof',
            body: 'Komm morgen bei Sonnenuntergang zum Bahnhof. Ich muss mit dir sprechen.',
            sentAt: '2026-07-25 17:42:00',
            readAt: null,
            unread: true
        }
    ],
    sent: [],
    unread: 1,
    settings: {
        sendCost: 1,
        currency: '$',
        numberDigits: 6,
        maxSubjectLength: 64,
        maxBodyLength: 1200
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

function money(value) {
    const currency = telegramData?.settings?.currency ?? '$';
    return `${currency}${Number(value ?? 0).toLocaleString('de-DE')}`;
}

function dateTime(value) {
    if (!value) return 'Unbekannt';
    const normalized = typeof value === 'string' ? value.replace(' ', 'T') : value;
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat('de-DE', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(date);
}

function shortDate(value) {
    if (!value) return '';
    const normalized = typeof value === 'string' ? value.replace(' ', 'T') : value;
    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat('de-DE', {
        day: '2-digit',
        month: '2-digit'
    }).format(date);
}

function showToast(message, success = true) {
    clearTimeout(toastTimer);
    toast.textContent = message || 'Aktion verarbeitet.';
    toast.classList.toggle('is-error', !success);
    toast.classList.add('is-visible');
    toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 3400);
}

function currentMessages() {
    if (!telegramData || activeFolder === 'compose') return [];
    return Array.isArray(telegramData[activeFolder]) ? telegramData[activeFolder] : [];
}

function selectedMessage() {
    return currentMessages().find((message) => Number(message.id) === Number(selectedMessageId));
}

function renderHeader() {
    const settings = telegramData?.settings ?? {};
    stationLabel.textContent = telegramData?.station?.label ?? 'Telegrafenamt';
    accountNumber.textContent = telegramData?.account?.number ?? '------';
    accountName.textContent = telegramData?.account?.name ?? 'Unbekannt';
    accountBalance.textContent = money(telegramData?.account?.balance);
    unreadBadge.textContent = String(Number(telegramData?.unread ?? 0));
    unreadBadge.hidden = Number(telegramData?.unread ?? 0) < 1;
    sendPrice.textContent = `Versand: ${money(settings.sendCost)}`;
    composeCost.textContent = `Versandgebühr: ${money(settings.sendCost)}`;
    numberHint.textContent = `Genau ${settings.numberDigits ?? 6} Ziffern`;
    recipientNumber.maxLength = Number(settings.numberDigits ?? 6);
    subject.maxLength = Number(settings.maxSubjectLength ?? 64);
    body.maxLength = Number(settings.maxBodyLength ?? 1200);
    updateCounters();
}

function createEmptyList() {
    const empty = document.createElement('div');
    empty.className = 'empty-state';

    const symbol = document.createElement('span');
    symbol.className = 'empty-state__wire';
    symbol.textContent = '⌁';

    const heading = document.createElement('h3');
    heading.textContent = activeFolder === 'inbox'
        ? 'Keine Telegramme eingegangen'
        : 'Noch nichts versendet';

    const copy = document.createElement('p');
    copy.textContent = activeFolder === 'inbox'
        ? 'Neue Nachrichten erscheinen automatisch in diesem Register.'
        : 'Verfasste Telegramme werden hier protokolliert.';

    empty.append(symbol, heading, copy);
    return empty;
}

function renderList() {
    const messages = currentMessages();
    folderTitle.textContent = activeFolder === 'inbox' ? 'Posteingang' : 'Gesendet';
    messageCount.textContent = `${messages.length} ${messages.length === 1 ? 'Eintrag' : 'Einträge'}`;
    messageList.replaceChildren();

    if (!messages.length) {
        selectedMessageId = null;
        messageList.append(createEmptyList());
        renderDetail();
        return;
    }

    if (!messages.some((message) => Number(message.id) === Number(selectedMessageId))) {
        selectedMessageId = Number(messages[0].id);
    }

    messages.forEach((message) => {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'message-card';
        card.classList.toggle('is-unread', activeFolder === 'inbox' && Boolean(message.unread));
        card.classList.toggle('is-selected', Number(message.id) === Number(selectedMessageId));
        card.dataset.messageId = String(message.id);

        const marker = document.createElement('span');
        marker.className = 'message-card__marker';

        const copy = document.createElement('span');
        copy.className = 'message-card__copy';
        const person = document.createElement('strong');
        person.textContent = activeFolder === 'inbox'
            ? message.senderName
            : message.recipientName;
        const headline = document.createElement('span');
        headline.textContent = message.subject;
        copy.append(person, headline);

        const date = document.createElement('time');
        date.textContent = shortDate(message.sentAt);
        card.append(marker, copy, date);
        card.addEventListener('click', () => selectMessage(message.id));
        messageList.append(card);
    });
    renderDetail();
}

function renderDetail() {
    const message = selectedMessage();
    emptyDetail.hidden = Boolean(message);
    detailContent.hidden = !message;
    if (!message) return;

    const inbox = activeFolder === 'inbox';
    detailDirection.textContent = inbox ? 'Empfangen von' : 'Gesendet an';
    detailName.textContent = inbox ? message.senderName : message.recipientName;
    detailNumber.textContent = `Telegrammnummer ${inbox ? message.senderNumber : message.recipientNumber}`;
    detailDate.textContent = dateTime(message.sentAt);
    detailSubject.textContent = message.subject;
    detailBody.textContent = message.body;
}

function renderNavigation() {
    document.querySelectorAll('[data-folder]').forEach((button) => {
        button.classList.toggle('is-active', button.dataset.folder === activeFolder);
    });
    const composing = activeFolder === 'compose';
    mailboxView.hidden = composing;
    composeView.hidden = !composing;
}

function render() {
    renderHeader();
    renderNavigation();
    if (activeFolder !== 'compose') renderList();
}

function selectFolder(folder) {
    if (!['inbox', 'sent', 'compose'].includes(folder)) return;
    activeFolder = folder;
    selectedMessageId = null;
    render();
    if (folder === 'compose') recipientNumber.focus();
}

function selectMessage(messageId) {
    selectedMessageId = Number(messageId);
    const message = selectedMessage();
    if (activeFolder === 'inbox' && message?.unread) {
        message.unread = false;
        telegramData.unread = Math.max(0, Number(telegramData.unread ?? 0) - 1);
        post('read', { messageId: Number(message.id) });
    }
    renderHeader();
    renderList();
}

function updateCounters() {
    const subjectLimit = Number(telegramData?.settings?.maxSubjectLength ?? 64);
    const bodyLimit = Number(telegramData?.settings?.maxBodyLength ?? 1200);
    subjectCount.textContent = `${subject.value.length} / ${subjectLimit}`;
    bodyCount.textContent = `${body.value.length} / ${bodyLimit}`;
}

function open(data) {
    telegramData = data && typeof data === 'object' ? data : fallbackData;
    activeFolder = 'inbox';
    selectedMessageId = null;
    sending = false;
    sendButton.disabled = false;
    app.classList.add('is-open');
    app.setAttribute('aria-hidden', 'false');
    prompt.classList.remove('is-visible');
    render();
}

function close() {
    app.classList.remove('is-open');
    app.setAttribute('aria-hidden', 'true');
    telegramData = null;
    selectedMessageId = null;
    composeForm.reset();
    updateCounters();
}

document.querySelectorAll('[data-folder]').forEach((button) => {
    button.addEventListener('click', () => selectFolder(button.dataset.folder));
});

document.getElementById('close-button').addEventListener('click', () => post('close'));
document.getElementById('refresh-button').addEventListener('click', () => post('refresh'));

deleteButton.addEventListener('click', () => {
    const message = selectedMessage();
    if (!message) return;
    post('delete', { messageId: Number(message.id), folder: activeFolder });
});

recipientNumber.addEventListener('input', () => {
    recipientNumber.value = recipientNumber.value.replace(/\D/g, '');
});
subject.addEventListener('input', updateCounters);
body.addEventListener('input', updateCounters);

composeForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!telegramData || sending) return;

    const digits = Number(telegramData.settings?.numberDigits ?? 6);
    if (recipientNumber.value.length !== digits) {
        return showToast(`Die Telegrammnummer muss ${digits} Ziffern haben.`, false);
    }
    if (!body.value.trim()) return showToast('Schreibe zuerst eine Nachricht.', false);

    sending = true;
    sendButton.disabled = true;
    await post('send', {
        recipientNumber: recipientNumber.value,
        subject: subject.value,
        body: body.value
    });
    window.setTimeout(() => {
        sending = false;
        sendButton.disabled = false;
    }, 700);
});

window.addEventListener('message', (event) => {
    const message = event.data ?? {};
    if (message.action === 'open') {
        open(message.data);
    } else if (message.action === 'refresh' && message.data) {
        const previousFolder = activeFolder;
        const previousId = selectedMessageId;
        telegramData = message.data;
        activeFolder = previousFolder;
        selectedMessageId = previousId;
        render();
    } else if (message.action === 'result') {
        showToast(message.message, message.success === true);
        sending = false;
        sendButton.disabled = false;
        if (message.success && activeFolder === 'compose') composeForm.reset();
        updateCounters();
    } else if (message.action === 'close') {
        close();
    } else if (message.action === 'prompt') {
        promptKey.textContent = message.key || 'E';
        promptLabel.textContent = message.label || 'Telegrafenamt';
        prompt.classList.toggle('is-visible', message.visible === true);
        prompt.setAttribute('aria-hidden', message.visible === true ? 'false' : 'true');
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && app.classList.contains('is-open')) post('close');
});

if (typeof GetParentResourceName !== 'function') open(fallbackData);
