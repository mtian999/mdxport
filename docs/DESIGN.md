````markdown
---
status: draft
owner: formula
version: 0.3
last_reviewed: 2025-12-17
product_name: MDXport
tech_route: typst_wasm_client_only
tags: [prd, markdown, export, pdf, chinese, client-only, ai-doc, typst]
---

# MDXport 产品文档（Typst 技术路线 · 完整版）

## 0. 一句话与结论

MDXport 是一个**纯客户端（浏览器端）**的 “Markdown → X” 导出工具，专注把 **AI 产出的 Markdown 草稿**变成**中文稳定、可交付**的文件：默认一键导出 **PDF（Typst 编译）**，并逐步扩展到 HTML/EPUB/DOCX/PPTX 等格式。

核心判断：  
- **PDF 交付**最容易出事故（分页、目录、页眉页脚、中文字体），用 **Typst** 作为“排版引擎”能显著降低你自研排版系统的风险。  
- “任意格式”不能靠 Typst 一把梭：Typst 负责**分页类输出**；其他格式靠统一 **Document IR** 走独立 exporter。

---

## 1. 产品定位

### 1.1 解决的问题（针对 AI 文档交付）
AI 让写作变快，但交付仍然慢，主要卡在：
- **结构不可靠**：标题层级、表格、列表、代码块经常“差一点点”，导出就崩。
- **中文不稳定**：缺字/豆腐块/字体漂移导致版式每台机器不一样。
- **隐私与复现**：在线转换要上传正文或加载外链资源，敏感文档不敢用；输出不可复现。
- **交付质感差**：缺封面、目录、页眉页脚、页码、品牌样式；看上去像草稿。

MDXport 的定位不是“转换站”，而是：  
> **AI 文档交付管线（Preflight + 模板 + 排版引擎）**

### 1.2 目标用户
- AI 重度写作者：PM/工程师/创始人/咨询/研究/投标
- 隐私敏感：不允许上传第三方
- 需要统一模板：公司/团队对外输出规范

### 1.3 产品原则（必须守）
1) **稳定交付 > 语法全兼容**：不装懂，宁可报错/降级，也不输出“看似成功但不可用”的 PDF。
2) **中文字体是产品能力**：不赌系统环境；默认嵌入字体。
3) **默认不联网**：远程图片/字体默认禁；用户显式开启才允许。
4) **可复现**：同输入 + 同模板 + 同版本 → 输出尽量一致。
5) **AI 友好**：提供 Prompt Pack + Markdown Profile，把输入噪声从源头压下去。

---

## 2. 产品功能

## 2.1 核心用户流程（MVP）
1) 粘贴 / 导入 AI Markdown  
2) 选择模板（技术方案/周报/PRD/报告）  
3) Preflight：问题列表 + 一键修复  
4) 预览（分页效果）  
5) 一键导出（默认 PDF）→ 直接下载

---

## 2.2 Markdown Profile（AI 输入契约）
> 你不可能“支持互联网上所有 Markdown”，你只能“支持交付所需的一套子集”。

**支持（v0.1）**
- 标题（H1~H6）、段落、粗体/斜体/删除线、链接
- 有序/无序列表（任务列表可选）
- GFM 表格（简单表）
- 引用块
- fenced 代码块 + 行内代码
- 图片（本地/拖拽导入/内嵌）
- 扩展控制：`<!-- pagebreak -->`、`<!-- keep-with-next -->`

**默认禁止/降级**
- 内嵌 HTML（sanitize + 降级为纯文本或代码块）
- 复杂嵌套表格/未识别扩展（降级为代码块或拆分）
- 默认禁止远程资源加载（图片/字体）

---

## 2.3 Preflight（面向 AI 的核心差异化）
Preflight 不是“代码 lint”，目标是：**把草稿推到可交付状态**。

### 规则输出模型
- severity：error / warn / info
- location：AST/IR 节点定位（可高亮）
- message：可读解释（短）
- fix：可选 patch（自动修复）或 action（用户手工处理）

### MVP 必做规则（建议 ≥ 12 条）
- 标题层级跳跃（H1→H3）、重复 H1
- 表格列数不齐、缺分隔行
- 列表缩进错误导致结构断裂
- 代码块未闭合 / 缺 language（默认 text）
- 超长 token/URL 溢出（插入软换行策略 / 显示文本缩短）
- 外链图片（默认阻止，提示“拖拽本地图片替换”）
- 控制字符/零宽字符清理
- 超大图片（压缩/重采样建议）
- 文档元信息缺失（标题/作者/日期）
- 章节过长导致“目录不可读”（建议拆分）
- 混用全角/半角标点造成断行异常（提示/可选修正）
- 非法链接括号不配对（修复）

---

## 2.4 模板系统（Typst 驱动）
模板不是“换皮肤”，模板决定交付质量。

