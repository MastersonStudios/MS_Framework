const bank = document.getElementById('bank');
const prompt = document.getElementById('prompt');
const branch = document.getElementById('branch');
const holder = document.getElementById('holder');
const accountNumber = document.getElementById('accountNumber');
const cash = document.getElementById('cash');
const balance = document.getElementById('balance');
const transactions = document.getElementById('transactions');
const transactionCount = document.getElementById('transactionCount');
const cashAmount = document.getElementById('cashAmount');
const targetAccount = document.getElementById('targetAccount');
const transferAmount = document.getElementById('transferAmount');
const toast = document.getElementById('toast');
const actionButtons = [...document.querySelectorAll('.button')];

let state = null;
let busy = false;
let toastTimer = null;

const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
});

const currency = () => state?.currency || '$';

const money = (value) => {
    const amount = Number(value) || 0;
    return `${currency()}${Math.abs(amount).toLocaleString('de-DE')}`;
};

const transactionLabels = {
    deposit: 'Einzahlung',
    withdrawal: 'Auszahlung',
    transfer_in: 'Überweisung erhalten',
    transfer_out: 'Überweisung gesendet'
};

function setBusy(value) {
    busy = value === true;
    actionButtons.forEach((button) => {
        button.disabled = busy;
    });
}

function showToast(message, success = true) {
    window.clearTimeout(toastTimer);
    toast.textContent = message || 'Bankauftrag verarbeitet.';
    toast.classList.toggle('error', !success);
    toast.classList.remove('hidden');
    toastTimer = window.setTimeout(() => toast.classList.add('hidden'), 3800);
}

function renderTransactions(rows = []) {
    transactions.replaceChildren();
    transactionCount.textContent = `${rows.length} ${rows.length === 1 ? 'Buchung' : 'Buchungen'}`;

    if (!rows.length) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = 'Für dieses Konto liegen noch keine Buchungen vor.';
        transactions.append(empty);
        return;
    }

    rows.forEach((entry) => {
        const amount = Number(entry.amount) || 0;
        const row = document.createElement('article');
        row.className = `transaction ${amount < 0 ? 'transaction--negative' : ''}`;

        const icon = document.createElement('span');
        icon.className = 'transaction__icon';
        icon.textContent = amount < 0 ? '−' : '+';

        const details = document.createElement('div');
        details.className = 'transaction__details';
        const title = document.createElement('strong');
        title.textContent = transactionLabels[entry.type] || entry.description || 'Buchung';
        const meta = document.createElement('small');
        const parts = [entry.createdAt || ''];
        if (entry.counterpartyAccount) parts.push(`Konto ${entry.counterpartyAccount}`);
        meta.textContent = parts.filter(Boolean).join(' · ');
        details.append(title, meta);

        const amounts = document.createElement('div');
        amounts.className = 'transaction__amount';
        const value = document.createElement('strong');
        value.textContent = `${amount < 0 ? '−' : '+'}${money(amount)}`;
        const after = document.createElement('small');
        after.textContent = `Saldo ${money(entry.balanceAfter)}`;
        amounts.append(value, after);

        row.append(icon, details, amounts);
        transactions.append(row);
    });
}

function render(data) {
    state = data || {};
    const account = state.account || {};
    branch.textContent = state.branch || 'Bank';
    holder.textContent = account.holder || '–';
    accountNumber.textContent = account.number || '–';
    cash.textContent = money(account.cash);
    balance.textContent = money(account.balance);
    document.getElementById('cashCurrency').textContent = currency();
    document.getElementById('transferCurrency').textContent = currency();
    cashAmount.max = Number(state.maxTransactionAmount) || '';
    transferAmount.max = Number(state.maxTransactionAmount) || '';
    renderTransactions(state.transactions || []);
}

function validInput(input) {
    const amount = Number(input.value);
    const max = Number(state?.maxTransactionAmount) || Number.MAX_SAFE_INTEGER;
    if (!Number.isInteger(amount) || amount < 1 || amount > max) {
        showToast(`Betrag muss zwischen ${currency()}1 und ${money(max)} liegen.`, false);
        return null;
    }
    return amount;
}

function cashOperation(type) {
    if (busy) return;
    const amount = validInput(cashAmount);
    if (!amount) return;
    setBusy(true);
    post(type, { amount }).catch(() => {
        setBusy(false);
        showToast('Die Verbindung zur Bank ist fehlgeschlagen.', false);
    });
}

document.getElementById('close').addEventListener('click', () => post('close'));
document.getElementById('refresh').addEventListener('click', () => {
    if (!busy) post('refresh');
});
document.getElementById('deposit').addEventListener('click', () => cashOperation('deposit'));
document.getElementById('withdraw').addEventListener('click', () => cashOperation('withdraw'));

document.getElementById('transferForm').addEventListener('submit', (event) => {
    event.preventDefault();
    if (busy) return;
    const amount = validInput(transferAmount);
    const number = targetAccount.value.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (!amount) return;
    if (number.length < 4) {
        showToast('Gib eine gültige Empfängerkontonummer ein.', false);
        return;
    }
    setBusy(true);
    post('transfer', { accountNumber: number, amount }).catch(() => {
        setBusy(false);
        showToast('Die Verbindung zur Bank ist fehlgeschlagen.', false);
    });
});

document.querySelectorAll('.quick-values button').forEach((button) => {
    button.addEventListener('click', () => {
        cashAmount.value = button.dataset.amount || '';
    });
});

document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((tab) => tab.classList.remove('active'));
        document.querySelectorAll('.panel').forEach((panel) => panel.classList.remove('active'));
        button.classList.add('active');
        document.getElementById(`${button.dataset.tab}Form`).classList.add('active');
    });
});

document.getElementById('copyAccount').addEventListener('click', async () => {
    const number = state?.account?.number;
    if (!number) return;
    try {
        await navigator.clipboard.writeText(number);
        showToast('Kontonummer kopiert.');
    } catch {
        showToast(`Kontonummer: ${number}`);
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !bank.classList.contains('hidden')) post('close');
});

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data.action !== 'string') return;
    if (data.action === 'prompt') {
        prompt.classList.toggle('hidden', data.visible !== true);
        document.getElementById('promptKey').textContent = data.key || 'E';
        document.getElementById('promptLabel').textContent = data.label || 'Bank';
        return;
    }
    if (data.action === 'open') {
        render(data.data);
        bank.classList.remove('hidden');
        prompt.classList.add('hidden');
        setBusy(false);
        return;
    }
    if (data.action === 'refresh') {
        render(data.data);
        setBusy(false);
        return;
    }
    if (data.action === 'result') {
        setBusy(false);
        showToast(data.message, data.success === true);
        return;
    }
    if (data.action === 'close') {
        bank.classList.add('hidden');
        toast.classList.add('hidden');
        setBusy(false);
        state = null;
    }
});
