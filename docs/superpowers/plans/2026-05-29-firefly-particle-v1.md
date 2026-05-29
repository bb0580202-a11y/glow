# 暖光萤火粒子 v1 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 单个 HTML 文件,深暮色全屏画布上漂浮一群暖光萤火,鼠标/触摸作为"吸引点"把附近萤火捧起聚拢、移开后散回。

**Architecture:** 单文件三段式 —— 通用外壳 `ParticleSystem`(持有粒子+主循环)+ 可插拔 `InputSource`(v1=PointerInput)+ 可插拔 `Theme`(v1=FireflyTheme)。外壳不关心吸引点来自鼠标还是摄像头,也不关心意境是萤火还是星空;换输入/换主题都只是替换接口实现。为后续摄像头(CameraInput)和星空(StarryNightTheme)预留接口。

**Tech Stack:** 原生 HTML + Canvas 2D + Pointer Events,无构建、无依赖、无 CDN。

> **测试说明(重要):** 本项目无自动化测试框架(刻意保持单文件无构建)。每个任务的验收 = 在浏览器中用眼睛/操作确认的**具体观察步骤**。这些步骤需由人(项目所有者)在真实浏览器/手机上执行确认——执行 agent 无法替代视觉验收,只能确认代码无报错。

---

### Task 0: Git 初始化

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: 初始化仓库**

Run:
```bash
cd /Users/bb/Documents/cursor_practice/glow && git init
```
Expected: `Initialized empty Git repository`

- [ ] **Step 2: 写 .gitignore**

`.gitignore`:
```
.DS_Store
```

- [ ] **Step 3: 提交已有设计/计划文档**

```bash
git add docs .gitignore
git commit -m "docs: 初始设计与实现计划"
```

---

### Task 1: 全屏画布骨架 + 渲染循环

建立 `index.html`:深底全屏 canvas、随窗口自适应、考虑高分屏 DPR、空转的 requestAnimationFrame 循环。

**Files:**
- Create: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 写骨架与循环**

`index.html`:
```html
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>萤 · 暖光粒子</title>
<style>
  html, body { margin: 0; height: 100%; overflow: hidden; background: #16121F; }
  canvas { display: block; touch-action: none; }
</style>
</head>
<body>
<canvas id="c"></canvas>
<script>
"use strict";

const CONFIG = {
  bgColor: '#16121F',
  countFor(w) { return w < 640 ? 90 : 180; },
  colorStops: ['#FFD79A', '#F4A65A', '#FFC078'],
  sizeMin: 1.5, sizeMax: 4,
  drift: 0.15, damping: 0.96,
  attractRadius: 220, attractForce: 0.6,
  breathSpeed: 0.004, glowScale: 4,
};

const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
let W = 0, H = 0, DPR = 1;

function resize() {
  DPR = Math.min(window.devicePixelRatio || 1, 2);
  W = window.innerWidth; H = window.innerHeight;
  canvas.width = W * DPR; canvas.height = H * DPR;
  canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
}
window.addEventListener('resize', resize);
resize();

let last = performance.now();
function frame(now) {
  const dt = Math.min((now - last) / 16.67, 3);
  last = now;
  ctx.globalCompositeOperation = 'source-over';
  ctx.fillStyle = CONFIG.bgColor;
  ctx.fillRect(0, 0, W, H);
  // 后续任务在此插入 update + draw
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
</script>
</body>
</html>
```

- [ ] **Step 2: 浏览器验收**

