const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const state = {
    open: false,
    data: null,
    category: 'all',
    selected: null,
    cart: new Set(),
    purchasing: false
};

const app = $('#app');
const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'MS_ClothingShop';

async function nui(name, data = {}) {
    if (typeof GetParentResourceName !== 'function') {
        if (name === 'close') closeUi();
        if (name === 'purchase') {
            toast('Vorschaukauf abgeschlossen.', true);
            state.purchasing = false;
            state.cart.clear();
            renderCart();
            renderCatalog();
        }
        return { ok: true };
    }

    try {
        const response = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (_) {
        toast('Die Spielschnittstelle antwortet nicht.', false);
        return { ok: false };
    }
}

function money(value) {
    const currency = state.data?.currencyLabel || '$';
    return `${currency}${Math.max(0, Math.floor(Number(value) || 0)).toLocaleString('de-DE')}`;
}

function categoryLabel(key) {
    return (state.data?.categories || []).find((entry) => entry.key === key)?.label || key;
}

function productSymbol(product) {
    const labels = {
        hat: 'HUT',
        shirt: 'HEM',
        coat: 'MAN',
        pants: 'HOS',
        boots: 'STI'
    };
    return labels[product.category] || String(product.label || '?').slice(0, 3);
}

function rarityColor(rarity) {
    return {
        uncommon: '#79a18a',
        rare: '#7395bf',
        epic: '#9b77b7',
        legendary: '#d3a348'
    }[rarity] || '#a9956c';
}

function productByName(itemName) {
    return (state.data?.products || []).find((product) => product.item === itemName);
}

function selectProduct(product) {
    state.selected = product.item;
    $('#preview-name').textContent = product.label;
    $('#preview-slot').textContent = `${categoryLabel(product.category)} · ${money(product.price)}`;
    nui('preview', { item: product.item });
    renderCatalog();
}

function toggleCart(product) {
    if (state.cart.has(product.item)) {
        state.cart.delete(product.item);
    } else {
        const maximum = Math.max(1, Number(state.data?.maxCartItems) || 12);
        if (state.cart.size >= maximum) {
            return toast(`Die Einkaufsliste darf höchstens ${maximum} Artikel enthalten.`, false);
        }
        state.cart.add(product.item);
    }
    renderCart();
    renderCatalog();
}

function renderCategories() {
    const container = $('#categories');
    container.replaceChildren();
    for (const category of state.data?.categories || []) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `category-button${state.category === category.key ? ' active' : ''}`;
        button.textContent = category.label;
        button.addEventListener('click', () => {
            state.category = category.key;
            renderCategories();
            renderCatalog();
        });
        container.append(button);
    }
}

function makeProductCard(product) {
    const card = document.createElement('article');
    card.className = `product-card${state.selected === product.item ? ' selected' : ''}`;
    card.style.setProperty('--rarity', rarityColor(product.rarity));

    const top = document.createElement('div');
    top.className = 'product-top';
    const symbol = document.createElement('span');
    symbol.className = 'product-symbol';
    symbol.textContent = productSymbol(product);
    const price = document.createElement('strong');
    price.className = 'product-price';
    price.textContent = money(product.price);
    top.append(symbol, price);

    const title = document.createElement('h3');
    title.textContent = product.label;
    const description = document.createElement('p');
    description.textContent = product.description || 'Handgefertigtes Kleidungsstück.';

    const actions = document.createElement('div');
    actions.className = 'product-actions';
    const preview = document.createElement('button');
    preview.type = 'button';
    preview.className = 'preview-button';
    preview.textContent = 'Vorschau';
    preview.addEventListener('click', (event) => {
        event.stopPropagation();
        selectProduct(product);
    });
    const add = document.createElement('button');
    add.type = 'button';
    add.className = `add-button${state.cart.has(product.item) ? ' in-cart' : ''}`;
    add.textContent = state.cart.has(product.item) ? '✓' : '+';
    add.title = state.cart.has(product.item) ? 'Von Einkaufsliste entfernen' : 'Zur Einkaufsliste';
    add.addEventListener('click', (event) => {
        event.stopPropagation();
        toggleCart(product);
    });
    actions.append(preview, add);

    card.append(top, title, description, actions);
    card.addEventListener('click', () => selectProduct(product));
    return card;
}

function renderCatalog() {
    const catalog = $('#catalog');
    catalog.replaceChildren();
    const products = (state.data?.products || []).filter((product) => (
        state.category === 'all' || product.category === state.category
    ));

    $('#category-title').textContent = state.category === 'all'
        ? 'Alle Kleidungsstücke'
        : categoryLabel(state.category);
    $('#product-count').textContent = `${products.length} ${products.length === 1 ? 'Artikel' : 'Artikel'}`;
    if (!products.length) {
        const empty = document.createElement('div');
        empty.className = 'catalog-empty';
        empty.textContent = 'In dieser Kategorie sind aktuell keine passenden Artikel verfügbar.';
        catalog.append(empty);
        return;
    }
    for (const product of products) catalog.append(makeProductCard(product));
}

