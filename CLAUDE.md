# CLAUDE.md

本文件指导 AI 在本仓库工作。详细设计见 `docs/superpowers/`,玩法见 `README.md`。

## 这是什么

`glow` —— 全屏网页互动粒子(暖光萤火)。**单个 `index.html`,原生 Canvas 2D,无构建、无依赖、无 npm**。直接编辑 `index.html` 即可,改完刷新浏览器。

## 关键约定

- **所有可调参数集中在 `index.html` 顶部的 `CONFIG`**(粒子数、颜色、物理参数、手势阈值、暗蒙版等)。调手感/外观先改这里。
- **两个可插拔接口,外壳(ParticleSystem)不依赖具体实现:**
  - `InputSource.get() → {x, y, active, mode?}`:已有 `PointerInput`(鼠标/触摸)、`CameraInput`(摄像头手部追踪)。
  - `Theme`(`init/update/draw`):目前只有 `FireflyTheme`;加新主题(如星空流场)实现接口后注册到 `THEMES` 即可,`?theme=xxx` 切换。
- **物理模型**:运动 = Ornstein–Uhlenbeck 布朗运动(高斯白噪声 √dt 缩放 + 黏滞阻力);发光 = 平方反比软化衰减 + 两层(实心亮核 + 带色外晕)+ `lighter` 加色叠加。改这些前先读 `docs/superpowers/specs/`。

## 摄像头(红线/易踩坑)

- 摄像头(`getUserMedia`)**只能在 HTTPS 或 localhost 用,`file://` 不行**。本地测:双击 `start.command`(起服务 + 开浏览器,端口 8137)。
- MediaPipe(`@mediapipe/tasks-vision` 的 HandLandmarker)资源**已本地打包在 `vendor/`,绝不引用任何 CDN**(国内无梯子约束)。`vendor/` 必须提交进仓库,勿加入 .gitignore。
- 摄像头模块用**动态 import** 懒加载,以保证双击 `index.html`(file://)时鼠标版仍能用。

## 部署

已部署 GitHub Pages:https://bb0580202-a11y.github.io/glow/(`main` 分支根目录)。push 后自动重建。
