#!/bin/bash
# 萤 · 暖光粒子 —— 双击启动器(本地服务,摄像头需要它)
# 双击本文件即可:自动起本地服务并打开浏览器。关闭弹出的终端窗口即停止。
cd "$(dirname "$0")" || exit 1
PORT=8137
echo "萤 · 暖光粒子 —— 正在启动本地服务 (端口 $PORT) …"
echo "浏览器将自动打开 http://localhost:$PORT/"
echo "玩完后:关闭此终端窗口即可停止服务。"
( sleep 1; open "http://localhost:$PORT/" ) &
exec python3 -m http.server "$PORT"
