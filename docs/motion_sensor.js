// Puente entre la IMU del celular (acelerómetro + orientación) y Flutter.
//
// El navegador del celular entrega:
//   devicemotion      -> aceleración lineal (x, y, z) en m/s²
//   deviceorientation -> beta (adelante/atrás) y gamma (izquierda/derecha)
// Cada lectura se envía a Dart; la detección de gestos (agitar, inclinar,
// boca abajo) vive en lib/gestures/inertial_gesture_detector.dart.
(() => {
  const state = {
    listener: null,
    running: false,
    beta: null,
    gamma: null,
    gravity: null, // para celulares que solo dan "accelerationIncludingGravity"
    gotData: false,
    wakeLock: null,
  };

  function onOrientation(e) {
    if (e.beta != null) state.beta = e.beta;
    if (e.gamma != null) state.gamma = e.gamma;
  }

  function onMotion(e) {
    let a = e.acceleration;
    if (!a || a.x == null) {
      // Sin giroscopio: estimar la gravedad con un filtro pasa-bajos y restarla.
      const g = e.accelerationIncludingGravity;
      if (!g || g.x == null) return;
      const p = state.gravity;
      state.gravity = p
        ? { x: 0.8 * p.x + 0.2 * g.x, y: 0.8 * p.y + 0.2 * g.y, z: 0.8 * p.z + 0.2 * g.z }
        : { x: g.x, y: g.y, z: g.z };
      a = { x: g.x - state.gravity.x, y: g.y - state.gravity.y, z: g.z - state.gravity.z };
    }
    state.gotData = true;
    state.listener?.(a.x, a.y, a.z, state.beta, state.gamma);
  }

  async function requestPermission() {
    // iPhone (Safari) exige pedir permiso desde un toque del usuario.
    const perms = [];
    if (typeof DeviceMotionEvent !== 'undefined' &&
        typeof DeviceMotionEvent.requestPermission === 'function') {
      perms.push(DeviceMotionEvent.requestPermission());
    }
    if (typeof DeviceOrientationEvent !== 'undefined' &&
        typeof DeviceOrientationEvent.requestPermission === 'function') {
      perms.push(DeviceOrientationEvent.requestPermission());
    }
    const results = await Promise.all(perms);
    if (results.some((r) => r !== 'granted')) {
      throw new Error('Permiso de movimiento denegado. En iPhone: Ajustes → Safari → Movimiento y orientación.');
    }
  }

  async function keepAwake() {
    try { state.wakeLock = await navigator.wakeLock?.request('screen'); } catch (_) { /* opcional */ }
  }

  // Pantalla completa + orientación vertical fija: así inclinar el celular
  // no gira la app. Solo funciona en algunos navegadores; si falla, se ignora.
  async function lockPortrait() {
    try {
      if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen({ navigationUI: 'hide' });
      }
      await screen.orientation?.lock?.('portrait');
    } catch (_) { /* opcional */ }
  }

  async function start() {
    if (state.running) return null;
    if (!window.isSecureContext) {
      return 'Los sensores solo funcionan en https://.';
    }
    if (typeof DeviceMotionEvent === 'undefined') {
      return 'Este navegador no da acceso a los sensores de movimiento.';
    }
    try {
      await requestPermission();
    } catch (e) {
      return e.message || String(e);
    }
    state.gotData = false;
    window.addEventListener('devicemotion', onMotion);
    window.addEventListener('deviceorientation', onOrientation);
    state.running = true;
    lockPortrait();
    keepAwake();

    // Las laptops tienen el evento pero nunca mandan datos: se avisa.
    await new Promise((r) => setTimeout(r, 1500));
    if (state.running && !state.gotData) {
      stop();
      return 'Este dispositivo no tiene acelerómetro. Abre la app en el celular.';
    }
    return null;
  }

  function stop() {
    window.removeEventListener('devicemotion', onMotion);
    window.removeEventListener('deviceorientation', onOrientation);
    state.running = false;
    state.gravity = null;
    try { state.wakeLock?.release(); } catch (_) { /* opcional */ }
    state.wakeLock = null;
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && state.running) keepAwake();
  });

  window.motionSensor = {
    // Devuelve null si arrancó bien, o un mensaje de error legible.
    start: () => start().catch((e) => String((e && e.message) || e)),
    stop,
    setListener: (fn) => { state.listener = fn; },
  };
})();
