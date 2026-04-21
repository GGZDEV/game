export const keys = {};
export const justPressed = {};
const pressedThisFrame = new Set();

window.addEventListener('keydown', e => {
    const k = e.key.toLowerCase();
    if (!keys[k]) pressedThisFrame.add(k);
    keys[k] = true;
    // Prevent page scroll with space/arrows
    if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) {
        e.preventDefault();
    }
});

window.addEventListener('keyup', e => {
    keys[e.key.toLowerCase()] = false;
});

window.addEventListener('blur', () => {
    for (const k in keys) keys[k] = false;
});

export function inputFrameStart() {
    for (const k in justPressed) delete justPressed[k];
    for (const k of pressedThisFrame) justPressed[k] = true;
    pressedThisFrame.clear();
}

export function isDown(...names) {
    return names.some(n => keys[n]);
}

export function wasPressed(...names) {
    return names.some(n => justPressed[n]);
}