操作:双击 `index.html` 在 Chrome 打开。
预期:整屏铺满深暮色(#16121F),无滚动条、无白边;缩放窗口时画布跟着变、不留白。控制台无报错。

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: 全屏深底画布骨架与渲染循环"
```

---

### Task 2: 粒子与自由漂浮(暂无吸引、暂无发光)

加入 `Particle` 与 `ParticleSystem`,以及一个临时的简易绘制(实心点),先看到粒子在漂。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 在 CONFIG 之后、canvas 取得之前插入 Particle 与 ParticleSystem 类**

```javascript
class Particle {
  constructor(w, h) { this.reset(w, h); }
  reset(w, h) {
    this.x = Math.random() * w;
    this.y = Math.random() * h;
    this.vx = (Math.random() - 0.5) * 0.3;
    this.vy = (Math.random() - 0.5) * 0.3;
    this.size = CONFIG.sizeMin + Math.random() * (CONFIG.sizeMax - CONFIG.sizeMin);
    this.color = CONFIG.colorStops[(Math.random() * CONFIG.colorStops.length) | 0];
    this.phase = Math.random() * Math.PI * 2;
    this.baseAlpha = 0.5 + Math.random() * 0.5;
  }
}

class ParticleSystem {
  constructor() { this.particles = []; }
  init(w, h) {
    this.particles = [];
    const n = CONFIG.countFor(w);
    for (let i = 0; i < n; i++) this.particles.push(new Particle(w, h));
  }
}
```

- [ ] **Step 2: 在 resize() 定义之后创建系统并初始化**

在 `resize(); ` 这一行**之后**加入:
```javascript
const system = new ParticleSystem();
system.init(W, H);
```

- [ ] **Step 3: 临时简易运动+绘制(下个任务会被 Theme 取代)**

把 `frame` 里 `// 后续任务...` 那一行替换为:
```javascript
  for (const p of system.particles) {
    p.vx += (Math.random() - 0.5) * CONFIG.drift * dt;
    p.vy += (Math.random() - 0.5) * CONFIG.drift * dt;
    p.vx *= CONFIG.damping; p.vy *= CONFIG.damping;
    p.x += p.vx * dt; p.y += p.vy * dt;
    if (p.x < 0) p.x += W; if (p.x > W) p.x -= W;
    if (p.y < 0) p.y += H; if (p.y > H) p.y -= H;
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
    ctx.fill();
  }
```

- [ ] **Step 4: 浏览器验收**

操作:刷新页面。
预期:深底上出现约 180 个暖色小点(手机宽度下约 90 个),各自缓慢、无规律地漂浮,移出边缘从另一侧绕回。控制台无报错。

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: 粒子系统与自由漂浮"
```

---

### Task 3: 发光渲染(夜光感的关键)

用径向渐变 + `globalCompositeOperation='lighter'` 让粒子发暖光、重叠处更亮,并加入呼吸闪烁。把临时绘制升级为发光绘制。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 在 Particle 类之前加入颜色辅助函数**

```javascript
function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return `rgba(${r},${g},${b},${a})`;
}
```

- [ ] **Step 2: 用发光绘制替换 Task 2 Step 3 的整段 for 循环**

把 frame 里那段 for 循环替换为:
```javascript
  // 更新
  for (const p of system.particles) {
    p.vx += (Math.random() - 0.5) * CONFIG.drift * dt;
    p.vy += (Math.random() - 0.5) * CONFIG.drift * dt;
    p.vx *= CONFIG.damping; p.vy *= CONFIG.damping;
    p.x += p.vx * dt; p.y += p.vy * dt;
    if (p.x < 0) p.x += W; if (p.x > W) p.x -= W;
    if (p.y < 0) p.y += H; if (p.y > H) p.y -= H;
    p.phase += CONFIG.breathSpeed * dt * 16.67;
  }
  // 发光绘制
  ctx.globalCompositeOperation = 'lighter';
  for (const p of system.particles) {
    const breath = 0.6 + 0.4 * Math.sin(p.phase);
    const alpha = p.baseAlpha * breath;
    const radius = p.size * CONFIG.glowScale;
    const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
    g.addColorStop(0, hexA(p.color, alpha));
    g.addColorStop(1, hexA(p.color, 0));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalCompositeOperation = 'source-over';
```

- [ ] **Step 3: 浏览器验收**

操作:刷新页面。
预期:小点变成柔和的发光暖光斑,边缘羽化无硬边;轻微明暗呼吸;两个光斑靠近重叠处更亮(萤火夜光感)。控制台无报错。

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: 发光渲染与呼吸闪烁"
```

---

### Task 4: InputSource 接口 + PointerInput

抽出"吸引点来源"接口,实现鼠标/触摸板/触屏统一的 PointerInput。本任务只接入并打印吸引点,不改粒子行为,便于单独验证输入逻辑。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 在 ParticleSystem 类之后加入 PointerInput 类**

```javascript
// InputSource 接口约定:get() -> { x, y, active }
//   active=false 表示当前无吸引点(手机松手 / 桌面光标离开 / 摄像头未识别到手)
class PointerInput {
  constructor(el) {
    this.x = 0; this.y = 0; this.active = false;
    el.addEventListener('pointermove', (e) => {
      this.x = e.clientX; this.y = e.clientY;
      if (e.pointerType !== 'touch') this.active = true;
    });
    el.addEventListener('pointerdown', (e) => {
      this.x = e.clientX; this.y = e.clientY; this.active = true;
    });
    el.addEventListener('pointerup', (e) => {
      if (e.pointerType === 'touch') this.active = false;
    });
    el.addEventListener('pointercancel', () => { this.active = false; });
    el.addEventListener('pointerleave', (e) => {
      if (e.pointerType !== 'touch') this.active = false;
    });
  }
  get() { return { x: this.x, y: this.y, active: this.active }; }
}
```

- [ ] **Step 2: 在 system.init(W, H) 之后创建输入源**

```javascript
const input = new PointerInput(canvas);
```

- [ ] **Step 3: 临时在循环里读取并打印(下个任务移除打印)**

在 frame 内 `const dt = ...` 之后加入:
```javascript
  const point = input.get();
  if (point.active && (now | 0) % 30 === 0) console.log('point', point.x | 0, point.y | 0);
```

- [ ] **Step 4: 浏览器验收**

操作:刷新,打开控制台。桌面:移动鼠标 → 看到坐标打印;鼠标移出窗口 → 打印停止(active 变 false)。手机/触屏模拟:按住拖动 → 打印;松手 → 停止。
预期:坐标随指针更新;桌面 hover 即 active,触摸需按住才 active。无报错。

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: PointerInput 输入源(鼠标/触摸板/触屏)"
```

---

### Task 5: Theme 接口 + FireflyTheme(接入吸引)

把"运动+绘制"抽成 Theme 接口,FireflyTheme 实现自由漂浮 + 吸引点聚拢。外壳通过接口调用,验证两个留白接口协同工作。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 在 PointerInput 类之后加入 FireflyTheme**

```javascript
// Theme 接口约定:init(particles, cfg) / update(particles, point, dt, time, w, h) / draw(ctx, particles, cfg)
const FireflyTheme = {
  init(particles, cfg) { /* 颜色与初态已在 Particle 构造时设置 */ },
  update(particles, point, dt, time, w, h) {
    for (const p of particles) {
      p.vx += (Math.random() - 0.5) * CONFIG.drift * dt;
      p.vy += (Math.random() - 0.5) * CONFIG.drift * dt;
      if (point.active) {
        const dx = point.x - p.x, dy = point.y - p.y;
        const dist = Math.hypot(dx, dy);
        if (dist < CONFIG.attractRadius && dist > 0.001) {
          const f = CONFIG.attractForce * (1 - dist / CONFIG.attractRadius) * dt;
          p.vx += (dx / dist) * f;
          p.vy += (dy / dist) * f;
        }
      }
      p.vx *= CONFIG.damping; p.vy *= CONFIG.damping;
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (p.x < 0) p.x += w; if (p.x > w) p.x -= w;
      if (p.y < 0) p.y += h; if (p.y > h) p.y -= h;
      p.phase += CONFIG.breathSpeed * dt * 16.67;
    }
  },
  draw(ctx, particles, cfg) {
    ctx.globalCompositeOperation = 'lighter';
    for (const p of particles) {
      const breath = 0.6 + 0.4 * Math.sin(p.phase);
      const alpha = p.baseAlpha * breath;
      const radius = p.size * cfg.glowScale;
      const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
      g.addColorStop(0, hexA(p.color, alpha));
      g.addColorStop(1, hexA(p.color, 0));
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalCompositeOperation = 'source-over';
  }
};
```

- [ ] **Step 2: 加入主题注册表 + URL 参数选择(留白:以后加 starrynight 即可)**

在 `const input = new PointerInput(canvas);` 之后加入:
```javascript
const THEMES = { firefly: FireflyTheme };
const requested = new URLSearchParams(location.search).get('theme');
const theme = THEMES[requested] || FireflyTheme;
theme.init(system.particles, CONFIG);
```

- [ ] **Step 3: 用接口调用替换 frame 内的更新+绘制+临时打印**

把 frame 内从 `const point = input.get();` 起、到那段发光绘制 `ctx.globalCompositeOperation = 'source-over';` 为止的所有临时代码,整体替换为:
```javascript
  const point = input.get();
  theme.update(system.particles, point, dt, now, W, H);
  theme.draw(ctx, system.particles, CONFIG);
```

- [ ] **Step 4: 浏览器验收(核心手感)**

操作:刷新。桌面移动光标到粒子群中;手机按住屏幕拖动。
预期:吸引半径(~220px)内的萤火被温柔吸向指针、聚成一小团且更亮;指针移开/手机松手后,萤火慢慢散回自由漂浮。聚拢柔和不生硬、不抖。无报错。

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: Theme 接口与 FireflyTheme 吸引互动"
```

---

### Task 6: 留白接口的占位注释(摄像头 / 星空)

不实现功能,只在代码中留清晰的扩展锚点与接口说明,确保后续接入零改动外壳。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`

- [ ] **Step 1: 在 PointerInput 类之后加入摄像头留白注释**

```javascript
// 【留白·摄像头】未来实现 CameraInput,同样提供 get() -> {x,y,active}:
//   用 MediaPipe Hands 取手心坐标 → 归一化到画布坐标;未识别到手时 active=false。
//   MediaPipe 资源需下载到本地与本文件同目录(不走 CDN);摄像头需 HTTPS,故需托管运行。
//   接入时只需:const input = new CameraInput(canvas); 其余代码不变。
```

- [ ] **Step 2: 在 FireflyTheme 之后加入星空/水波留白注释**

```javascript
// 【留白·主题】未来实现 StarryNightTheme(梵高星空,曲线噪声流场 curl noise)
//   与 RippleTheme(水波,波函数)。实现 init/update/draw 后注册到 THEMES 即可:
//   THEMES.starrynight = StarryNightTheme;  通过 ?theme=starrynight 切换。
```

- [ ] **Step 3: 浏览器验收**

操作:刷新。
预期:行为与 Task 5 完全一致(纯注释,无功能变化)。无报错。

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "docs: 摄像头与星空主题的扩展留白注释"
```

---

### Task 7: 手机真机走查与参数微调

在真实手机上验收,并据手感微调 CONFIG。本任务无固定代码,产出是确认 + 可能的数值调整。

**Files:**
- Modify: `/Users/bb/Documents/cursor_practice/glow/index.html`(仅 CONFIG 数值,按需)

- [ ] **Step 1: 局部起 HTTPS/HTTP 服务以便手机访问(可选,仅为同局域网真机预览)**

Run:
```bash
cd /Users/bb/Documents/cursor_practice/glow && python3 -m http.server 8080
```
然后手机与电脑同 Wi-Fi,手机浏览器访问 `http://<电脑局域网IP>:8080/`。
(注:此为纯触摸版预览,不涉及摄像头,故 HTTP 即可。)

- [ ] **Step 2: 手机验收清单**

逐项确认:
- 手指按住跟手吸引、松手散回。
- 页面不被手指拖动/缩放(`touch-action:none` + viewport 生效)。
- 帧率流畅不卡。
- 横竖屏切换后画布正确自适应、不模糊不变形。

- [ ] **Step 3: 按手感微调 CONFIG(如有需要)**

可调:`attractRadius`(吸引范围)、`attractForce`(吸力强弱)、`damping`(黏滞感)、`count`/`countFor`(密度)、`glowScale`(光晕大小)、`breathSpeed`(呼吸快慢)。
改完刷新对比,满意为止。

- [ ] **Step 4: Commit(若有调整)**

```bash
git add index.html
git commit -m "tune: 按真机手感微调粒子参数"
```

---

## 完成标准(v1 Definition of Done)

- 双击 `index.html` 即可在桌面浏览器游玩(无需服务器)。
- 深暮色底上暖光萤火自然漂浮、呼吸发光、重叠更亮。
- 鼠标/触摸板/触屏作为吸引点:聚拢柔和、松开散回,桌面 hover 即响应、手机按住才响应。
- 手机真机流畅、页面不被手势干扰。
- 代码含 InputSource / Theme 两个清晰接口 + 摄像头/星空留白注释,后续扩展不动外壳。

## 后续(不在 v1)

- v2:StarryNightTheme(流场)。
- v3:CameraInput(MediaPipe 本地打包)+ 国内静态托管(艾可秀)链接分享。
