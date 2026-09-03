# 构建与发布

## 本地开发包

执行：

```sh
./scripts/run-checks.sh
./scripts/build-app.sh
```

构建产物：

```text
dist/Auto Clicker.app
```

构建脚本会：

1. 使用 SwiftPM 执行 Release 构建。
2. 创建标准 macOS App Bundle 目录。
3. 写入 `Support/Info.plist`。
4. 将 MIT `LICENSE` 放入 App Bundle 的 Resources 目录。
5. 对 Bundle 进行 ad-hoc 签名。

ad-hoc 签名只适合本机开发测试，不适合向其他用户分发。脚本构建当前 Mac 的原生架构；通用二进制需要分别构建 `arm64` 和 `x86_64` 后使用 `lipo` 合并。

## 发布前检查

```sh
plutil -lint "dist/Auto Clicker.app/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "dist/Auto Clicker.app"
```

还应人工完成 PRD 中的 AC-01 至 AC-13，尤其检查：

- Safari、Finder 等其他 App 位于前台时，全局快捷键仍可启停。
- 任务启动后移动鼠标，点击位置不发生变化。
- 无限任务和长按任务均能立即停止。
- 退出 App 后不再产生鼠标事件。
- 撤销辅助功能权限后无法启动任务，并显示授权入口。

## Developer ID 签名

正式分发需要有效的 Apple Developer Program 账号和 `Developer ID Application` 证书。将占位内容替换为实际证书名称：

```sh
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: Example Company (TEAMID)" \
  "dist/Auto Clicker.app"
```

验证签名：

```sh
codesign --verify --deep --strict --verbose=2 "dist/Auto Clicker.app"
spctl --assess --type execute --verbose=4 "dist/Auto Clicker.app"
```

## 公证

先创建保留扩展属性的 ZIP：

```sh
ditto -c -k --keepParent "dist/Auto Clicker.app" "dist/Auto-Clicker.zip"
```

使用已配置在钥匙串中的 `notarytool` profile 提交：

```sh
xcrun notarytool submit "dist/Auto-Clicker.zip" \
  --keychain-profile "NOTARY_PROFILE" \
  --wait
```

公证通过后附加票据并再次验证：

```sh
xcrun stapler staple "dist/Auto Clicker.app"
xcrun stapler validate "dist/Auto Clicker.app"
spctl --assess --type execute --verbose=4 "dist/Auto Clicker.app"
```

不要把 Apple ID 密码、App Store Connect API 私钥或签名证书提交到仓库。

## 版本发布清单

- 更新 `Support/Info.plist` 中的 `CFBundleShortVersionString` 和 `CFBundleVersion`。
- 更新 PRD 或变更记录中的用户可见行为。
- 运行核心检查与 Release 构建。
- 完成人工验收。
- 使用 Developer ID 重新签名并完成公证。
- 生成校验和并创建 GitHub Release。
