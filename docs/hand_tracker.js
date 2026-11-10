// Puente entre la cámara + MediaPipe Hand Landmarker y Flutter (Dart).
//
// Pipeline por cada frame de video:
//   cámara (getUserMedia) -> HandLandmarker.detectForVideo -> 21 landmarks (x, y, z)
//   -> se dibujan sobre el preview -> se envían a Dart como Float32Array(63).
//
// Toda la lógica de "qué gesto es" y "qué función ejecuta" vive en Dart
// (lib/gestures/touchless_gesture_detector.dart).

import { FilesetResolver, HandLandmarker } from './mediapipe/vision_bundle.mjs';

// Conexiones entre landmarks para dibujar el esqueleto de la mano.
const HAND_CONNECTIONS = [
  [0, 1], [1, 2], [2, 3], [3, 4],        // pulgar
  [0, 5], [5, 6], [6, 7], [7, 8],        // índice
  [5, 9], [9, 10], [10, 11], [11, 12],   // medio
  [9, 13], [13, 14], [14, 15], [15, 16], // anular
  [13, 17], [17, 18], [18, 19], [19, 20],// meñique
  [0, 17],
];

const state = {
  landmarker: null,
  video: null,
  stream: null,
  canvas: document.createElement('canvas'),
  listener: null,
  running: false,
  lastVideoTime: -1,
  rafId: 0,
};

state.canvas.style.width = '100%';
state.canvas.style.height = '100%';
state.canvas.style.objectFit = 'cover';
state.canvas.style.pointerEvents = 'none';
state.canvas.style.display = 'block';
state.canvas.style.background = '#111';

async function createLandmarker() {
  const fileset = await FilesetResolver.forVisionTasks('./mediapipe/wasm');
  const options = (delegate) => ({
    baseOptions: { modelAssetPath: './mediapipe/hand_landmarker.task', delegate },
    runningMode: 'VIDEO',
    numHands: 1,
    minHandDetectionConfidence: 0.6,
    minHandPresenceConfidence: 0.6,
    minTrackingConfidence: 0.5,
  });
  try {
    return await HandLandmarker.createFromOptions(fileset, options('GPU'));
  } catch (e) {
    console.warn('GPU no disponible, usando CPU', e);
    return await HandLandmarker.createFromOptions(fileset, options('CPU'));
  }
}

async function start() {
  if (state.running) return;
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
    throw new Error(
      'La cámara solo funciona en https:// o en localhost. ' +
      'Abre la app con https://.');
  }
  if (!state.landmarker) state.landmarker = await createLandmarker();

  state.stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
    audio: false,
  });
  const video = document.createElement('video');
  video.playsInline = true;
  video.muted = true;
  video.srcObject = state.stream;
  await video.play();
  state.video = video;
  state.running = true;
  state.lastVideoTime = -1;
  loop();
}

function stop() {
  state.running = false;
  cancelAnimationFrame(state.rafId);
  state.stream?.getTracks().forEach((t) => t.stop());
  state.stream = null;
  state.video = null;
  const ctx = state.canvas.getContext('2d');
  ctx.clearRect(0, 0, state.canvas.width, state.canvas.height);
  state.listener?.(null, 1);
}

function loop() {
  if (!state.running) return;
  const video = state.video;
  if (video.readyState >= 2 && video.currentTime !== state.lastVideoTime) {
    state.lastVideoTime = video.currentTime;
    const result = state.landmarker.detectForVideo(video, performance.now());
    const hand = result.landmarks && result.landmarks[0];
    draw(video, hand);

    const aspect = video.videoWidth / video.videoHeight;
    if (hand) {
      const data = new Float32Array(63);
      hand.forEach((p, i) => {
        data[i * 3] = p.x;
        data[i * 3 + 1] = p.y;
        data[i * 3 + 2] = p.z;
      });
      state.listener?.(data, aspect);
    } else {
      state.listener?.(null, aspect);
    }
  }
  state.rafId = requestAnimationFrame(loop);
}

function draw(video, hand) {
  const c = state.canvas;
  if (c.width !== video.videoWidth) c.width = video.videoWidth;
  if (c.height !== video.videoHeight) c.height = video.videoHeight;
  const ctx = c.getContext('2d');

  // Espejo: se ve como en un espejo, igual que la cámara frontal del celular.
  ctx.save();
  ctx.translate(c.width, 0);
  ctx.scale(-1, 1);
  ctx.drawImage(video, 0, 0, c.width, c.height);

  if (hand) {
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#7CF29A';
    for (const [a, b] of HAND_CONNECTIONS) {
      ctx.beginPath();
      ctx.moveTo(hand[a].x * c.width, hand[a].y * c.height);
      ctx.lineTo(hand[b].x * c.width, hand[b].y * c.height);
      ctx.stroke();
    }
    hand.forEach((p, i) => {
      const highlight = i === 4 || i === 8; // pulgar e índice (pinch)
      ctx.fillStyle = highlight ? '#FF5252' : '#FFFFFF';
      ctx.beginPath();
      ctx.arc(p.x * c.width, p.y * c.height, highlight ? 7 : 4, 0, Math.PI * 2);
      ctx.fill();
    });
  }
  ctx.restore();
}

window.handTracker = {
  // Devuelve null si todo salió bien, o un mensaje de error legible.
  start: async () => {
    try {
      await start();
      return null;
    } catch (e) {
      console.error(e);
      if (e && e.name === 'NotAllowedError') return 'Permiso de cámara denegado.';
      if (e && e.name === 'NotFoundError') return 'No se encontró ninguna cámara.';
      return String((e && e.message) || e);
    }
  },
  stop,
  isRunning: () => state.running,
  setListener: (fn) => { state.listener = fn; },
  attachPreview: (container) => {
    container.style.width = '100%';
    container.style.height = '100%';
    container.style.pointerEvents = 'none';
    container.appendChild(state.canvas);
  },
};
