# MODIFICATIONS — 相对上游的全部改动

上游：[6shenhonghong9/dsh-startup-screen](https://github.com/6shenhonghong9/dsh-startup-screen) v1.1.0
分支：`macos-enhancements`　·　改动文件：`lib/index.js` `lib/splash.js` `lib/splash.css`
`lib/client.js` `test/smoke-splash.mjs` `test/smoke-host.mjs`　·　新增：`tools/touchid-helper.swift`

所有改动均在原仓库 MIT License 授权范围内（`lib/assets/` 音频素材除外，见 README）。

## 一、终幕 TTS 欢迎语（lib/splash.js）

上游 `finale()` 写死 `voice.line(null, null, 'line-6')`：真声素材模式下能播，
但「语音来源 = 系统 TTS」时 `ttsLine(null, null)` 的 items 为空，终幕整段静音。
改为传入兜底文本（素材缺失或 TTS 模式时生效，`voiceLang` 决定念哪句）：

```js
voice.line('Welcome, ' + voice.speakName(C.identity) + '.',
           '欢迎 ' + C.identity + ' 访问', 'line-6')
```

真声素材优先级不变，`voiceSource=asset` 时行为与上游完全一致。

## 二、ID CONFIRMED 挪位 + 延后出现（lib/splash.css · lib/splash.js）

- **挪位**：`.dsu-idline` 原挂在环形准星右侧（`left: calc(50% + 190px)`），全屏时
  准星直径撑到 86vh、右缘压住该位置导致文字重叠。改挂页脚上方
  （`right: 46px; bottom: 76px`），与 `POWERED BY …` 同一边缘；入场改为与页脚
  同款从右滑入；窄窗隐藏阈值 1180px → 900px。
- **延后**：原版在第二幕就点亮并一路挂到终幕；现改为仅在「身份资料确认」
  验证通过、资料卡亮出时出现。

## 三、身份验证三模式（lib/index.js · lib/client.js）

配置从布尔 `auth` 改为枚举 **`authMode: 'touchid' | 'iris' | 'none'`**（默认
touchid），`normalize()` 带迁移：老配置 `auth:false` 自动映射为 `none`，升级后
不会被突然要求验证。设置页「交互」组换成三选一下拉，并实时显示验证助手状态。

## 四、系统验证（Touch ID / 登录密码）

**架构**：插件前端拿不到 Electron 原生 API（`promptTouchID` 仅主进程可用、无 IPC
桥），WebAuthn 在桌面端自定义协议下也不可用。可行路径是 Host 半侧 spawn 子进程：

```
前端「确认身份」→ POST /dsh-startup/auth（插件 Host 路由）
  → execFile spawn ~/.dsh/dsh-startup-auth
    → LAContext.evaluatePolicy(.deviceOwnerAuthentication)
```

- **`tools/touchid-helper.swift`（新增）**：约 50 行 Swift，调 macOS
  LocalAuthentication 弹真正的系统验证框（Touch ID 优先，无指纹自动退回登录
  密码，一次验证同时覆盖两者）。60 秒自超时，退出码 0/1/2/3，失败原因写
  stderr。编译安装：

  ```bash
  swiftc -O tools/touchid-helper.swift -o ~/.dsh/dsh-startup-auth && chmod +x ~/.dsh/dsh-startup-auth
  ```

  助手装在 `$DSH_HOME` 下、**不在包内**，插件升级不会覆盖；缺失时前端安静
  退回「点一下继续」的旧行为，绝不让动画卡死。
  助手本身是 **macOS 专属**（依赖 LocalAuthentication）；Windows / Linux 上
  自动走同一条退路，其余功能（虹膜模拟、动画、TTS 等）不受任何影响。
- **lib/index.js**：新增 `GET/POST /dsh-startup/auth` 路由（GET 探测助手在位、
  POST spawn 助手并回传结果）；并发闸门防止重复弹框；配置接口附带 `authReady`。
- **lib/splash.js**：验证不通过（取消 / 密码错误）时收起扫描舞台、显示具体
  原因（「验证已取消」/「验证未通过」），回到按钮界面可重试；Esc 跳过不受影响。

**流程时序**：点「确认身份」→ 居中舞台出现指纹扫描动画（2s）→ 唤起系统弹窗 →
通过后「指纹比对通过」停留 1.4s → 舞台收起 → 身份资料卡 + ID CONFIRMED 亮出。

## 五、模拟虹膜扫描（lib/splash.js · lib/splash.css）

`authMode=iris` 时的纯演出动画（不调任何系统能力）：居中 250px 舞台，
白盘 + 八圈细密点阵虹膜（几何按参考图逐像素实测：纹理 0.33–0.60R、
点径 0.016R、瞳孔严格居中）+ 橙色扫描光带 + 四角取景角标。扫描 2.6s +
「比对通过」停留 1.4s + 进度条，配一记高频合成提示音。

## 六、其他修复

- **输入屏蔽**：动画全程拦下会打字/滚动的按键（捕获阶段 preventDefault），
  不再漏进下层聊天输入框；修饰键组合与 F 功能键放行，揭幕后自动解除。
- **生物识别期间中央标题不消失**：上移让位给扫描图形，而不是整块淡出。
- **资料页去误导**：身份资料亮出后，残留的「确认身份」按钮去掉呼吸脉冲、
  「按 Enter / Space」提示隐藏（该段流程自动推进）；显示恢复点在
  `showAction`，避免动作区淡出时闪回。
- **指纹/虹膜共用居中舞台**（`.dsu-iris-stage`），尺寸 `min(250px, 30vh)`。
- **测试**：`smoke-host.mjs` 路由数断言 4→5；`smoke-splash.mjs` 终幕断言改为
  兼容 TTS 兜底写法并新增身份名称断言。四套测试 59+61+40+45 全绿。