function renderCart() {
    const container = $('#cart-items');
    container.replaceChildren();
    const products = Array.from(state.cart)
        .map(productByName)
        .filter(Boolean);
    const total = products.reduce((sum, product) => sum + (Number(product.price) || 0), 0);
    const balance = Number(state.data?.player?.balance) || 0;

    for (const product of products) {
        const row = document.createElement('div');
        row.className = 'cart-item';
        const symbol = document.createElement('span');
        symbol.className = 'cart-item-symbol';
        symbol.textContent = productSymbol(product);
        const copy = document.createElement('div');
        copy.className = 'cart-item-copy';
        const label = document.createElement('strong');
        label.textContent = product.label;
        const price = document.createElement('span');
        price.textContent = money(product.price);
        copy.append(label, price);
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'remove-button';
        remove.textContent = '×';
        remove.setAttribute('aria-label', `${product.label} entfernen`);
        remove.addEventListener('click', () => toggleCart(product));
        row.append(symbol, copy, remove);
        container.append(row);
    }

    $('#cart-count').textContent = products.length;
    $('#cart-total').textContent = money(total);
    $('#cart-empty').classList.toggle('hidden', products.length > 0);
    container.classList.toggle('hidden', products.length === 0);

    const purchase = $('#purchase');
    purchase.disabled = state.purchasing || products.length === 0 || total > balance;
    purchase.textContent = state.purchasing
        ? 'Einkauf wird verarbeitet …'
        : (total > balance ? 'Guthaben reicht nicht' : 'Liste kaufen');
}

function renderHeader() {
    $('#shop-name').textContent = state.data?.shop?.label || 'Bekleidungshaus';
    $('#balance').textContent = money(state.data?.player?.balance);
    $('#account-label').textContent = state.data?.account === 'bank' ? 'BANK' : 'BARGELD';
}

function renderAll() {
    if (!state.data) return;
    const available = new Set((state.data.products || []).map((product) => product.item));
    for (const itemName of Array.from(state.cart)) {
        if (!available.has(itemName)) state.cart.delete(itemName);
    }
    if (state.selected && !available.has(state.selected)) state.selected = null;
    renderHeader();
    renderCategories();
    renderCatalog();
    renderCart();
}

function openUi(data) {
    state.open = true;
    state.data = data;
    state.category = 'all';
    state.selected = null;
    state.cart.clear();
    state.purchasing = false;
    $('#preview-name').textContent = 'Wähle ein Kleidungsstück';
    $('#preview-slot').textContent = 'Vorschau am Charakter';
    $('#zoom').value = '50';
    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
    renderAll();
}

function closeUi() {
    state.open = false;
    state.data = null;
    state.selected = null;
    state.cart.clear();
    state.purchasing = false;
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
}

function toast(message, success = true) {
    if (!message) return;
    const element = document.createElement('div');
    element.className = `toast${success ? '' : ' error'}`;
    element.textContent = message;
    $('#toast-region').append(element);
    window.setTimeout(() => element.remove(), 3700);
}

$('#close').addEventListener('click', () => nui('close'));
$('#refresh').addEventListener('click', () => nui('refresh'));
$('#purchase').addEventListener('click', () => {
    if (!state.cart.size || state.purchasing) return;
    state.purchasing = true;
    renderCart();
    nui('purchase', { items: Array.from(state.cart) });
});

$$('[data-rotate]').forEach((button) => {
    button.addEventListener('click', () => {
        nui('rotate', { direction: Number(button.dataset.rotate) });
    });
});

$('#zoom').addEventListener('input', (event) => {
    nui('zoom', { value: Number(event.target.value) / 100 });
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.open) nui('close');
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'open') openUi(message.data);
    if (message.action === 'refresh' && state.open) {
        state.data = message.data;
        renderAll();
    }
    if (message.action === 'result') {
        state.purchasing = false;
        if (message.clearCart) state.cart.clear();
        renderCart();
        renderCatalog();
        toast(message.message, message.success === true);
    }
    if (message.action === 'close') closeUi();
    if (message.action === 'prompt') {
        $('#prompt').classList.toggle('hidden', message.visible !== true);
        $('#prompt-key').textContent = message.key || 'E';
        $('#prompt-label').textContent = message.label || 'Bekleidungshaus';
    }
});

if (typeof GetParentResourceName !== 'function') {
    openUi({
        shop: { id: 'valentine', label: 'Valentine Schneiderei' },
        player: { name: 'Eleanor Masterson', sex: 'female', balance: 248 },
        account: 'cash',
        currencyLabel: '$',
        maxCartItems: 12,
        categories: [
            { key: 'all', label: 'Alle' },
            { key: 'hat', label: 'Hüte' },
            { key: 'shirt', label: 'Hemden & Blusen' },
            { key: 'coat', label: 'Mäntel' },
            { key: 'pants', label: 'Hosen' },
            { key: 'boots', label: 'Stiefel' }
        ],
        products: [
            { item: 'tailor_hat_female', label: 'Damen-Reisehut', description: 'Ein eleganter und wetterfester Reisehut.', category: 'hat', rarity: 'common', price: 32, weight: 380, componentHash: 3429928 },
            { item: 'tailor_shirt_female', label: 'Baumwollbluse', description: 'Eine fein vernähte Bluse aus weicher Baumwolle.', category: 'shirt', rarity: 'common', price: 38, weight: 560, componentHash: 4745637 },
            { item: 'tailor_coat_female', label: 'Damen-Reisemantel', description: 'Ein warmer Reisemantel mit klassischem Schnitt.', category: 'coat', rarity: 'uncommon', price: 86, weight: 1480, componentHash: 8351677 },
            { item: 'tailor_pants_female', label: 'Damen-Reithose', description: 'Eine bequeme Hose für Reise und Ausritt.', category: 'pants', rarity: 'common', price: 46, weight: 760, componentHash: 18069356 },
            { item: 'tailor_boots_female', label: 'Damen-Schnürstiefel', description: 'Feine Schnürstiefel aus widerstandsfähigem Leder.', category: 'boots', rarity: 'common', price: 62, weight: 1020, componentHash: 26925726 }
        ]
    });
}
