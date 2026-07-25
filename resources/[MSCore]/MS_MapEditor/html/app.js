const editor = document.getElementById('editor');
const mode = document.getElementById('mode');
const model = document.getElementById('model');
const position = document.getElementById('position');
const rotation = document.getElementById('rotation');

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;
    if (data.action === 'hide') {
        editor.classList.add('hidden');
        return;
    }
    if (data.action !== 'show') return;

    mode.textContent = data.mode || 'Mapeditor';
    model.textContent = data.model || '';
    position.textContent = [data.x, data.y, data.z]
        .map(value => Number(value || 0).toFixed(2))
        .join(' / ');
    rotation.textContent = [data.rotX, data.rotY, data.rotZ]
        .map(value => `${Number(value || 0).toFixed(1)}°`)
        .join(' / ');
    editor.classList.remove('hidden');
});
