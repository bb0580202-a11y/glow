# v3 摄像头手部追踪 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans 逐任务实现。Steps 用 checkbox(`- [ ]`)跟踪。

**Goal:** 用摄像头追踪手心位置控制萤火吸引,作为可选开关接到现有 InputSource 接口上,粒子系统/外壳不改动。

**Architecture:** 全屏 `<video>`(镜像,压暗)作背景层 + 透明粒子画布(不变)+「开启摄像头」开关。`CameraInput` 懒加载本地 `@mediapipe/tasks-vision` 的 HandLandmarker,每帧取手心关键点映射为吸引点 `{x,y,active}`,与 PointerInput 可互换。MediaPipe 资源本地打包(不走 CDN)。

**Tech Stack:** 原生 HTML + Canvas 2D + `@mediapipe/tasks-vision`(HandLandmarker,本地动态 import)。

> **测试说明:** 摄像头需 HTTPS/localhost。验收在本机 `python -m http.server` 走 `http://localhost:PORT` 进行,由项目所有者用真实摄像头确认;执行 agent 无法做视觉/摄像头验收。

---

### Task 0: 获取并提交 MediaPipe 资源到 vendor/

把 wasm 运行时、JS 模块、手部模型下载进仓库。**这是预计可能卡住的一步**(模型在 Google 存储,国内可能需镜像或手动下)。

**Files:**
- Create: `vendor/tasks-vision/vision_bundle.mjs`, `vendor/tasks-vision/wasm/*`, `vendor/hand_landmarker.task`
- Modify: `.gitignore`(确保不忽略 vendor)

- [ ] **Step 1: 下载 tasks-vision 包并取出 JS + wasm**

Run:
```bash
cd /Users/bb/Documents/cursor_practice/glow
npm pack @mediapipe/tasks-vision 2>&1 | tail -1
tar -xzf mediapipe-tasks-vision-*.tgz
mkdir -p vendor/tasks-vision
cp package/vision_bundle.mjs vendor/tasks-vision/
cp -r package/wasm vendor/tasks-vision/wasm
rm -rf package mediapipe-tasks-vision-*.tgz
ls -la vendor/tasks-vision vendor/tasks-vision/wasm | head
```
Expected: `vision_bundle.mjs` 与 `wasm/`(含 `.wasm`/`.js` 文件)就位。

- [ ] **Step 2: 下载手部模型(含镜像回退)**

Run(先试 Google 官方,失败再试 hf-mirror 镜像;两者都失败则人工下载):
```bash
cd /Users/bb/Documents/cursor_practice/glow
URL_OFFICIAL="https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
curl -fL --connect-timeout 15 -o vendor/hand_landmarker.task "$URL_OFFICIAL" \
  || curl -fL --connect-timeout 15 -o vendor/hand_landmarker.task \
     "https://hf-mirror.com/qualcomm/MediaPipe-Hand-Detection/resolve/main/hand_landmarker.task"
ls -la vendor/hand_landmarker.task
file vendor/hand_landmarker.task
```
Expected:文件存在且大小数 MB(不是几百字节的报错页)。
**若两个都失败:** 停下,告诉用户从 `$URL_OFFICIAL` 手动下载 `hand_landmarker.task` 放到 `vendor/`(可能需梯子),再继续。

- [ ] **Step 3: 确认 .gitignore 不排除 vendor,提交**

Run:
```bash
cd /Users/bb/Documents/cursor_practice/glow
grep -q vendor .gitignore && echo "警告:vendor 被忽略,需处理" || echo "vendor 未被忽略,OK"
du -sh vendor
git add vendor && git commit -m "chore: 本地打包 MediaPipe tasks-vision 资源(不走 CDN)" 2>&1 | tail -2
```
Expected:vendor 入库,提交成功。

---

### Task 1: 摄像头画面上屏(video + 蒙版 + 开关按钮)

先只把摄像头画面显示出来(还不做手追踪),验证分层、镜像、开关、压暗都对。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 加 DOM 元素(在 `<canvas id="c">` 前后)**

把 `<body>` 内的 `<canvas id="c"></canvas>` 替换为:
```html
<video id="cam" playsinline muted></video>
<div id="scrim"></div>
<canvas id="c"></canvas>
<button id="camBtn">开启摄像头</button>
```

- [ ] **Step 2: 加 CSS(在 `<style>` 内 canvas 规则之后)**

