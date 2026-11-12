# 首次发布与商店政策

开发期要预留的界面和规则在 [开发期合规设计要求](12-compliance.md)。本文是首次发布前一次性处理的清单，加上美区 / 全球条款的摘要，以及先不做的国区材料。

信息截至 2026-11-12，整理公开资料供设计和开发对照，不构成法律意见。标了 **待核实** 的数字、备案号和第三方文章，以官方系统或原文为准。第三方和律所文章只当线索。

## 首次发布前统一处理

下列事项都依赖付费账号或还没定的主体。开发期只保证代码里留好接口，见 [开发期合规](12-compliance.md)。

1. **账号。** 个人 Apple Developer Program（99 美元/年）。商店里的卖家名是法定姓名。以后要上国区、多人签名或以企业名义运营时，升级成组织账号，或把 App 转移到合作企业。
2. **品牌授权。** 取得面壁智能对 MiniCPM 名称和图标的书面授权，或改用自有名称并写“基于 MiniCPM 模型”（审核指南 4.1(c)）。
3. **Bundle ID 与签名。** 定一个品牌中立的正式 Bundle ID。上传之后不能改。换成付费团队签名。用本仓库要求的 Xcode 27 构建（最低 iOS 27）。审核对 SDK 的最低要求以发布当时的 [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) 为准；2026-04-28 起的公开要求是 iOS 26 SDK，本项目高于这条线。现在的 `dev.icebluesakura.minicpm` 带个人域名，只给免费签名用。
4. **税务与银行。** 免费 App 只需默认的免费 App 协议，不需要税表和银行信息。
5. **替换占位链接。** 把 `AppLinks` / `config.ts` 里的 example.com 换成正式的隐私政策、使用条款、支持页和无障碍说明，并在 App Store Connect 填同样的地址。
6. **模型分发。** 切到 Apple 托管的 Background Assets。每个 App 最多 200 GB，构建本体上限 4 GB。开发期免费签名用不到这条，见 [个人设备测试](12-compliance.md#个人设备测试)。
7. **隐私与无障碍申报。** 按实际行为填隐私营养标签，目标是“不收集数据”，以及 Accessibility Nutrition Labels。判断标准见 [开发期合规](12-compliance.md#隐私营养标签争取不收集数据)。
8. **年龄分级。** 完成新版问卷。接入 Declared Age Range、PermissionKit 的 Significant Change API，以及撤回同意的通知。
9. **出口合规。** 只用系统 HTTPS 时，在 Info.plist 声明 `ITSAppUsesNonExemptEncryption` = NO。
10. **供应范围。** 先全球，取消中国大陆。上欧盟要做 DSA 交易商声明。
11. **TestFlight。** 内部测试最多 100 人，外部最多 10,000 人（第一个构建要过 Beta 审核），每个构建 90 天。重点测内存、发热和下载中断。
12. **提交审核。** 审核备注写明模型大小、下载时间、设备跑不动时的路径、在线备用默认关闭和它的说明、测试步骤、品牌授权。

## 个人账号与组织账号

优先级是个人账号，先美国和全球。中国大陆待扩展调研，见下一节。

| 事项 | 个人账号 | 组织账号 |
|---|---|---|
| 商店显示 | 卖家和开发者名称都是法定姓名 | 卖家是公司法定名称，开发者名称可以设成商号 |
| 协作 | 可以邀请别人进 App Store Connect。他们不是开发者团队成员，用不了证书、标识符和描述文件。签名和正式构建基本只能账号持有人做 | 可以添加不限数量的团队成员，按角色分权限 |
| 账号持有人转移 | 只在有限情况下由 Apple 协助 | 可以转给有签约权的员工 |
| 受监管领域 | 医疗等受监管领域的服务应由法人实体提交（5.1.1(ix)）。不要把 App 定位成医疗服务 | 可以以法人提交 |
| 中国大陆 | 只能对上个人非经营性备案。生成式 AI 登记实务上基本办不了 | 可以配合企业备案 |

两条迁移路径：

| 方式 | 何时用 | 做法 |
|---|---|---|
| 个人会员升级为组织会员 | 自己成立公司 | 须是创始人或联合创始人，提供 D-U-N-S，可能要交工商文件。卖家名变成公司名，已上架的 App 保留 |
| App Transfer 到合作企业的组织账号 | 上国区，或改由企业运营 | App 连同用户和评分转过去，由企业继续发布。原来的开发者以团队成员继续开发。这也是以后做国区的前提 |

会触发迁移的信号：要上中国大陆、需要第二个人签名发版、以企业名义合作或收费、要以企业品牌显示。

迁移很可能发生，所以正式 Bundle ID 不要带个人域名，提前定一个品牌中立的。免费签名阶段的 `dev.icebluesakura.minicpm` 不作为正式 ID。

## 美区与全球：相关条款

不做付费、不做追踪，所以 3.1 支付、外链抽成和 ATT 不适用。其余和本项目有关的条款：

| 条款 | 要求 | 对本项目 |
|---|---|---|
| 1.2 用户生成内容（2026-10-16 更新） | 明确覆盖 AI 内容生成类 App：过滤、举报并及时处理、屏蔽滥用用户、公开联系方式 | 已列入 [P0 内容安全](12-compliance.md)。开放场景分发后再补齐过滤和举报 |
| 2.5.2 / 2.5.19 | 不得下载会改变功能的代码。不得有隐藏的、或审核之后才开启的功能 | 模型只当数据。功能随版本固定，见开发期合规的能力交集 |
| 4.2.3(ii) | 首次启动要下载时，披露大小并提示 | 欢迎页已写下载体积 |
| 4.7 聊天机器人与插件 | 不随二进制附带的聊天机器人和插件也要遵守全部准则 | 接入第三方场景或 Agent 时适用 |
| 5.1.2(i) | 把个人数据分享给第三方（含第三方 AI）之前，要披露并取得明确许可 | 在线备用的同意流程 |
| 5.1.1(v) / 5.1.1(ix) | 有账号就必须能删除。受监管领域应由法人实体提交 | 现在没有账号。不定位为医疗服务 |
| 1.4.1 医疗 | 可能给出不准确的医疗信息时，要提醒咨询医生 | 体检场景加“仅帮助理解，不能替代医生” |
| 4.1(c) 品牌 | 未经许可不得使用他人品牌 | 需要授权，或改名并标明基于 MiniCPM |
| 年龄分级 / 德州 SB 2420 | 13+ / 16+ / 18+ 的新问卷。德州账号要做年龄验证 | 预留年龄接口 |
| 欧盟 DSA / AI Act | 交易商声明。第 50 条透明度义务自 2026-08-02 起适用 | AI 身份告知、导出文件里的机器可读标记 |
| 付费与追踪 | 3.1 支付、外链抽成、ATT | 不适用 |

美区外链佣金仍在诉讼之后的方案阶段（第九巡回法院 2025-12-11 的判决，以及之后公开报道的佣金方案）。本项目没有外链购买，不跟这条走。若以后收费，再读当时的协议。

## 国区（待扩展调研 / 待定）

**当前不推进。** 首发在 App Store Connect 的供应范围里取消中国大陆。下面的材料留下来，供以后扩展调研，不作为现在的开发任务。

合作方的在线服务若已备案，不自动覆盖这个新 App。以后做国区，关键是主体统一：备案主体、Apple 卖家（开发者名称）和中文 App 名称要一致，所以通常要先升级为组织账号，或把 App 转移到合作企业。

个人主体只能做非经营性 APP 备案。生成式 AI 登记实务上基本只受理企业。端侧运行不因此豁免。远程服务的自填地址要改成只连接已备案的服务。下载源要换成 ModelScope 或境内 CDN。

### 政策要点

| 规则 | 要求 | 对本项目 | 把握度 |
|---|---|---|---|
| APP 备案（工信部 105 号通知，2023-08） | 在境内提供互联网信息服务的 App 要向属地通信管理局备案。Apple 核验备案号和 App 信息是否一致。存量 App 在 2024-04-01 之后没有备案不能更新 | 合作企业若已有主体备案号，可在同一主体下新增这个 App | 已核实 |
| 《生成式人工智能服务管理暂行办法》（2023-08-15） | 面向境内公众的生成式服务适用。内容合规、服务协议、防沉迷、投诉渠道。有舆论属性的要做安全评估和算法备案 | 本项目属于生成式 AI 服务 | 已核实 |
| 生成式 AI 备案 / 登记 | 网信办 2026-09-14 公告：7–8 月有 124 款完成备案，其中 7 款是手机端侧。调用已备案模型的应用由地方网信办登记。要公示模型名称和备案号或上线编号 | 在线服务已备案这一说法需要核对。编号 Beijing-MiniCPM-202503180058 来自第三方汇总，必须以官方系统为准。还要确认是否覆盖 iOS App 和端侧运行 | 待核实 |
| 备案系统切换 | 2026-11-09 起统一使用“互联网新技术新应用信息服务备案系统”（beian.cac.gov.cn） | 按新系统办理 | 已核实 |
| 《深度合成管理规定》（2023-01-10） | 对使用者做真实身份认证之后才能提供信息发布。有标识义务 | 现在的无账号设计和实名要求有冲突。适用范围待确认 | 待核实 |
| 《人工智能生成合成内容标识办法》和 GB 45438-2025（2025-09-01） | 显式标识加隐式标识。分发平台上架时核验标识材料 | 必须做。端侧离线生成同样适用 | 已核实 |
| 《人工智能拟人化互动服务管理暂行办法》（2026-07-15） | 规范持续性的情感陪伴。工作助手和知识问答不适用 | 场景做成陪伴角色才会适用 | 已核实 |
| 《网络安全法》修正（2026-01-01） | 新增人工智能条款 | 总体背景 | 已核实 |
| PIPL 与数据出境 | 告知同意。出境要做评估、标准合同或符合豁免。豁免不免除告知和单独同意 | 远程服务指向境外、iCloud 备份，都要写进隐私政策 | 已核实 |
| 游戏版号 / CallKit | 游戏要有 NPPA 审批号。国区禁用 CallKit | 都不适用 | 不适用 |

### APP 备案：个人与企业

| 维度 | 个人 | 企业 |
|---|---|---|
| 主体资格 | 自然人。内地居民用身份证。其他证件看接入商和管局 | 境内依法设立的单位，用统一社会信用代码证件核验 |
| 主体负责人 / APP 负责人 | 都必须是本人 | 主体负责人多为法定代表人。APP 负责人须是员工，不是法人时要授权书 |
| 服务性质 | 只能非经营性。292 号令第十一条：不得从事有偿服务 | 可以做非经营性备案。平台类经营性服务需要 ICP 许可证 |
| 什么算经营性 | “有偿提供信息”。订阅和 IAP 在严格口径下是灰色地带。单纯广告多不单独认定。受委托收报酬的风险高 | 收费不影响备案资格 |
| 名称与前置审批 | 不得含“中国”等词，不用个人姓名。医疗等前置审批基本办不了 | 可按需申请 |
| 材料与接入商 | 身份证、核验照、短信核验。经云厂商提交，需要境内服务器或域名，实名一致 | 营业执照、法人和负责人证件、授权书。已备案的企业可以直接新增 APP |
| 时间与上线后 | 管局法定 20 个工作日内。App 内标注备案号。30 日内做公安联网备案（云厂商文档） | 同左 |
| 变更与转移 | 不能直接变更成企业备案。应用转移后要由新主体重新备案 | 同左 |

工信部答问：同一个 App 的发布主体不同，要先统一主体再备案。开发者实测里，Apple 保存备案号时会报 “Your developer name does not match MIIT's records”（第三方帖，**待核实**）。

### 生成式 AI 备案与登记：个人与企业

| 事项 | 个人 | 企业 | 本项目 |
|---|---|---|---|
| 大模型备案（约 6–8 个月） | 实务上不受理 | 自研或微调模型时办理 | 在线服务若已备案，微调后上线可能要做变更。周期是公开指南里的量级，**待核实** |
| 应用登记（约 3–6 个月） | 公开指南称需要营业执照，个人基本无法办理（待确认） | 调用已备案模型时办理 | App 是新入口：由备案主体办变更，或由 App 主体办登记 |
| 公示 | — | App 内公示模型名称、备案号或上线编号 | 放在“关于”和模型选择页 |

口径不一致：浙江网信办 2024 年称不具有舆论属性的服务无需备案；2026 年的国家公告和应用商店实务则普遍要求登记和公示。以属地网信办的答复为准。

### 上架方式

| 方案 | 做法 | 判断 |
|---|---|---|
| A | 合作企业做主体，开发者以团队成员参与。企业持有组织账号（可以由个人账号 App Transfer 过去），同一主体新增 APP 备案，并纳入已有的生成式 AI 备案或登记 | 推荐 |
| B | 自己成立公司，个人会员升级为组织。自己办 APP 备案和生成式 AI 登记，并与模型方签合作协议 | 可行，成本高 |
| C | 企业备案，个人账号发布 | 不可行。开发者名称和工信部记录对不上，授权书解决不了 |
| D | 个人账号加个人非经营性备案 | 不建议。不能收费，生成式 AI 登记基本办不了，调用企业的在线服务还会主体错配 |

### 美区与中国大陆

| 要求 | 美区 | 中国大陆 |
|---|---|---|
| 开发者账号 | 个人即可 | 实际要和备案主体一致，通常是企业 |
| 上架前的行政手续 | 无 | APP 备案，加上生成式 AI 备案或登记 |
| AI 内容标识 | 非强制（欧盟另有第 50 条） | 法定：显式和隐式 |
| 公示模型备案号 | 无 | 须公示 |
| 年龄 / 未成年人 | 新分级问卷。德州要接 Declared Age Range | 防沉迷义务 |
| 外部支付链接 | 允许，抽成另议。本项目不用 | 不允许 |
| 模型下载源 | Hugging Face 可用 | 需要 ModelScope 或境内 CDN |
| 远程服务的自填地址 | 保留，但要披露并取得同意 | 只允许已备案的服务 |

### 还没问清的问题

1. “已备案”具体是 ICP 备案号、生成式 AI 备案号，还是上线编号？主体是哪家公司，和面壁智能是什么关系？
2. 生成式 AI 备案的服务形式是否已经包含 iOS App？端侧运行的 MiniCPM 能否包含在内？
3. 合作企业是否已有 Apple 组织账号和 D-U-N-S？是否愿意接收 App Transfer？
4. 由哪个主体出具 MiniCPM / OpenBMB 名称和图标的授权书？
5. 有没有收费、广告或商业合作计划？和个人开发者是雇佣、外包，还是开源贡献？
6. 向省通信管理局确认：APP 负责人是否必须是员工、是否要授权书、模型下载域名是否要列入备案。
7. 技术待办（以后做国区时才做）：显式和隐式 AI 标识；下载源按地区切到 ModelScope；国区隐藏远程服务的自填地址；App 内公示备案号。

## 来源

访问日期都是 2026-11-12。有发布日期的写在条目末尾。

### 欧盟与隐私

- [EU AI Act 第 50 条（透明度义务）](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50) — AI Act Service Desk（欧盟委员会）
- [Article 50: Transparency Obligations](https://artificialintelligenceact.eu/article/50/) — artificialintelligenceact.eu
- [EDPB Guidelines 2/2023：ePrivacy 第 5(3) 条的技术范围（含 localStorage）](https://www.edpb.europa.eu/documents/guideline/guidelines-22023-on-technical-scope-of-art-53-of-eprivacy-directive_en) — EDPB
- [严格必要例外](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/) — ICO

### Apple

- [App privacy details（“收集”的定义、可选披露）](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [TN3183：Required reason API 条目](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Supported capabilities (iOS)：免费账号可用的能力](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)
- [Larger Text evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria/)
- [Apple Developer Program：个人与组织注册](https://developer.apple.com/programs/enroll/)
- [Developer account overview](https://developer.apple.com/support/compare-memberships/)
- [Updating your account information（个人升级为组织）](https://developer.apple.com/help/account/membership/updating-your-account-information/)
- [App Store Connect 用户与角色（个人账号的限制）](https://help.apple.com/app-store-connect/en.lproj/static.html)
- [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [Provide tax information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Invite external testers（TestFlight）](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- [Upcoming Requirements（最低 SDK、年龄分级）](https://developer.apple.com/news/upcoming-requirements/)
- [App 转移概述](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 页面所标最后更新 2026-10-16
- [Updated App Review Guidelines are now available](https://developer.apple.com/news/?id=92th7e5i) — 2026-10-16
- [Strengthening guidelines against NCII and bait-and-switch apps](https://developer.apple.com/news/?id=vvzx6cul) — 2026-10-16
- [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf)
- [Update for Apps Distributed in Texas](https://developer.apple.com/news/?id=sg176nne) — 2026-06-03
- [Age assurance developer Q&A](https://developer.apple.com/support/age-assurance/)
- [Apple-hosted asset pack size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/apple-hosted-asset-pack-size-limits/)
- [App information（含隐私政策 URL、中国大陆供应）](https://developer.apple.com/cn/help/app-store-connect/reference/app-information/app-information/)
- [设置你的开发者名称](https://developer.apple.com/cn/help/app-store-connect/create-an-app-record/set-your-developer-name/)

### 美区外链（本项目不适用，仅作背景）

- [Epic v. Apple 第九巡回法院判决](https://cdn.ca9.uscourts.gov/datastore/opinions/2025/12/11/25-2935.pdf) — 2025-12-11
- [Apple 提出美区外链佣金方案](https://9to5mac.com/2026/08/13/apple-proposes-commissions-of-up-to-15-for-off-app-store-purchases-in-the-us/) — 9to5Mac，2026-08-13。第三方报道

### 国区

- [《关于开展移动互联网应用程序备案工作的通知》解读](https://www.gov.cn/zhengce/202308/content_6897437.htm) — 中国政府网
- [互联网信息服务备案审批服务指南](https://hunca.miit.gov.cn/bsfw/bszn/art/2024/art_7ef0d8bd3b0d433ba4b9b277f883f74d.html) — 湖南省通信管理局
- [互联网信息服务管理办法（292 号令）](https://www.samr.gov.cn/zw/zfxxgk/fdzdgknr/bgt/art/2023/art_483f0dd8eb1b4dc5961e4e008bd4a083.html) — 市场监管总局
- [APP 备案实操“快问快答”](https://wxb.xzdw.gov.cn/qwfb/zyjs/202310/t20231018_406352.html) — 西藏网信办
- [生成式人工智能服务管理暂行办法](https://www.gov.cn/zhengce/202311/content_6917778.htm) — 中国政府网
- [生成式人工智能服务已备案信息公告（2026 年 7–8 月）](https://www.cac.gov.cn/2026-09/14/c_1791136833136332.htm) — 国家网信办
- [互联网新技术新应用信息服务备案系统上线通告](https://www.cac.gov.cn/2026-11/09/c_1795978604463007.htm) — 国家网信办
- [互联网信息服务深度合成管理规定](https://www.gov.cn/zhengce/202310/content_6909368.htm) — 中国政府网
- [人工智能生成合成内容标识办法](https://www.gov.cn/zhengce/zhengceku/202503/content_7014286.htm) — 中国政府网
- [人工智能拟人化互动服务管理暂行办法](https://www.cac.gov.cn/2026-04/10/c_1777558395078289.htm) — 国家网信办
- [促进和规范数据跨境流动规定](https://www.gov.cn/zhengce/202501/content_6997438.htm) — 中国政府网
- [大模型备案与大模型登记](https://developer.cloud.tencent.cn/article/2736065) — 腾讯云开发者社区。第三方
- [关于受理生成式人工智能服务备案的公告](https://www.zjwx.gov.cn/art/2024/5/6/art_1673564_58874992.html) — 浙江网信办
- [端侧生成式 AI 服务备案](https://jianshenlaw.com/articles/on-device-ai-filing-guide/) — 简深律师事务所。律所解读
- [App Store 校验开发者名称](https://juejin.cn/post/7351613645460160531) — 掘金。开发者实测，**待核实**

仓库本身：[IceblueSakura/minicpm-design](https://github.com/IceblueSakura/minicpm-design)。
