# v3 摄像头手部追踪 — 设计文档

> 日期:2026-05-29
> 状态:设计待评审
> 前置:v1(暖光萤火,已完成)。本期在 v1 基础上增加摄像头输入,**不改动粒子系统/外壳**。

## 1. 目标与范围

让用户用**真实的手**(摄像头)控制萤火:手在画面里移动,萤火被手心吸引、聚拢——复用 v1 已有的"把光捧在手里"吸引逻辑。

**本期范围:**
- 手心位置吸引 + **两个手势**(从已有 21 关键点计算,不加 ML):
  - **张开手掌 → 推散**(萤火被推开四散)
  - **握拳 → 强聚**(萤火紧紧聚向手心)
  - 平手/自然 → 默认轻柔吸引
- 摄像头是**可选开关**,默认仍是鼠标/触摸;点按钮才开摄像头。
- MediaPipe 资源**提交进仓库**(本地路径,不碰任何 CDN)。

**不在本期:** 捏合手势、光点颜色随环境亮度自适应(只做简单暗蒙版)、HTTPS 公网托管(单独处理)。

## 2. 技术选型(经调研)

- 库:**`@mediapipe/tasks-vision` 的 `HandLandmarker`**(Google 现行主推,非旧版 `@mediapipe/hands`)。输出 **21 个手部关键点**,x/y 归一化到 [0,1]。
- 初始化:`FilesetResolver.forVisionTasks(wasm本地路径)` → `HandLandmarker.createFromOptions({modelAssetPath, runningMode:'VIDEO', numHands:1})`;每帧 `detectForVideo(video, timestamp)`。
- wasm 路径与模型 `hand_landmarker.task` **均用本地相对路径**,不走 CDN。

## 3. 架构(全部挂在现有接口上)

```
全屏 <video>(摄像头画面,CSS 镜像)   z0  ← 透明画布"后面"的背景层(v1 已为此预留)
  └ 全屏暗色蒙版 <div>               z1  ← 压暗实景,让暖光点跳出(应对亮环境看不见)
透明画布 <canvas>(粒子,不变)        z2
「开启/关闭摄像头」按钮               z3  ← 可选开关,极简,左下角
```

- 摄像头**关**时:video+蒙版 `display:none`,body 纯黑,与 v1 表现一致。
- 摄像头**开**时:显示 video+蒙版,粒子叠在压暗后的实景上。

### CameraInput(实现 InputSource 接口,与 PointerInput 可互换)

```
契约不变:get() → { x, y, active }
- start():懒加载 —— 点按钮时才 import 本地 MediaPipe 模块 + 申请摄像头权限。
- detect(now):每帧由主循环调用;video 帧变化时跑 detectForVideo。
    取手心关键点(landmark 9,中指根,比指尖稳)→ 归一化映射到画布像素 → X 轴镜像(自拍视角)。
    检测到手 active=true 并记录时间;丢失超过 handGrace 毫秒才置 active=false(防闪烁)。
- **手势(本期)**:从关键点算"展开度" = 指尖(8/12/16/20)到手心(9)平均距离 / 手长(0→9)。
    EMA 平滑后三段分类:> openThreshold → 'repel';< fistThreshold → 'attract';之间 → 'neutral'。
    中间留空带 + 平滑 = 迟滞防抖。`get()` 返回 `{x,y,active,mode}`。
- FireflyTheme 读 `point.mode`:'repel' 反向推力(repelForce),'attract' 强吸(attractForceStrong),
    其余/无 mode(如 PointerInput)→ 默认 attractForce。归一化 x/y 各向异性对比值影响小,接受。
- 【留白·捏合】detect 内仍可加 拇指(4)-食指(8) 捏合 → 更精细牵引(后续)。
```

## 4. 资源与加载方式

- 仓库新增 `vendor/`(约 7–8MB,提交进仓库,自包含):
  - `vendor/tasks-vision/vision_bundle.mjs` + `vendor/tasks-vision/wasm/`(wasm 运行时)
  - `vendor/hand_landmarker.task`(手部模型)
- **加载方式 = 动态 import**:主脚本保持非模块,**双击 file:// 仍能玩鼠标版**;摄像头相关代码只在点按钮时 `await import('./vendor/tasks-vision/vision_bundle.mjs')`。file:// 下摄像头本就不可用(非安全环境),故不影响双击体验;在服务器(localhost/HTTPS)下正常。

## 5. 坐标映射

- 归一化 `palm.x/palm.y` ∈ [0,1] → 画布像素:`x = (1 - palm.x) * W`(镜像),`y = palm.y * H`。
- **已知近似**:video 用 `object-fit: cover` 全屏可能裁剪,归一化坐标基于完整视频帧,与裁剪后显示区有轻微偏差。本期接受;如需精确再按裁剪比例校正(后续)。

## 6. 可见性应对(亮环境)

- video 上叠一层**可调暗色蒙版**(`rgba(0,0,0,scrimAlpha)`,初值 ~0.45),压暗实景让暖光点跳出。
- 完整的"按画面亮度自适应粒子颜色"留作后续(见 §9)。

## 7. 权限与安全上下文

- 摄像头需 **HTTPS 或 localhost**。本机 `python -m http.server` 走 `http://localhost:PORT` 即可测;手机用局域网 `http://172.x` **不是安全环境,摄像头会被禁**(需 HTTPS 托管,单独处理)。
- `getUserMedia({video:{facingMode:'user'}})`。

## 8. 错误处理

- 用户**拒绝授权** / 无摄像头:捕获异常,按钮回到"开启摄像头",提示一句失败原因,回落到鼠标输入。
- **模型/wasm 加载失败**:同上回落,提示。
- **未检测到手**:`active=false`,粒子回到自由漂浮(正常待机)。

## 9. 验证清单(本机 localhost)

- [ ] 点「开启摄像头」→ 浏览器请求授权;允许后看到镜像的摄像头画面(被压暗)在粒子后面。
- [ ] 手在画面里移动 → 附近萤火被手心吸引、跟随;手移开/移出画面 → 萤火散回。
- [ ] 拒绝授权 → 友好提示,自动回到鼠标可用状态。
- [ ] 「关闭摄像头」→ 画面隐藏、摄像头灯灭、回到纯黑鼠标版。
- [ ] 双击本地 `index.html`(file://)→ 鼠标版仍正常(摄像头按钮点了会提示需服务器,不崩)。

## 10. 后续(不在本期)

- 手势:张手推开 / 握拳吸引 / 捏合聚焦(接 §3 留白)。
- 光点颜色随环境亮度自适应(采样 video 亮度)。
- HTTPS 公网托管(艾可秀等)→ 手机/分享可用摄像头。
- 坐标裁剪校正、多手(numHands:2)。