```css
  #cam, #scrim, canvas { position: fixed; inset: 0; width: 100%; height: 100%; }
  #cam { object-fit: cover; transform: scaleX(-1); z-index: 0; display: none; }
  #scrim { background: rgba(0,0,0,0.45); z-index: 1; display: none; }
  canvas { z-index: 2; }
  #camBtn {
    position: fixed; left: 16px; bottom: 16px; z-index: 3;
    background: rgba(255,255,255,0.08); color: #FFF6E0;
    border: 1px solid rgba(255,255,255,0.2); border-radius: 999px;
    padding: 8px 16px; font-size: 13px; cursor: pointer;
    backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px);
  }
  #camBtn:hover { background: rgba(255,255,255,0.15); }
```

- [ ] **Step 3: 加临时按钮逻辑(仅开画面,下个任务接手追踪)**

在 `index.html` 脚本末尾(`requestAnimationFrame(frame);` 之后)加:
```javascript
const camEl = document.getElementById('cam');
const scrimEl = document.getElementById('scrim');
const camBtn = document.getElementById('camBtn');
let camStream = null;

async function enableCamera() {
  camStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } });
  camEl.srcObject = camStream;
  await camEl.play();
  camEl.style.display = 'block';
  scrimEl.style.display = 'block';
}
function disableCamera() {
  if (camStream) { camStream.getTracks().forEach(t => t.stop()); camStream = null; }
  camEl.style.display = 'none';
  scrimEl.style.display = 'none';
}
camBtn.addEventListener('click', async () => {
  if (camStream) { disableCamera(); camBtn.textContent = '开启摄像头'; return; }
  camBtn.disabled = true; camBtn.textContent = '启动中…';
  try {
    await enableCamera();
    camBtn.textContent = '关闭摄像头';
  } catch (e) {
    alert('摄像头开启失败:' + e.message + '\n(需 HTTPS 或 localhost;file:// 不支持)');
    camBtn.textContent = '开启摄像头';
  } finally { camBtn.disabled = false; }
});
```

- [ ] **Step 4: 浏览器验收(localhost)**

Run:
```bash
cd /Users/bb/Documents/cursor_practice/glow && python3 -m http.server 8080
```
浏览器开 `http://localhost:8080/`。点「开启摄像头」→ 授权 → 应看到**镜像的、被压暗的摄像头画面**在萤火后面;萤火照常漂浮(此时手还不能控制)。点「关闭摄像头」→ 画面消失、回纯黑。控制台无报错。

- [ ] **Step 5: Commit**

```bash
git add index.html && git commit -m "feat: 摄像头画面层 + 开关按钮(暂不含手追踪)"
```

---

### Task 2: 手部追踪吸引(CameraInput 接入)

加 `CameraInput`(懒加载 HandLandmarker),开摄像头时把活动输入从鼠标切到摄像头,手心吸引萤火。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: CONFIG 加手部宽限参数**

在 CONFIG 内 `attractForce` 行后加:
```javascript
  handGrace: 250,        // 手短暂丢失的宽限毫秒(防 active 闪烁)
```

- [ ] **Step 2: 在 PointerInput 类之后、FireflyTheme 之前,把原"摄像头留白注释"替换为 CameraInput 类**

删掉那段 `// 【留白·摄像头】...` 注释,替换为:
```javascript
// CameraInput:实现 InputSource 接口,与 PointerInput 可互换。懒加载本地 MediaPipe。
class CameraInput {
  constructor(videoEl) {
    this.video = videoEl;
    this.x = 0; this.y = 0; this.active = false;
    this.landmarker = null;
    this.lastSeen = -Infinity;
    this.lastVideoTime = -1;
  }
  async start() {
    const { FilesetResolver, HandLandmarker } =
      await import('./vendor/tasks-vision/vision_bundle.mjs');
    const fileset = await FilesetResolver.forVisionTasks('./vendor/tasks-vision/wasm');
    this.landmarker = await HandLandmarker.createFromOptions(fileset, {
      baseOptions: { modelAssetPath: './vendor/hand_landmarker.task' },
      runningMode: 'VIDEO',
      numHands: 1
    });
    const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } });
    this.stream = stream;
    this.video.srcObject = stream;
    await this.video.play();
  }
  stop() {
    if (this.stream) { this.stream.getTracks().forEach(t => t.stop()); this.stream = null; }
    this.active = false;
  }
  detect(now, w, h) {
    if (!this.landmarker || this.video.readyState < 2) return;
    if (this.video.currentTime === this.lastVideoTime) return;
    this.lastVideoTime = this.video.currentTime;
    const res = this.landmarker.detectForVideo(this.video, now);
    if (res.landmarks && res.landmarks.length > 0) {
      const palm = res.landmarks[0][9]; // 中指根 ≈ 手心,比指尖稳
      this.x = (1 - palm.x) * w;        // X 镜像(自拍视角)
      this.y = palm.y * h;
      this.lastSeen = now;
      this.active = true;
      // 【留白·手势】此处可从 res.landmarks[0] 的 21 点算 张手/握拳/捏合,
      //   给下面 get() 返回的对象加 mode 字段,Theme 按需读取(本期不读)。
    } else if (now - this.lastSeen > CONFIG.handGrace) {
      this.active = false;
    }
  }
  get() { return { x: this.x, y: this.y, active: this.active }; }
}
```

