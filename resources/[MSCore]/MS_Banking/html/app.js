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
const companyTab = document.getElementById('companyTab');
const companyAmount = document.getElementById('companyAmount');
const companyDeposit = document.getElementById('companyDeposit');
const companyWithdraw = document.getElementById('companyWithdraw');
const adminTab = document.getElementById('adminTab');
const historyTitle = document.getElementById('historyTitle');
const cashTaxHint = document.getElementById('cashTaxHint');
const companyTaxHint = document.getElementById('companyTaxHint');
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
    transfer_out: 'Überweisung gesendet',
    company_deposit: 'Firmeneinzahlung',
    company_withdrawal: 'Firmenauszahlung',
    tax: 'Transaktionssteuer'
};

const operationLabels = {
    deposit: 'Private Einzahlung',
    withdrawal: 'Private Auszahlung',
    companyDeposit: 'Firmeneinzahlung',
    companyWithdrawal: 'Firmenauszahlung'
};

function setBusy(value) {
    busy = value === true;
    actionButtons.forEach((button) => {
        button.disabled = busy;
    });
    companyDeposit.disabled = busy || state?.company?.canDeposit !== true;
    companyWithdraw.disabled = busy || state?.company?.canWithdraw !== true;
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
        title.textContent = entry.type === 'tax'
            ? `Steuer · ${operationLabels[entry.operationType] || 'Bankvorgang'}`
            : transactionLabels[entry.type] || entry.description || 'Buchung';
        const meta = document.createElement('small');
        const parts = [entry.createdAt || ''];
        if (entry.counterpartyAccount) parts.push(`Konto ${entry.counterpartyAccount}`);
        if (entry.actorName) parts.push(entry.actorName);
        if (entry.sourceAccount) parts.push(entry.sourceAccount);
        if (entry.grossAmount) parts.push(`Brutto ${money(entry.grossAmount)}`);
        meta.textContent = parts.filter(Boolean).join(' · ');
        details.append(title, meta);

        const amounts = document.createElement('div');
        amounts.className = 'transaction__amount';
        const value = document.createElement('strong');
        value.textContent = `${amount < 0 ? '−' : '+'}${money(amount)}`;
        amounts.append(value);
        if (entry.balanceAfter !== undefined && entry.balanceAfter !== null) {
            const after = document.createElement('small');
            after.textContent = `Saldo ${money(entry.balanceAfter)}`;
            amounts.append(after);
        }

        row.append(icon, details, amounts);
        transactions.append(row);
    });
}

function activeTab() {
    return document.querySelector('.tab.active')?.dataset.tab || 'cash';
}

function renderActiveTransactions() {
    const companyActive = activeTab() === 'company' && state?.company;
    const adminActive = activeTab() === 'admin' && state?.admin;
    historyTitle.textContent = adminActive
        ? 'Steuerbuchungen'
        : companyActive ? 'Firmenbuchungen' : 'Letzte Buchungen';
    const rows = adminActive
        ? state.admin.transactions || []
        : companyActive ? state.company.transactions || [] : state?.transactions || [];
    renderTransactions(rows);
}

function selectTab(name) {
    const button = document.querySelector(`.tab[data-tab="${name}"]`);
    const panel = document.getElementById(`${name}Form`);
    if (!button || !panel || button.classList.contains('hidden')) return;
    document.querySelectorAll('.tab').forEach((tab) => tab.classList.remove('active'));
    document.querySelectorAll('.panel').forEach((current) => current.classList.remove('active'));
    button.classList.add('active');
    panel.classList.add('active');
    renderActiveTransactions();
}

function estimatedTax(operation, value) {
    const amount = Number(value);
    const tax = state?.tax;
    if (!Number.isInteger(amount) || amount < 1 || !tax?.enabled
        || tax.appliesTo?.[operation] !== true) return 0;
    const raw = amount * (Number(tax.percent) || 0) / 100;
    let fee;
    if (tax.rounding === 'floor') fee = Math.floor(raw);
    else if (tax.rounding === 'round') fee = Math.round(raw);
    else fee = Math.ceil(raw);
    if (raw > 0) fee = Math.max(fee, Number(tax.minimum) || 0);
    return Math.max(0, fee);
}

