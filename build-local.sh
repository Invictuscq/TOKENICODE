#!/bin/bash
# TOKENICODE 本地构建脚本
# 用法:
#   ./build-local.sh          仅构建并安装
#   ./build-local.sh sync     先同步上游更新，再构建并安装
set -e

APP_NAME="TOKENICODE"
BUNDLE_PATH="src-tauri/target/aarch64-apple-darwin/release/bundle/macos/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"

cd "$(dirname "$0")"

# ── 可选：同步上游 ──
if [ "$1" = "sync" ]; then
  echo "==> 同步上游更新..."
  git fetch upstream
  git checkout main
  git merge upstream/main
  git push origin main
  git checkout custom/dark-theme-low-brightness
  git rebase main || {
    echo "!! rebase 有冲突，请手动解决后运行:"
    echo "   git rebase --continue && ./build-local.sh"
    exit 1
  }
  git push --force-with-lease origin custom/dark-theme-low-brightness
  echo "==> 上游同步完成"
fi

# ── 安装依赖 ──
echo "==> 安装前端依赖..."
pnpm install --frozen-lockfile

# ── 构建 ──
echo "==> 开始构建 (首次约 5-10 分钟，后续增量约 1-2 分钟)..."
pnpm tauri build --target aarch64-apple-darwin 2>&1 || {
  # Tauri exits with error if TAURI_SIGNING_PRIVATE_KEY is missing (updater signing),
  # but the .app bundle is already built successfully at this point.
  if [ -d "$BUNDLE_PATH" ]; then
    echo "    (忽略签名警告，.app 已构建成功)"
  else
    echo "!! 构建失败"
    exit 1
  fi
}

# ── 安装到 /Applications ──
if [ -d "$BUNDLE_PATH" ]; then
  echo "==> 安装到 ${INSTALL_PATH}..."
  # 关闭正在运行的实例
  osascript -e "quit app \"${APP_NAME}\"" 2>/dev/null || true
  sleep 1
  rm -rf "$INSTALL_PATH"
  cp -R "$BUNDLE_PATH" "$INSTALL_PATH"
  # 移除 macOS 隔离标记（未签名 app 需要）
  xattr -cr "$INSTALL_PATH"
  echo ""
  echo "==> 构建完成！"
  echo "    已安装到: ${INSTALL_PATH}"
  echo "    可直接从 Launchpad 或 Dock 启动"
  # 打开 Applications 文件夹方便拖到 Dock
  open -a "$INSTALL_PATH"
else
  echo "!! 构建产物未找到: ${BUNDLE_PATH}"
  exit 1
fi