模板能力（v0.1）
- 封面：标题/作者/日期/Logo（可选）
- 目录：按标题生成（可选）
- 页眉/页脚：文档名 / 章节名 / 页码（可配置）
- 字体/字号/行距/段间距统一
- 代码块样式、表格样式、引用样式统一

模板文件建议形态：
- `template.typ`：样式与宏（header/footer/toc/table/code）
- `main.typ`：渲染入口（接收 meta + 内容块）
- `theme.json`：可视化参数（颜色、logo、保密水印、边距）

示例（概念）
```typst
#let mdxport(meta, body) = {
  set document(title: meta.title, author: meta.author)
  set page(margin: (top: 18mm, bottom: 16mm))
  show heading: it => heading_style(it)
  header(meta)
  body
  footer(meta)
}
````

---

## 2.5 导出格式（路线图）

* P0：PDF（Typst）✅
* P1：PNG（按页）/ SVG（图形）✅（复用 Typst 输出能力）
* P1：HTML（用于知识库/网页发布）——不依赖 Typst（走 IR→HTML exporter）
* P2：EPUB（可重排电子书）——走 IR→EPUB exporter（不要执念 MOBI）
* P2：DOCX / PPTX（二选一先落地，模板化导出）

> 关键原则：**同一份 Document IR 驱动所有 exporter**。绝不允许每个格式重复解析 Markdown。

---

## 3. 技术架构（Typst 纯客户端路线）

## 3.1 总体架构

```
UI Layer
 ├─ Editor (Markdown)
 ├─ Preflight Panel (issues + one-click fixes)
 ├─ Template Config (cover/toc/header/footer/branding)
 ├─ Preview (PDF preview + outline)
 └─ Export Panel (PDF/PNG/HTML/EPUB/...)

Core Pipeline
 ├─ Parser: Markdown -> AST
 ├─ Normalizer: AST -> Standard AST (Profile)
 ├─ Preflight: rules -> diagnostics + patches
 ├─ IR Builder: AST -> Document IR
 ├─ Typst Generator: IR -> Typst source + assets
 ├─ Typst Compiler (WASM): Typst -> PDF bytes (and PNG/SVG)
 └─ Other Exporters: IR -> HTML/EPUB/DOCX/PPTX

Local Runtime
 ├─ Font Manager (CJK fonts, cache, optional subsets)
 ├─ Asset Store (images, attachments) [IndexedDB/CacheStorage]
 ├─ Worker Pool (parse, preflight, typst compile)
 └─ Service Worker (optional PWA/offline)
