# PhotoTend Android 图标留白调整设计

## 问题

PhotoTend 的批准 Logo 源稿本身包含米白背景与四张照片卡片，但 Android 8 及以上的自适应图标会在不同启动器遮罩中缩放前景。当前 adaptive foreground 占 432 × 432 画布约 84%，在实机桌面上主卡接近系统圆角边缘，左侧后层卡片也显得拥挤。

## 已批准方案

- 只调整 Android adaptive icon；Android legacy、iOS 与 macOS 图标保持不变。
- 保留 `assets/brand/phototend-mark.svg` 的精确几何与颜色，不修改品牌源稿。
- 将 adaptive foreground 在 432 × 432 透明画布中的占比从约 84% 缩小到 68%。
- 前景居中渲染为约 294 × 294，四周各保留约 69 像素透明区；系统背景继续使用 `#F4F0E8`。
- 不改变资源名称、AndroidManifest、包名或 adaptive icon XML 契约。

## 验收标准

- Android 8+ 启动器图标比当前版本明显更舒展，主卡不贴近系统遮罩边缘。
- 四张卡片层次、右上圆孔与方正主卡仍清晰可辨。
- `ic_launcher_foreground.png` 仍为 432 × 432 RGBA PNG，透明边距居中且四边对称。
- Android debug APK 与 Kotlin 编译通过。
- iOS、macOS 和 Android legacy 图标文件不发生变化。
