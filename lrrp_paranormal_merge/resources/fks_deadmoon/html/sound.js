// 3D zombie sounds. Lua sends: play { id, file, rate, volume, pan } · update { id, volume, pan }
const ctx = new AudioContext();
const buffers = {};   // file -> Promise<AudioBuffer>
const playing = {};   // id -> { gain, panner }

function load(file) {
    if (!buffers[file]) {
        buffers[file] = fetch('../sounds/' + encodeURIComponent(file))
            .then(r => r.arrayBuffer())
            .then(data => ctx.decodeAudioData(data))
            .catch(err => { console.error('[fks-deadmoon] could not load ' + file, err); delete buffers[file]; });
    }
    return buffers[file];
}

// tells Lua how a test sound went (/deadmoon som)
function report(msg, ok, error) {
    if (!msg.test) return;
    fetch(`https://${GetParentResourceName()}/soundState`, {
        method: 'POST',
        body: JSON.stringify({ ok, error: error || '', state: ctx.state }),
    }).catch(() => {});
}

async function play(msg) {
    if (ctx.state === 'suspended') {
        // never wait forever if the browser blocks audio
        await Promise.race([ctx.resume(), new Promise(r => setTimeout(r, 1000))]);
    }
    const buffer = await load(msg.file);
    if (!buffer) return report(msg, false, 'could not load/decode sounds/' + msg.file);
    if (ctx.state !== 'running') return report(msg, false, 'AudioContext ' + ctx.state);

    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.playbackRate.value = msg.rate || 1.0;

    const panner = ctx.createStereoPanner();
    const gain = ctx.createGain();
    panner.pan.value = msg.pan || 0;
    gain.gain.value = msg.volume || 0;

    source.connect(panner).connect(gain).connect(ctx.destination);
    playing[msg.id] = { gain, panner };
    source.onended = () => delete playing[msg.id];
    source.start();
    report(msg, true);
}

function update(msg) {
    const s = playing[msg.id];
    if (!s) return;
    // short ramp so moving zombies don't "click"
    s.gain.gain.setTargetAtTime(msg.volume, ctx.currentTime, 0.05);
    s.panner.pan.setTargetAtTime(msg.pan, ctx.currentTime, 0.05);
}

window.addEventListener('message', (e) => {
    const msg = e.data;
    if (msg.action === 'play') play(msg);
    else if (msg.action === 'update') update(msg);
    else if (msg.action === 'preload') (msg.files || []).forEach(load);
});