```

---

## 3.2 关键设计：Document IR（必须）

你要把不稳定输入收敛成稳定结构，Typst 只是 downstream 引擎。

建议 IR（概念）

* `DocMeta { title, author, date, template_id, lang, confidentiality, paper, margins }`
* Block：

  * `Heading(level, text, id)`
  * `Paragraph(inlines)`
  * `List(ordered, items)`
  * `Table(columns, rows)`
  * `CodeBlock(lang, code)`
  * `Quote(blocks)`
  * `Image(asset_id, caption, sizing)`
  * `PageBreak`
  * `KeepWithNext(block)`（可选）
* Inline：`Text / Em / Strong / Code / Link`

约束：

* Preflight 在 AST/IR 层修复
* Typst Generator 不“猜测语义”，只做确定性映射
* 模板升级要 versioned（避免老项目导出漂移）

---

## 3.3 Typst 集成方式（纯客户端）

### 3.3.1 运行形态

* Typst 编译器以 **WASM** 形式运行在浏览器内
* 编译必须放在 **Web Worker**（避免主线程卡死）
* 与 UI 通信：`postMessage`（输入：typst 源码 + 虚拟文件系统；输出：pdf bytes + diagnostics）

### 3.3.2 虚拟文件系统（VFS）

Typst 编译需要“文件”，你在浏览器端提供一个 VFS：

* `/main.typ`（入口）
* `/template/template.typ`（模板宏）
* `/assets/img_*.png`（图片 bytes）
* `/fonts/*.ttf`（字体 bytes）
* `/meta.json`（可选：模板参数）

### 3.3.3 字体策略（成败点）

MVP（务实版）

* 内置 1 套简中字体 Regular + 1 套等宽字体（代码）
* 点击导出时 lazy-load 字体（显示进度条）
* 用 CacheStorage 缓存字体与 wasm（二次导出秒开）

进阶（v0.3+ 强烈建议）

* 字体分档：Basic（常用字）/ Full（全量）
* 字体子集化：按文档用字裁剪 → 嵌入（减少体积、减少内存峰值）

### 3.3.4 资源与安全

* 默认禁止远程 URL：图片必须本地化（拖拽/上传/粘贴截图）
* sanitize：剥离 HTML 与潜在脚本
* 限制资源规模：单图上限、总资源上限、最大页数/字符数（防浏览器崩溃）

---

## 3.4 IR → Typst 映射规则（关键可控）

你需要一份“映射白名单”，保证结果稳定：

* Heading：`= / == / ===` 或 `#heading(level: n)[...]`
* Paragraph：普通文本块；inline 样式转 Typst markup
* List：`- item` / `+` / `1.`（注意嵌套缩进一致）
* Table：用 Typst 表格语法（模板统一表格样式、列宽策略）
* CodeBlock：`#raw(lang: "...", block: true)[...]`（避免 Typst 误解析）
* Quote：`#quote[...]`
* Image：`#image("assets/img.png", width: ...)`（模板控制 caption）
* PageBreak：`#pagebreak()`（或模板宏）
* KeepWithNext：可用“block grouping/keep”策略（模板层实现；做不到就降级为提示）

关键实现要求：

* 生成 Typst 源码时要做 **escape/quoting**，防止用户文本触发 Typst 语法歧义
* 生成稳定 id（目录/锚点）用于目录与页眉显示

---

## 3.5 预览策略（不要把体验做死）

* 快速预览：HTML 预览（不分页，秒开）
* 交付预览：Typst 编译的 PDF 预览（所见即所得）
* 预览编译要做“增量体验”：用户停止输入 500ms 后再触发（并可取消上一次编译）

---

## 3.6 其他格式导出（Typst 之外）

Typst 是你“分页引擎”，但不是“万能转换器”。

* HTML：IR → HTML + CSS（更适合知识库/网页）
* EPUB：IR → XHTML + OPF + nav.xhtml → zip（纯客户端即可）
* DOCX/PPTX：IR → 模板化映射（明确不追求 100% 版式等价）

---

## 4. 质量与测试（必须工程化）

### 4.1 Golden 文档集（AI 样本库）

* 技术方案（目录、表格、代码、图片）
* PRD（大量列表/表格/链接）
* 周报（短、多段）
* 研究报告（长文、引用）
* 极端样例（超长 token、超宽表格、混合中英、emoji）

### 4.2 自动化校验（浏览器端/CI）

* PDF 文本抽取一致性（中文不丢字、可复制）
* 页数/目录存在性
* 表格溢出检测（基于渲染后布局信息或规则启发）
* 性能预算：导出耗时、内存峰值、输出体积阈值

---

## 5. 里程碑（建议按风险切）

### v0.1（2–4 周）

* Markdown→AST→IR→Typst→PDF（Worker）
* 12 条 Preflight 规则 + 一键修复
* 1 套模板（技术方案）+ 封面/页眉页脚/页码/基础目录
* 中文字体内置 + 缓存

### v0.2（4–8 周）

* 模板库 ≥ 4（技术方案/周报/PRD/研究报告）
* 资源面板（图片本地化、压缩建议、引用追踪）
* 预览体验优化（取消/防抖/进度）
* HTML exporter（IR→HTML包）

### v0.3（8–12 周）

* 字体包管理（Basic/Full）+ 子集化（如果你真想规模化，这是硬门槛）
* PNG 按页导出（复用 Typst）
* EPUB exporter（IR→EPUB）
* DOCX/PPTX 二选一先落地（模板化，不做“Word 级排版承诺”）

---

## 6. 风险清单（Typst 路线特有）

1. **WASM + CJK 字体体积/内存峰值**：不做 lazy-load/缓存/子集化，移动端会崩。
2. **表格跨页/超宽表格**：Typst 能做，但需要模板里明确策略（缩放/换页/横向页/拆表）。
3. **浏览器差异**：Safari 的下载与内存限制更苛刻；必须明确支持范围与降级策略。
4. **模板版本漂移**：模板升级会导致老文档输出变样；必须 template version pinning。
5. **Typst 生态依赖**：你内置第三方 typst 包/模板时要锁版本并做许可证与兼容评估。

---

## 7. 开放问题（你必须做取舍）

* 你更想卖“Markdown → X 工具”，还是“AI 草稿 → 交付物”？
  前者拼 SEO 和功能广度；后者拼交付质量与模板/品牌包。
* PDF 之外的第二格式：HTML 还是 EPUB？
  如果用户主要是企业知识库：HTML 更强；如果是长文分发：EPUB 更强。
* 字体策略：你接受“第一次导出下载几十 MB”吗？
  如果不接受，就必须把子集化提前到 v0.2/v0.3。

---

```

如果你下一步要进入实现，我建议你先把两份“工程级规范”写死（否则会发散）：
1) **Markdown Profile v0.1（允许/禁止/降级规则 + 示例）**  
2) **IR → Typst 映射规范 v0.1（每个节点怎么渲染、哪些必须模板提供、哪些必须 escape）**

你要的话我可以直接把这两份规格也补齐到可开工的程度（含测试样例）。
::contentReference[oaicite:0]{index=0}
```
