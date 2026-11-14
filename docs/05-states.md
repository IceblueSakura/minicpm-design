# 状态矩阵

每个界面都要回答“这个状态下用户看到什么、能做什么”。本表列出原型已覆盖的状态和打开方式。`states.html` 把它们排在一页里，方便一次评审。

状态参数都加在 `index.html` 后面，比如 `index.html?hold=call&task=camera&live=voice&t=11`。

加 `&still=1` 让实时和下载停在打开时的那一刻。`states.html` 里全部这样打开，否则一秒长的话轮一闪就过了。

**交付阶段**：原型默认打开第一阶段，只有看图模型，没有实时。`stage=2` 打开下阶段的预留设计，带 `live` 参数或 `crash=live` 时自动进入。本文的实时会话和全能模型都属于下阶段，见 [交付阶段和两条基线](03-structure.md#交付阶段和两条基线)。

## 首次启动与模型

| 状态 | 用户看到 | 可做的事 | 参数 |
|---|---|---|---|
| 欢迎 | 三个承诺 | 继续 | `?onboard=welcome` |
| 恢复备份 | iCloud 里有备份，写时间和数量 | 恢复、重新开始 | `?onboard=restore` |
| 选模型 | 这台设备能用的模型列表，标推荐，写大小。列表由 backend 按硬件给出，现在是占位 | 选择、下载、用自己的服务器 | `?onboard=model` |
| 选模型·下阶段 | 列表里有全能模型 | 同上 | `?onboard=model&stage=2` |
| 内存偏小 | 推荐看图，全能写风险 | 仍可选全能 | `?onboard=model&device=low&stage=2` |
| 内存充足 | 列表里多出更大的选择 | 选择 | `&device=high` |
| 空间不足 | 写明还差多少，下载按钮不可用 | 改下载看图、清理 | `&storage=low` |
| 下载中 | 进度、剩余时间、可离开 | 暂停、先进去看看 | `?onboard=download&dl=62` |
| 等待 Wi-Fi | 进度、还差多少 | 用移动网络继续、取消 | `&dlstate=wifi` |
| 已暂停 | 进度 | 继续、取消 | `&dlstate=paused` |
| 下载中断 | 已下载的部分还在 | 重试、取消 | `&dlstate=failed` |
| 校验中 | 正在检查文件 | 等待 | `&dlstate=verifying` |
| 文件不完整 | 校验没过，要重新下载 | 重新下载、取消 | `&dlstate=badfile` |
| 下载时使用 | 输入框上方显示进度 | 可以写，不能发，内容保留 | `?view=empty&dl=62` |
| 当前模型不在了 | 输入框上方提示 | 下载、换模型 | `?view=empty&omni=none` |
| 正在准备 | 模型不在内存里，横幅写预计时间，发送后自动接上 | 打字、发送、点实时 | `?view=empty&prep=1` |
| 准备时点了实时 | 横幅写“现在还没有在听” | 取消 | 上一条点实时 |
| 准备失败 | 红色横幅，内容保留 | 重试 | 原型状态里开“内存不够”和“模型不在内存里”后发送 |
| 换模型确认 | 选择器里就地展开说明，不弹窗 | 换用、先不换 | `?view=empty&swap=ask` |
| 换模型中 | 横幅写目标和预计时间，发送后自动接上 | 取消 | `?swap=loading` |
| 载不下 | 红色横幅，已换回原模型 | 重试 | `?swap=failed&model=minicpm-v-4.6` |

## 对话

| 状态 | 用户看到 | 参数 |
|---|---|---|
| 新对话 | 提问语、隐私声明、建议。紧凑形态主按钮是拍照提问 | `?view=empty` |
| 新对话·下阶段 | 主按钮是实时 | `?view=empty&stage=2` |
| 历史页 | 紧凑形态的整页历史，返回回到对话 | `?view=empty&nav=1` |
| 说话输入 | 录音条写“本机转成文字”，完成后文字进输入框 | `?view=empty&rec=1` |
| 说话输入·第一次 | 用途说明，再进系统弹窗 | `?view=empty&perm=ask` |
| 说话输入·被拒绝 | 红色横幅，给重试和用文字 | `?view=empty&perm=denied` |
| 没有说话输入 | 系统不能本机识别，麦克风不出现 | `?view=empty&dictate=off` |
| 浏览器没有说话输入 | 同上，提问语只写打字和图片 | `?view=empty&runtime=browser` |
| 图片处理中 | 附件写“正在处理”，可以发送 | `?view=empty&att=busy` |
| 临时对话 | 标题和输入框都有标记 | `?temp=1` |
| 视觉模型，已下载全能模型 | 实时入口还在，点了先问要不要换 | `?view=empty&model=minicpm-v-4.6&live=voice` |
| 视觉模型，没有全能模型 | 没有实时入口，紧凑形态主按钮是拍照提问 | `?view=empty&model=minicpm-v-4.6&omni=none&stage=2` |
| 生成中 | 光标、发送变停止 | 发送一条消息 |
| 已停止 | 回答留在原处 | 生成时按停止 |
| 发送失败 | 消息下方“没有发出去”和重试 | `?engine=offline` 后发送 |
| 回答被截断 | “回答太长，到这里停了”和接着写 | `?task=trip` |
| 对话快满 | 提示会遗忘，带上摘要新开 | `?task=trip` |
| 联网前询问 | 卡片写明发送内容 | `?task=camping` |
| 联网后记录 | 一行记录，可跳到联网记录 | 点“查一下” |
| 离线时的询问 | 卡片写明现在不能联网，给关闭离线模式 | `?task=camping&offline=1` |
| 定时通知 | 卡片写明时间和通知内容，点了才添加 | `?task=community` |
| 定时通知没有权限 | 卡片写明去系统设置 | `?task=community&notify=denied` |
| 定时通知在浏览器 | 卡片改成存成日历提醒 | `?task=community&runtime=browser` |
| 写备忘录 | 卡片写明要写的那句话 | `?task=memo` |
| 写入记忆 | 回答下面一行“已记住：……”，有撤销和管理 | `?task=allergy` |
| 撤销记忆后 | 这一行变成“已忘掉这条”，不显示原文，可以重新记住 | `?task=allergy&forgot=1` |
| 记忆关着 | 旧的一行不能重新记住。说“记住……”时回答记不下来，没有新的一行 | `?task=allergy&forgot=1&memory=off`，或 `?memory=off` 后发“记住我喜欢短回答” |
| 对照原图 | 从回答里的数字打开，高亮位置和读到的原文 | `?task=report&source=glucose` |
| 看不太清 | 数字旁标记，面板写可能的读法 | `?task=report&source=chol` |
| 附件不支持 | 附件标红，发送不可用，提示换模型 | 视觉模型下添加音频 |
| 拖入文件 | 区域高亮 | 拖入文件 |
| 搜索无结果 | 提示可搜场景名 | 搜索任意词 |

## 回答内容

回答可能包含的形态：段落、粗体、三级标题、有序和无序列表、引用、链接、行内代码、代码块、表格、产物卡片、步骤、思考过程、语音条。

| 形态 | 紧凑形态处理 | 参数 |
|---|---|---|
| 表格 | 单元格换行，放不下时横向滚动，不撑破页面 | `?task=trip` |
| 代码块 | 块内横向滚动，顶部有语言和复制 | `?task=script` |
| 列表和引用 | 与正文同宽 | `?task=repot` |
| 产物 | 卡片，打开走系统预览 | `?task=script` |

## 运行参数与测量

规则见 [运行参数与测量](03-structure.md#运行参数与测量)。

| 状态 | 用户看到 | 参数 |
|---|---|---|
| 测量行 | 回答工具行末尾一行模型、速度、用时，可点。“显示技术信息”默认打开 | `?task=report` |
| 运行详情 | 生成速度、模型和规格、首字用时、生成用时、生成长度、内存峰值、运行方式；LES 测量写明后端接入后显示 | `?task=report&run=1` |
| 运行方式·自定义 | 档位下写“自定义 · 和推荐值相比改了 2 项”和查看 | `?settings=models&params=custom` |
| 参数·都是推荐值 | 顶部写“都是当前模型的推荐值”，每项标“推荐值” | `?settings=advanced` |
| 参数·已调整 | 顶部写改了几项和“恢复推荐值”，改过的项数值加重，旁边有推荐值和恢复 | `?settings=advanced&params=custom` |
| 参数·记忆太长 | 对话记忆长度下面写约需多少、超过多少，改到多少就能放下 | `?settings=advanced&params=custom&device=low` |
| 参数·模型太大 | 写明模型本身放不下，缩短记忆也没用，换轻量规格或更小的模型 | `?settings=advanced&device=low&model=minicpm-v-4.5` |

## 主题

规则见 [设计语言](02-design-language.md#主题)。原型的主题和外观各自独立，每一条都可以加 `&theme=dark`。

| 状态 | 用户看到 | 参数 |
|---|---|---|
| 六套主题 | 对话区纸面、文字色调和模型色随主题变；采集点、琥珀提示、删除按钮不变 | `?task=report&palette=plain`，`palette` 依次是 `plain` `celadon` `xuan` `indigo` `wisteria` `lab` |
| 增强对比度 | 辅助文字和分隔线加深，模型色朝墨色收 | `?task=report&contrast=more`，可再加 `&palette=` |
| 主题选择 | 通用设置里外观下面的主题卡片，每张有当前外观的纸面、气泡、模型色缩略 | `?settings=general&palette=xuan` |
| 不认识的主题 | 显示青瓷，存储里的值不改 | `?task=report&palette=unknown` |

## 实时会话

话轮状态和打断的完整定义在 [实时会话](04-live-session.md)。

| 状态 | 参数 |
|---|---|
| 连接中 | `?view=empty&live=voice` |
| 聆听、你在说、回应、重叠 | `?view=empty&live=voice&t=0.3`，`t` 依次是 0.3、2.5、6、9.6 |
| 麦克风已关 | 上一条加 `&mute=1` |
| 远看模式 | `?view=empty&live=voice&t=6&far=1`（紧凑形态） |
| 摄像头 | `?view=empty&live=camera&t=6` |
| 共享屏幕 | `?view=empty&live=screen&t=6`（展开形态） |
| 主动提醒 | `&proactive=high&t=25` |
| 来电 | `?task=camera&live=voice&t=11&hold=call` |
| 来电结束 | 上一条加 `&ready=1` |
| 回到前台 | `&hold=background&ready=1` |
| 屏幕锁定 | `&hold=lock` |
| 耳机断开 | `&hold=route` |
| 断线重连 | `&link=1` |
| 闲置·倒计时 | `&idle=1` |
| 闲置·已暂停 | `&hold=idle` |
| 发热·放慢 | `&heat=1` |
| 发热·只用声音 | `&heat=2` |
| 发热·暂停 | `&hold=heat` |
| 电量·放慢 | `&battery=1` |
| 电量·只用声音 | `&battery=2` |
| 电量·暂停 | `&hold=battery` |
| 电量·接上电源 | `&hold=battery&ready=1` |
| 模型中断 | `?task=camera&live=voice&t=11&crash=model` |
| 实时里写入记忆 | `?task=camera&live=voice&t=11&remember=1` |
| 从别的对话看 | 实时中切到其他对话，顶部出现状态条 |

## 后端与权限

下面是原型现在能打开的状态。切到远程在原型里仍是直接切换。目标行为是先经过在线备用的同意页，见 [隐私设计](08-privacy.md#在线备用)。同意页还没有查询参数。

| 状态 | 用户看到 | 参数 |
|---|---|---|
| 本机模型未启动 | 输入框上方红色提示，内容保留 | `?engine=offline` |
| 远程未配置 | 提示去设置 | `?backend=remote&remote=empty` |
| 远程可用 | 所有隐私声明改成写明发送到哪里 | `?backend=remote` |
| 远程连不上 | 提示重试，或改用这台设备 | `?backend=remote&engine=offline` |
| 切换后的对话 | 对话里留一行标记，写明从这里开始发送到哪里 | `?task=notes&backend=remote&place=1` |
| 浏览器运行 | 模型设置和选模型页写明存放在浏览器里，隐藏平台没有的设置 | `&runtime=browser` |
| 浏览器跑不了 | 提示换浏览器或改用远程服务，内容保留 | `?runtime=nogpu`，首次使用加 `&onboard=model` |
| 网络不稳 | 实时自动降帧，状态写“网络不稳” | `&net=weak` |
| 第一次用麦克风 | 用途说明，再进系统弹窗 | `?perm=ask` |
| 权限被拒绝 | 提示去系统设置，或用文字继续 | `?perm=denied` |
| 内存紧张 | 侧栏提示原因和建议 | `?mem=tight` |
| 离线模式和远程 | 红色横幅，声明写“内容不会发送” | `?backend=remote&offline=1` |

## 崩溃

规则见 [意外退出之后](04-live-session.md#意外退出之后)。

| 状态 | 用户看到 | 可做的事 | 参数 |
|---|---|---|---|
| 模型重启失败 | 会话结束，转写留着，红色横幅 | 重试 | `?task=camera&live=voice&t=11&crash=model&fail=1` |
| 上次实时意外结束（下阶段） | 回到那段对话，横幅写“现在没有在听” | 重新开始、知道了 | `?crash=live` |
| 回答中断 | 已写出的部分和“模型中断了，回答到这里” | 接着写 | `?crash=reply` |
| 载入时退出 | 红色横幅，这次没有自动载入 | 再试一次、换模型、发送 | `?crash=load` |
| 发送崩溃报告 | 横幅写明发送什么 | 发送、不发送 | `?crash=report` |
| 联网记录里的报告 | 多一行崩溃报告 | | `?settings=network&crash=sent` |

## 隐私

| 状态 | 参数 |
|---|---|
| 应用已锁定 | `?lock=1` |
| 后台遮盖 | `?cover=1` |
| 已记住的内容 | `?settings=memories` |
| 联网记录 | `?settings=network` |
| 联网记录·远程 | `?settings=network&backend=remote` |
| 联网记录·备份 | `?settings=network&backup=on` |
| 已记住的内容·远程 | `?settings=memories&backend=remote` |
| 定时通知列表 | `?settings=reminders` |

## 备份与迁移

| 状态 | 用户看到 | 参数 |
|---|---|---|
| 备份关闭 | 开关和写明内容的说明 | `?settings=privacy&import=none` |
| 备份开启 | 上次备份时间，隐私声明改成写明 iCloud | `?settings=privacy&backup=on` |
| 正在备份 | 进度条 | `?settings=privacy&backup=running` |
| iCloud 空间不够 | 写还差多少，给管理入口 | `?settings=privacy&backup=full` |
| 没有登录 | 给系统设置入口 | `?settings=privacy&backup=signedout` |
| 没有 iCloud | 只有导出和导入，Android 和 Web 相同 | `?settings=privacy&backup=none` 或 `&runtime=browser` |
| 导入失败 | 提示卡写原因，现有对话不变 | `?settings=privacy&import=failed` |
| 新对话·备份开启 | 声明写“记录备份到你的 iCloud” | `?view=empty&backup=on` |

## 通用要求

所有状态都要在这些条件下成立：

- 浅色和深色：加 `&theme=dark`。
- 窗口宽度 360、390、768、1280、1512。
- 四种语言的最长文案，见 [文案与多语言](09-i18n-copy.md)。
- 系统字体放大。原型没有模拟，原生端验收时检查。
- 仅键盘操作和读屏。

## 原型还没有覆盖

| 内容 | 处理方式 |
|---|---|
| 系统字体放大 | 原生端用系统能力验证 |
| 系统通知、锁屏活动、灵动岛、菜单栏 | 见 [平台落地](07-platforms.md) 的文字规格 |
| 分享进入 | 同上 |
| 手机屏幕共享 | 手机网页不支持，原生端单独设计入口 |
| 场景安装和分发 | 方向未定，见 [决策记录](10-decisions.md) |
