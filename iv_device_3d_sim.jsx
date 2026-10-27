import { useRef, useEffect, useState } from "react";
import * as THREE from "three";

// ─────────────────────────────────────────────────────────────────
// IoT-PIMS 가상 기기 시뮬레이터 (Gazebo/RViz 스타일)
//  - 드래그: 카메라 궤도 회전 / 휠: 줌
//  - 흔들기: 감쇠 진자 물리 → 무게 노이즈 → RATE_SHAKING 감지
//  - 흔들림 판정: flow_rate_monitor.h 와 동일 (최근 5샘플 max-min > 2.0g)
// ─────────────────────────────────────────────────────────────────

const SHAKE_WINDOW = 5;
const SHAKE_THRESHOLD_G = 2.0;
const FAST_RATIO = 1.5;
const SLOW_RATIO = 0.5;
const SHORT_WINDOW = 3;
const LONG_WINDOW = 15;
const SAMPLE_MS = 400;

export default function IvDevice3DSim() {
  const mountRef = useRef(null);
  const chartRef = useRef(null);
  const stateRef = useRef({
    thX: 0, thZ: 0, omX: 0, omZ: 0,        // 진자 각도/각속도
    bagX: 0, bagZ: 0, bagOmX: 0, bagOmZ: 0, // 수액백 2차 진자
    fluid: 500,                              // 잔량 (g ≈ mL)
    buf: [], flowRate: 120,                  // mL/h
    autoRotate: false, running: true,
  });
  const [weight, setWeight] = useState(500);
  const [status, setStatus] = useState("OK");
  const [fluidPct, setFluidPct] = useState(100);
  const [flowRate, setFlowRate] = useState(120);
  const [autoRotate, setAutoRotate] = useState(false);

  useEffect(() => { stateRef.current.flowRate = flowRate; }, [flowRate]);
  useEffect(() => { stateRef.current.autoRotate = autoRotate; }, [autoRotate]);

  useEffect(() => {
    const mount = mountRef.current;
    const W = mount.clientWidth, H = mount.clientHeight;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x22262e);
    scene.fog = new THREE.Fog(0x22262e, 8, 22);

    const camera = new THREE.PerspectiveCamera(50, W / H, 0.1, 100);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(W, H);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    mount.appendChild(renderer.domElement);

    // 조명
    scene.add(new THREE.HemisphereLight(0xdde4ee, 0x30343c, 0.9));
    const dir = new THREE.DirectionalLight(0xffffff, 0.8);
    dir.position.set(4, 8, 5);
    scene.add(dir);

    // 바닥 그리드 + 축 기즈모 (RViz 스타일)
    const grid = new THREE.GridHelper(20, 40, 0x4a5568, 0x323844);
    grid.position.y = -3.2;
    scene.add(grid);
    const axes = new THREE.AxesHelper(0.9);
    axes.position.set(-2.6, -3.18, -2.6);
    scene.add(axes);

    // ── 기기 조립 ──────────────────────────────────────────────
    // 폴대 (고정 지지대)
    const poleMat = new THREE.MeshStandardMaterial({ color: 0x8a94a3, metalness: 0.6, roughness: 0.4 });
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 6.4, 16), poleMat);
    pole.position.set(-1.6, 0, 0);
    scene.add(pole);
    const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 1.7, 12), poleMat);
    arm.rotation.z = Math.PI / 2;
    arm.position.set(-0.78, 3.0, 0);
    scene.add(arm);

    // 진자 피벗 (폴대 암 끝)
    const pivot = new THREE.Group();
    pivot.position.set(0, 3.0, 0);
    scene.add(pivot);

    // 상단 걸이 고리
    const hookMat = new THREE.MeshStandardMaterial({ color: 0xb8bec8, metalness: 0.7, roughness: 0.35 });
    const topHook = new THREE.Mesh(new THREE.TorusGeometry(0.14, 0.028, 10, 24), hookMat);
    topHook.position.y = -0.14;
    pivot.add(topHook);
    const strap = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.34, 8), hookMat);
    strap.position.y = -0.44;
    pivot.add(strap);

    // 본체 케이스 (흰색, 미니어처 독립형)
    const body = new THREE.Group();
    body.position.y = -0.95;
    pivot.add(body);
    const caseMesh = new THREE.Mesh(
      new THREE.BoxGeometry(1.15, 0.72, 0.42),
      new THREE.MeshStandardMaterial({ color: 0xf2f3f5, roughness: 0.55 })
    );
    body.add(caseMesh);
    // 전면 디스플레이 패널
    const panel = new THREE.Mesh(
      new THREE.BoxGeometry(0.62, 0.3, 0.02),
      new THREE.MeshStandardMaterial({ color: 0x11161f, roughness: 0.3 })
    );
    panel.position.set(-0.14, 0.06, 0.22);
    body.add(panel);
    // 상태 LED
    const led = new THREE.Mesh(
      new THREE.SphereGeometry(0.035, 12, 12),
      new THREE.MeshStandardMaterial({ color: 0x22c55e, emissive: 0x16a34a, emissiveIntensity: 1.2 })
    );
    led.position.set(0.4, 0.06, 0.225);
    body.add(led);
    // 하단 로드셀 하우징
    const cell = new THREE.Mesh(
      new THREE.BoxGeometry(0.5, 0.16, 0.3),
      new THREE.MeshStandardMaterial({ color: 0xcbd2db, metalness: 0.3, roughness: 0.5 })
    );
    cell.position.y = -0.44;
    body.add(cell);
    // 하단 후크
    const botHook = new THREE.Mesh(new THREE.TorusGeometry(0.09, 0.02, 8, 20), hookMat);
    botHook.position.y = -0.62;
    body.add(botHook);

    // ── 수액백 (2차 진자) ─────────────────────────────────────
    const bagPivot = new THREE.Group();
    bagPivot.position.y = -0.62;
    body.add(bagPivot);
    const bagGroup = new THREE.Group();
    bagPivot.add(bagGroup);
    const bagShell = new THREE.Mesh(
      new THREE.BoxGeometry(0.85, 1.35, 0.24),
      new THREE.MeshStandardMaterial({ color: 0xdaf0f5, transparent: true, opacity: 0.34, roughness: 0.15 })
    );
    bagShell.position.y = -0.85;
    bagGroup.add(bagShell);
    // 내부 수액 (잔량에 따라 높이 변화)
    const fluidMesh = new THREE.Mesh(
      new THREE.BoxGeometry(0.78, 1, 0.18),
      new THREE.MeshStandardMaterial({ color: 0x66c7dd, transparent: true, opacity: 0.75, roughness: 0.2 })
    );
    bagGroup.add(fluidMesh);
    // 튜브 + 점적통
    const tube = new THREE.Mesh(
      new THREE.CylinderGeometry(0.022, 0.022, 0.85, 8),
      new THREE.MeshStandardMaterial({ color: 0xe8eef2, transparent: true, opacity: 0.8 })
    );
    tube.position.y = -1.95;
    bagGroup.add(tube);
    const drip = new THREE.Mesh(
      new THREE.CylinderGeometry(0.075, 0.075, 0.3, 12),
      new THREE.MeshStandardMaterial({ color: 0xf0f5f8, transparent: true, opacity: 0.55 })
    );
    drip.position.y = -1.7;
    bagGroup.add(drip);

    // ── 카메라 궤도 (수동 구현, OrbitControls 미사용) ──────────
    const cam = { theta: 0.6, phi: 1.15, r: 8.5, target: new THREE.Vector3(0, 0.6, 0) };
    const applyCam = () => {
      camera.position.set(
        cam.target.x + cam.r * Math.sin(cam.phi) * Math.sin(cam.theta),
        cam.target.y + cam.r * Math.cos(cam.phi),
        cam.target.z + cam.r * Math.sin(cam.phi) * Math.cos(cam.theta)
      );
      camera.lookAt(cam.target);
    };
    applyCam();

    let dragging = false, px = 0, py = 0;
    const onDown = (e) => { dragging = true; px = e.clientX; py = e.clientY; };
    const onMove = (e) => {
      if (!dragging) return;
      cam.theta -= (e.clientX - px) * 0.008;
      cam.phi = Math.min(2.6, Math.max(0.25, cam.phi - (e.clientY - py) * 0.008));
      px = e.clientX; py = e.clientY;
      applyCam();
    };
    const onUp = () => { dragging = false; };
    const onWheel = (e) => {
      e.preventDefault();
      cam.r = Math.min(18, Math.max(3.5, cam.r + e.deltaY * 0.008));
      applyCam();
    };
    const dom = renderer.domElement;
    dom.addEventListener("pointerdown", onDown);
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    dom.addEventListener("wheel", onWheel, { passive: false });

    // ── 물리 + 렌더 루프 ──────────────────────────────────────
    const s = stateRef.current;
    const G = 22, DAMP = 1.15;       // 진자 계수 (시각적 튜닝값)
    let last = performance.now();
    let raf;
    const loop = (now) => {
      raf = requestAnimationFrame(loop);
      const dt = Math.min(0.033, (now - last) / 1000);
      last = now;

      // 1차 진자 (기기 전체)
      s.omX += (-G * Math.sin(s.thX) - DAMP * s.omX) * dt;
      s.omZ += (-G * Math.sin(s.thZ) - DAMP * s.omZ) * dt;
      s.thX += s.omX * dt;
      s.thZ += s.omZ * dt;
      pivot.rotation.x = s.thX;
      pivot.rotation.z = s.thZ;

      // 2차 진자 (수액백 — 본체를 살짝 지연 추종)
      s.bagOmX += (-(G * 1.4) * Math.sin(s.bagX - s.thX * 0.4) - 1.9 * s.bagOmX) * dt;
      s.bagOmZ += (-(G * 1.4) * Math.sin(s.bagZ - s.thZ * 0.4) - 1.9 * s.bagOmZ) * dt;
      s.bagX += s.bagOmX * dt;
      s.bagZ += s.bagOmZ * dt;
      bagPivot.rotation.x = s.bagX;
      bagPivot.rotation.z = s.bagZ;

      // 수액 소모 + 잔량 시각화
      const gs = s.flowRate / 3600; // mL/h → g/s
      s.fluid = Math.max(0, s.fluid - gs * dt);
      const pct = s.fluid / 500;
      const h = Math.max(0.02, 1.28 * pct);
      fluidMesh.scale.y = h;
      fluidMesh.position.y = -0.85 - (1.28 - h) / 2;
      // 액면은 수평 유지 (백 기울기 상쇄)
      fluidMesh.rotation.x = -s.bagX;
      fluidMesh.rotation.z = -s.bagZ;

      // 잔량 부족 LED
      const low = s.fluid < 75;
      led.material.color.setHex(low ? 0xef4444 : 0x22c55e);
      led.material.emissive.setHex(low ? 0xb91c1c : 0x16a34a);

      if (s.autoRotate && !dragging) { cam.theta += 0.15 * dt; applyCam(); }
      renderer.render(scene, camera);
    };
    raf = requestAnimationFrame(loop);

    // ── 텔레메트리 샘플링 (펌웨어 로직 재현) ───────────────────
    const chart = chartRef.current;
    const ctx = chart.getContext("2d");
    const samples = [];
    const sampleTimer = setInterval(() => {
      // 로드셀 무게 = 잔량 + 흔들림 관성 노이즈
      const sway = Math.abs(s.omX) + Math.abs(s.omZ) + Math.abs(s.thX) * 3 + Math.abs(s.thZ) * 3;
      const noise = sway * 2.2 * (Math.random() - 0.5) * 2;
      const w = s.fluid + noise + (Math.random() - 0.5) * 0.15;
      samples.push(w);
      if (samples.length > 60) samples.shift();
      s.buf.push(w);
      if (s.buf.length > LONG_WINDOW + 1) s.buf.shift();

      // 흔들림 판정: 최근 5샘플 max-min > 2.0g
      let st = "OK";
      if (s.buf.length >= SHAKE_WINDOW) {
        const recent = s.buf.slice(-SHAKE_WINDOW);
        if (Math.max(...recent) - Math.min(...recent) > SHAKE_THRESHOLD_G) st = "SHAKING";
      }
      // 유속 비율 판정 (단기 vs 장기)
      if (st === "OK" && s.buf.length > SHORT_WINDOW) {
        const n = s.buf.length;
        const shortRate = (s.buf[n - 1 - SHORT_WINDOW] - s.buf[n - 1]) / (SHORT_WINDOW * SAMPLE_MS / 1000);
        const base = s.buf.length > LONG_WINDOW
          ? (s.buf[0] - s.buf[n - 1]) / ((n - 1) * SAMPLE_MS / 1000)
          : s.flowRate / 3600;
        if (base > 0.001) {
          const ratio = shortRate / base;
          if (ratio > FAST_RATIO) st = "FAST";
          else if (ratio < SLOW_RATIO) st = "SLOW";
        }
      }
      setStatus(st);
      setWeight(w);
      setFluidPct(Math.round(pctOf(s.fluid)));

      // 차트 렌더
      const cw = chart.width, ch = chart.height;
      ctx.clearRect(0, 0, cw, ch);
      ctx.strokeStyle = "#2e3540";
      ctx.lineWidth = 1;
      for (let gy = 1; gy < 4; gy++) {
        ctx.beginPath(); ctx.moveTo(0, (ch / 4) * gy); ctx.lineTo(cw, (ch / 4) * gy); ctx.stroke();
      }
      if (samples.length > 1) {
        const mn = Math.min(...samples) - 1.5, mx = Math.max(...samples) + 1.5;
        ctx.strokeStyle = st === "SHAKING" ? "#f59e0b" : "#38bdf8";
        ctx.lineWidth = 2;
        ctx.beginPath();
        samples.forEach((v, i) => {
          const x = (i / 59) * cw;
          const y = ch - ((v - mn) / (mx - mn)) * (ch - 10) - 5;
          i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        });
        ctx.stroke();
      }
    }, SAMPLE_MS);

    const pctOf = (f) => (f / 500) * 100;

    const onResize = () => {
      const w2 = mount.clientWidth, h2 = mount.clientHeight;
      camera.aspect = w2 / h2;
      camera.updateProjectionMatrix();
      renderer.setSize(w2, h2);
    };
    window.addEventListener("resize", onResize);

    return () => {
      cancelAnimationFrame(raf);
      clearInterval(sampleTimer);
      window.removeEventListener("resize", onResize);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      dom.removeEventListener("pointerdown", onDown);
      dom.removeEventListener("wheel", onWheel);
      renderer.dispose();
      mount.removeChild(dom);
    };
  }, []);

  const shake = (strength) => {
    const s = stateRef.current;
    s.omX += (Math.random() - 0.5) * strength * 2;
    s.omZ += (Math.random() - 0.5) * strength * 2;
  };
  const refill = () => { stateRef.current.fluid = 500; };

  const badge =
    status === "SHAKING" ? "bg-amber-500 text-amber-950"
    : status === "FAST" ? "bg-red-500 text-white"
    : status === "SLOW" ? "bg-orange-500 text-white"
    : "bg-emerald-500 text-emerald-950";

  return (
    <div className="w-full h-screen flex flex-col bg-slate-900 text-slate-100 font-sans">
      <div className="px-4 py-2 flex items-center gap-3 border-b border-slate-700 text-sm">
        <span className="font-medium">IoT-PIMS 가상 기기 뷰어</span>
        <span className="text-slate-400 text-xs">드래그: 회전 · 휠: 줌</span>
        <span className={`ml-auto px-2.5 py-0.5 rounded text-xs font-medium ${badge}`}>{status}</span>
      </div>

      <div className="flex-1 flex min-h-0">
        <div ref={mountRef} className="flex-1 min-w-0" />

        <div className="w-64 shrink-0 border-l border-slate-700 p-3 flex flex-col gap-3 text-sm overflow-y-auto">
          <div className="bg-slate-800 rounded-lg p-3">
            <div className="text-xs text-slate-400">로드셀 측정값</div>
            <div className="text-2xl font-mono">{weight.toFixed(1)} g</div>
            <div className="text-xs text-slate-400 mt-1">잔량 {fluidPct}%</div>
            <div className="mt-1 h-1.5 bg-slate-700 rounded">
              <div className="h-1.5 bg-sky-400 rounded" style={{ width: `${fluidPct}%` }} />
            </div>
          </div>

          <div className="bg-slate-800 rounded-lg p-3">
            <div className="text-xs text-slate-400 mb-1">무게 시계열</div>
            <canvas ref={chartRef} width={224} height={90} className="w-full rounded" />
          </div>

          <div className="flex flex-col gap-2">
            <button onClick={() => shake(2.2)}
              className="w-full py-2 rounded-lg bg-amber-500 hover:bg-amber-400 text-amber-950 font-medium">
              흔들기 (약)
            </button>
            <button onClick={() => shake(5)}
              className="w-full py-2 rounded-lg bg-red-500 hover:bg-red-400 text-white font-medium">
              흔들기 (강)
            </button>
            <button onClick={refill}
              className="w-full py-2 rounded-lg bg-slate-700 hover:bg-slate-600">
              수액 교체 (리필)
            </button>
          </div>

          <div>
            <div className="flex justify-between text-xs text-slate-400 mb-1">
              <span>설정 유속</span><span className="font-mono text-slate-200">{flowRate} mL/h</span>
            </div>
            <input type="range" min="30" max="600" step="10" value={flowRate}
              onChange={(e) => setFlowRate(Number(e.target.value))} className="w-full" />
          </div>

          <label className="flex items-center gap-2 text-xs text-slate-300">
            <input type="checkbox" checked={autoRotate}
              onChange={(e) => setAutoRotate(e.target.checked)} />
            카메라 자동 회전
          </label>

          <div className="text-xs text-slate-500 leading-relaxed mt-auto">
            흔들림 판정: 최근 {SHAKE_WINDOW}샘플 max−min &gt; {SHAKE_THRESHOLD_G}g
            (flow_rate_monitor.h 동일 로직)
          </div>
        </div>
      </div>
    </div>
  );
}
