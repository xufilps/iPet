# iPet 图标来源与导出 — 2026-10-01 / pixel-v1

当前 AppIcon 使用像素风候选：参考仓库原 `vpeticon.png` 的银灰头发、黄色发饰、粉白服装和蓝色调，以头像构图重新生成。保留原图标及素材，未修改原角色动画。此前原创白色小宠物的立体候选保留为 `ipet-icon-v1-source.png` / `ipet-icon-v1-master.png`，不再进入应用图标。

## 生成记录

工具：OpenAI imagegen；日期：2026-10-01；参考输入：[原版图标](../../vpeticon.png)。原始输出1254×1254像素，保存为 `ipet-icon-pixel-v1-source.png`，1024×1024 母图为 `ipet-icon-pixel-v1-master.png`，使用系统 sips 做尺寸标准化，生成文件原件同时保留。该图是以原图为参考的 AI 生成演绎，不宣称独立于原角色的原创权利，也不是原作者绘制的新素材；相关角色/图像来源仍按 [原作授权](../ANIMATION_LICENSE.md)告知。生成方式不改变原动画和角色授权，公开使用仍需遵循原权利方要求。

生成提示词：

> Create a polished pixel-art macOS app icon for iPet, using the attached original VPet icon as a visual reference for the character and nostalgic pixel style. This is a new interpretation, not a copy of the original icon. A friendly chibi desktop-pet girl with long silver-gray hair, small warm yellow hair accents, rosy cheeks, a simple white and dusty-pink outfit, large friendly dark eyes. Show a large centered head and upper torso, very readable silhouette. True deliberate coarse pixel art: sharp square pixels, stepped contours, limited palette, no smooth 3D rendering, no fuzzy edges, no photorealism. Lake-blue rounded-square tile behind the character, subtle darker pixel border, generous transparent outer margin suitable for macOS. No Windows desktop or window frame, no text or letters, no Apple logo. Aim for a clean 64x64 pixel-art design enlarged with crisp nearest-neighbor style to 1024x1024 PNG; keep face readable at 16 and 32 pixels. One finished square app icon only.

输出是生成的像素风插画，不是严格网格对齐的 64×64 手工像素源文件。底板为阶梯式圆角，外部有透明留白；当前导出采用 sips 缩放，缩小后存在抗锯齿，不将其宣称为精确整数倍像素重绘。未来 iOS 应另做无透明外边距的排版，本母图不直接作为 iOS 上架图标。

## 资源与检查

`python3 Apple/scripts/export_icon.py` 从母图导出 16、32、64、128、256、512、1024 像素 PNG，配置 macOS 的十个 1x/2x 资源槽；`--check` 校验尺寸和资源槽对应关系。已提交的资源目录由 Xcode 编译，普通构建无需调用在线图片生成服务。`create_project.py` 同时维护资源目录引用和 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`。

已实际查看 16、32、64、128 像素导出：16 像素仍可辨认蓝底与浅色头像，发饰/表情细节不清晰；32 像素可见眼睛及粉色衣服；64/128 像素保留主要人物轮廓。小尺寸是简化的整体识别，不承诺全部细节保留。校验和见 [SHA256SUMS](SHA256SUMS)，最终工程验证记录见 [交接](../docs/HANDOFF.md)。回退本轮图标提交即可恢复此前工程配置，不删除原版图标或用户存档。

工程采用 Apple 的 [AppIcon资源目录配置方式](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)，不依赖Icon Composer。

## iOS 图标版式 — 2026-10-03

`ipet-icon-ios-v1-source.png` 为imagegen参照现有像素风母图生成的独立全幅方形版：保持灰发角色、蓝天和白星，去除预圆角与外部透明留白，将背景延伸到四边。生成原件1254×1254，导出到 `Resources/iOSAssets.xcassets/AppIcon.appiconset/icon-1024.png` 为1024×1024不带alpha的RGB。系统负责图标形状，未改macOS原图标。导出与验证由export_icon.py管理；这是品牌图标的生成来源，不是原角色/动画的新授权。