- [ ] **Step 3: 用 CameraInput 改写 Task 1 的按钮逻辑,并切换活动输入**

把 Task 1 Step 3 加的整段(从 `const camEl = ...` 到按钮 click 监听结束)替换为:
```javascript
const camEl = document.getElementById('cam');
const scrimEl = document.getElementById('scrim');
const camBtn = document.getElementById('camBtn');
const cameraInput = new CameraInput(camEl);
let cameraOn = false;

camBtn.addEventListener('click', async () => {
  if (cameraOn) {
    cameraInput.stop();
    camEl.style.display = 'none';
    scrimEl.style.display = 'none';
    activeInput = pointerInput;
    cameraOn = false;
    camBtn.textContent = '开启摄像头';
    return;
  }
  camBtn.disabled = true; camBtn.textContent = '启动中…';
  try {
    await cameraInput.start();
    camEl.style.display = 'block';
    scrimEl.style.display = 'block';
    activeInput = cameraInput;
    cameraOn = true;
    camBtn.textContent = '关闭摄像头';
  } catch (e) {
    alert('摄像头开启失败:' + e.message + '\n(需 HTTPS 或 localhost;file:// 不支持)');
    camBtn.textContent = '开启摄像头';
  } finally { camBtn.disabled = false; }
});
```

- [ ] **Step 4: 把固定的 input 改成可切换的 activeInput,并在 frame 里调 detect**

把 `const input = new PointerInput(canvas);` 改为:
```javascript
const pointerInput = new PointerInput(canvas);
let activeInput = pointerInput;
```
把 frame 内 `const point = input.get();` 替换为:
```javascript
  if (activeInput.detect) activeInput.detect(now, W, H);
  const point = activeInput.get();
```

- [ ] **Step 5: 浏览器验收(localhost)**

`http://localhost:8080/` 刷新。点「开启摄像头」授权后:**手在画面里移动 → 附近萤火被手心吸引、跟随**;手移出画面 → 萤火散回。关闭 → 回鼠标版。控制台无报错。
(首次点按钮会加载本地模型,可能有 1–2 秒延迟,正常。)

- [ ] **Step 6: Commit**

```bash
git add index.html && git commit -m "feat: CameraInput 手部追踪吸引(可选开关,本地 MediaPipe)"
```

---

### Task 2.5: 手势(张手推散 / 握拳强聚)

从 21 关键点算手势,写入 `point.mode`,FireflyTheme 据此改吸引力方向/强度。带 EMA 平滑 + 三段空带防抖。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: CONFIG 加手势参数**

在 `handGrace` 行后加:
```javascript
  attractForceStrong: 1.4,   // 握拳:强聚
  repelForce: 0.9,           // 张手:推散
  openThreshold: 1.6,        // 展开度 > 此 → 推散
  fistThreshold: 1.0,        // 展开度 < 此 → 强聚
```

- [ ] **Step 2: CameraInput.detect 内计算 mode(在设置 this.active=true 的块内、留白注释处)**