function taxHint(input, operations) {
    const amount = Number(input.value);
    if (!Number.isInteger(amount) || amount < 1) {
        return state?.tax?.enabled
            ? `${Number(state.tax.percent) || 0} % Transaktionssteuer`
            : 'Keine Transaktionssteuer';
    }
    return operations.map(({ key, label }) => {
        const fee = estimatedTax(key, amount);
        const net = Math.max(0, amount - fee);
        return `${label}: ${money(fee)} Steuer · ${money(net)} netto`;
    }).join(' | ');
}

function updateTaxHints() {
    cashTaxHint.textContent = taxHint(cashAmount, [
        { key: 'deposit', label: 'Einzahlung' },
        { key: 'withdrawal', label: 'Auszahlung' }
    ]);
    companyTaxHint.textContent = taxHint(companyAmount, [
        { key: 'companyDeposit', label: 'Einzahlung' },
        { key: 'companyWithdrawal', label: 'Auszahlung' }
    ]);
}

function render(data) {
    state = data || {};
    const account = state.account || {};
    const company = state.company;
    const admin = state.admin;
    branch.textContent = state.branch || 'Bank';
    holder.textContent = account.holder || '–';
    accountNumber.textContent = account.number || '–';
    cash.textContent = money(account.cash);
    balance.textContent = money(account.balance);
    document.getElementById('cashCurrency').textContent = currency();
    document.getElementById('transferCurrency').textContent = currency();
    document.getElementById('companyCurrency').textContent = currency();
    cashAmount.max = Number(state.maxTransactionAmount) || '';
    transferAmount.max = Number(state.maxTransactionAmount) || '';
    companyAmount.max = Number(state.maxTransactionAmount) || '';

    companyTab.classList.toggle('hidden', !company);
    adminTab.classList.toggle('hidden', !admin);
    document.querySelector('.tabs').style.setProperty(
        '--tab-count',
        String(2 + (company ? 1 : 0) + (admin ? 1 : 0))
    );
    if (company) {
        document.getElementById('companyLabel').textContent = company.label || company.job;
        document.getElementById('companyJob').textContent = company.job || '';
        document.getElementById('companyBalance').textContent = money(company.balance);
        const access = [];
        access.push(company.canDeposit
            ? 'Du darfst auf dieses Firmenkonto einzahlen.'
            : `Einzahlungen benötigen mindestens Jobgrad ${company.minDepositGrade}.`);
        access.push(company.canWithdraw
            ? 'Du darfst Firmenguthaben abheben.'
            : `Auszahlungen benötigen mindestens Jobgrad ${company.minWithdrawGrade}.`);
        document.getElementById('companyAccess').textContent = access.join(' ');
    }

    if (admin) {
        document.getElementById('adminLabel').textContent = admin.label || 'Administrationskonto';
        document.getElementById('adminBalance').textContent = money(admin.balance);
        document.getElementById('adminTaxPercent').textContent = `${admin.taxPercent || 0} %`;
        document.getElementById('adminMinimumTax').textContent = money(admin.minimumTax);
        const roundingLabels = { ceil: 'Aufrunden', floor: 'Abrunden', round: 'Kaufmännisch' };
        document.getElementById('adminTaxRounding').textContent =
            roundingLabels[admin.rounding] || admin.rounding;
    }

    if ((!company && activeTab() === 'company') || (!admin && activeTab() === 'admin')) {
        selectTab('cash');
    }

    updateTaxHints();
    renderActiveTransactions();
    setBusy(busy);
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

function companyOperation(type) {
    if (busy || !state?.company) return;
    const allowed = type === 'companyDeposit'
        ? state.company.canDeposit
        : state.company.canWithdraw;
    if (!allowed) {
        showToast('Dein Jobgrad besitzt dafür keine Berechtigung.', false);
        return;
    }
    const amount = validInput(companyAmount);
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
companyDeposit.addEventListener('click', () => companyOperation('companyDeposit'));
companyWithdraw.addEventListener('click', () => companyOperation('companyWithdraw'));

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
        updateTaxHints();
    });
});

cashAmount.addEventListener('input', updateTaxHints);
companyAmount.addEventListener('input', updateTaxHints);

document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => selectTab(button.dataset.tab));
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