把 detect 内 `this.active = true;` 之后、`// 【留白·手势】` 注释整段替换为:
```javascript
      this.active = true;
      const lm = res.landmarks[0];
      const scale = Math.hypot(lm[0].x - lm[9].x, lm[0].y - lm[9].y) || 1e-6;
      const tips = [8, 12, 16, 20];
      let sum = 0;
      for (const t of tips) sum += Math.hypot(lm[t].x - lm[9].x, lm[t].y - lm[9].y);
      const openRaw = (sum / tips.length) / scale;
      this.openness = (this.openness == null) ? openRaw : this.openness * 0.7 + openRaw * 0.3;
      if (this.openness > CONFIG.openThreshold) this.mode = 'repel';
      else if (this.openness < CONFIG.fistThreshold) this.mode = 'attract';
      else this.mode = 'neutral';
      // 【留白·捏合】可加 拇指(4)-食指(8) 距离 → 更精细牵引(后续)
```
并在构造函数里初始化:把 `this.lastVideoTime = -1;` 后加 `this.openness = null; this.mode = 'neutral';`
并把 `get()` 改为:`return { x: this.x, y: this.y, active: this.active, mode: this.mode };`

- [ ] **Step 3: FireflyTheme.update 读 mode,改吸引逻辑**

把 update 内吸引块替换为:
```javascript
      if (point.active) {
        const dx = point.x - p.x, dy = point.y - p.y;
        const dist = Math.hypot(dx, dy);
        if (dist < CONFIG.attractRadius && dist > 0.001) {
          const falloff = (1 - dist / CONFIG.attractRadius) * dt;
          const dirx = dx / dist, diry = dy / dist;
          if (point.mode === 'repel') {
            const f = CONFIG.repelForce * falloff;
            p.vx -= dirx * f; p.vy -= diry * f;
          } else {
            const f = (point.mode === 'attract' ? CONFIG.attractForceStrong : CONFIG.attractForce) * falloff;
            p.vx += dirx * f; p.vy += diry * f;
          }
        }
      }
```

- [ ] **Step 4: 加一个极简模式读出(便于验收/调阈值)**

在 `<button id="camBtn">` 后加 `<div id="camMode"></div>`;CSS 加:
```css
  #camMode { position: fixed; right: 16px; bottom: 16px; z-index: 3;
    color: rgba(255,246,224,0.6); font-size: 12px; font-family: monospace; }
```
在 frame 末尾(`requestAnimationFrame(frame);` 前)加:
```javascript
  if (cameraOn) document.getElementById('camMode').textContent =
    activeInput.mode === 'repel' ? '散' : activeInput.mode === 'attract' ? '聚' : '·';
```

- [ ] **Step 5: 浏览器验收(localhost)**

`http://localhost:8080/` 刷新,开摄像头:**张开手掌 → 萤火被推散**(右下角显示"散");**握拳 → 萤火紧聚向手心**(显示"聚");平手 → 轻吸(显示"·")。手势切换跟手、不乱抖。
若识别不准 → 调 `openThreshold`/`fistThreshold`(看右下角读出与实际手对不对)。

- [ ] **Step 6: Commit**

```bash
git add index.html docs && git commit -m "feat: 手势 张手推散/握拳强聚(关键点计算,无额外ML)"
```

---

### Task 3: 健壮性与收尾

错误回落、file:// 友好提示、暗蒙版调参确认。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 验收错误路径(无新代码,确认 Task 2 的 catch 生效)**

在 localhost 下:点开摄像头时**拒绝授权** → 应弹出友好提示且按钮回到「开启摄像头」、鼠标输入仍可用(移动鼠标萤火被吸引)。
双击本地 `index.html`(file://)→ 鼠标版正常;点「开启摄像头」→ 弹出"需 HTTPS 或 localhost"提示,页面不崩。

- [ ] **Step 2: 按手感确认/微调暗蒙版**

若开摄像头后光点不够跳脱 → 调 CSS `#scrim` 的 `rgba(0,0,0,0.45)` 透明度(调高更暗、光点更明显);若实景太黑看不清环境 → 调低。改完刷新对比。

- [ ] **Step 3: Commit(若有调整)**

```bash
git add index.html && git commit -m "tune: 摄像头暗蒙版手感微调"
```

---

## 完成标准(v3 DoD)

- 本机 localhost 下,点按钮可开/关摄像头;开后镜像压暗画面在粒子后,手心移动吸引萤火、移开散回。
- 拒绝授权/无摄像头/file:// 均有友好回落,不崩。
- MediaPipe 资源全本地(不碰 CDN);双击 file:// 鼠标版仍正常。
- 代码保留手势留白注释,后续接手势不改外壳。

## 后续(不在 v3)

- 手势(张手/握拳/捏合)、光点颜色按环境亮度自适应、HTTPS 公网托管(手机/分享)、坐标裁剪校正。
