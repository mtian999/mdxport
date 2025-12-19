<script lang="ts">
  import { browser } from '$app/environment'
  import { goto } from '$app/navigation'
  import { onMount, tick } from 'svelte'
  import { getPdfjs } from '$lib/pdf/pdfjs'
  import { markdownToTypst } from '$lib/pipeline/markdownToTypst'
  import { TypstWorkerClient } from '$lib/workers/typstClient'
  import type { UILang } from '$lib/i18n/lang'
  import { renderMermaidToSvg } from '$lib/mermaid/render'

  import 'pdfjs-dist/web/pdf_viewer.css'

  import type { PDFDocumentLoadingTask, PDFDocumentProxy } from 'pdfjs-dist'
  import type { PDFLinkService, PDFViewer } from 'pdfjs-dist/web/pdf_viewer.mjs'

  // Props
  interface Props {
    lang: UILang
    seoTitle: string
    seoDescription: string
    initialMarkdown?: string
  }

  let {
    lang = 'en',
    seoTitle,
    seoDescription,
    initialMarkdown = '',
  }: Props = $props()

  // ========================================
  // Default Markdown Content (as README)
  // ========================================
  const WELCOME_MARKDOWN = {
    zh: `---
lang: zh
title: MDXport 功能演示
authors:
  - MDXport Team
date: ${new Date().toISOString().split('T')[0]}
---

# 将原始 Markdown 和 AI 草稿转化为专业级 PDF

### 您 LLM 输出与专业报告之间更近的一步
MDXport 旨在提供稳定的分页、尝试自动修复常见的格式错误并为品牌规范提供支持——100% 在您的浏览器本地运行。

- **工程级分页**：表格表头尝试自动重复、处理标题孤行、智能换页建议。
- **主动预检**：检测并提示损坏的数学块、溢出的代码块和常见的嵌套问题。
- **确定性构建**：相同的输入 + 锁定的模板/引擎版本 = 每次都是完全相同的 PDF。
- **本地优先安全**：您的商业机密永远不会离开您的设备。

[ 立即尝试 → ](https://mdxport.com) &nbsp; [ 查看项目 · GitHub ](https://github.com/cosformula/mdxport)

*由 WASM 驱动。可验证、可重现。*

---

### 3 个核心 Feature 卡片

#### 1. 拯救导出的预检 (Active Preflight & Verification)
AI 生成的 Markdown 通常在“视觉上没问题”但“结构上不完整”。MDXport 充当预检工具：它尝试在导出前检测不匹配的定界符或错误嵌套、提示溢出的代码块，并正确处理常见的 LaTeX 数学语法。

#### 2. 是排版逻辑，而非简单的“打印到 PDF” (Smart Paging & Navigation)
浏览器并不擅长打印。MDXport 处理最棘手的部分：跨页自动重复表格表头、防止标题单独出现在页面底部（孤立行）、并自动生成完全可点击的目录 (TOC) 和 PDF 书签结构。

#### 3. 可扩展的品牌化 (Design Tokens & Branding) - 敬请期待
不要让您的团队弄乱字体。未来，您将可以使用锁定且带版本的模板。添加机密水印、自定义页眉/页脚，并定义您自己的品牌 Token (theme.json) 以完美匹配您的形象。

---

### 为什么不是 Pandoc / Notion / Typora？

| 工具 | 优劣对比 |
| :--- | :--- |
| **Pandoc** | **学术界的金标准，但配置是噩梦。** <br> Pandoc 功能强大，但通常需要手动安装二进制环境、数 GB 的 LaTeX 工具链，并调试晦涩的模板错误。**MDXport 的不同之处**：零配置，无需安装工具链；视觉反馈，实时查看预检问题。 |
| **Notion** | **非常适合 Wiki，但在导出为固定格式时有局限性。** <br> Notion 文档是“流式”的，针对屏幕阅读优化，直接导出 PDF 有时会遇到宽表格截断等挑战。**MDXport 的尝试**：提供固定布局选项，针对 A4 打印优化；Git 友好，保持源码为 Markdown。 |
| **Typora** | **优秀的编辑器，偏向个人写作体验。** <br> Typora 为写作而生，而非流水线发布。PDF 输出结果可能受到本地 CSS 样式和特定排版配置的影响。**MDXport 的不同之处**：致力于提供 100% 可重现的流程；关注团队一致性，无论 OS 如何，力求提供统一的边距和布局。 |

---

## 排版功能演示

### 文本格式

这是一段普通段落，包含 **加粗**、_斜体_、\`行内代码\`、以及一个 [内联链接](https://example.com)。

### 扩展语法
- [toc]
- ~~删除文本~~
- 上标^sup^ 下标~sub~
- 脚注支持[^1]

[^1]: 这是一个脚注示例。

### 嵌套列表

- 产品特性
  - 客户端运行
  - 隐私保护
- 技术架构
  1. Typst 排版引擎
  2. WebAssembly 编译
  3. PDF.js 预览

### 代码块
\`\`\`typescript
const pdf = await compile(markdown);
\`\`\`

### 数学公式

行内公式：$ E = m c^2 $

块级公式：
$$
a^2 + b^2 = c^2
$$

### 流程图 (Mermaid)

\`\`\`mermaid
graph LR;
    Markdown-->Typst;
    Typst-->PDF;
\`\`\`

> **提示**：你可以拖放 \`.md\` 文件到编辑器直接导入，或使用顶部的模板快速开始。
`,
    en: `---
lang: en
title: MDXport Feature Demo
authors:
  - MDXport Team
date: ${new Date().toISOString().split('T')[0]}
---

# Turn Raw Markdown & AI Drafts into Client-Ready PDFs.

### A better bridge between LLM output and professional reports.
MDXport aims for stable pagination, attempts to catch common formatting errors, and provides a path for branding—running 100% locally in your browser.

- **Engineered Pagination**: Strives for repeating table headers, orphan prevention, and smart breaks.
- **Active Preflight**: Detects & flags common math block issues, overflowing code, and bad nesting.
- **Reproducible Output**: Same input + Pinned template/engine versions = Same PDF.
- **Local-First Security**: Your commercial specs never leave your device.

[ Try in the browser → ](https://mdxport.com) &nbsp; [ View Project · GitHub ](https://github.com/cosformula/mdxport)

*Powered by WASM. Deterministic & reproducible.*

---

### Core Features

#### 1. Preflight for better exports
**Active Preflight & Verification**

AI-generated Markdown is often "visually okay" but "structurally broken." MDXport acts as a preflight tool: it attempts to detect mismatched delimiters & invalid nesting, flags overflowing code blocks, and renders most LaTeX-style math in Markdown correctly.

#### 2. Layout logic, not just "Print to PDF"
**Smart Paging & Navigation**

Browsers are bad at printing. MDXport handles the hard stuff: repeating table headers across pages, preventing headings from sitting alone at the bottom of a page (orphans), and generating a fully clickable TOC + PDF Bookmarks structure automatically.

#### 3. Branding that scales (Coming Soon)
**Design Tokens & Branding**

Don’t let your team mess up the fonts. In the future, you will be able to use locked, versioned templates for PRDs, Contracts, or Research. Add confidentiality watermarks, custom headers/footers, and bring your own design tokens (theme.json) to match your brand identity perfectly.

---

### Why not Pandoc / Notion / Typora?

| Tool | Comparison |
| :--- | :--- |
| **Pandoc** | **The gold standard for academics, but a nightmare to configure.** <br> Pandoc is powerful, but usually requires manual installation of binaries, LaTeX toolchains, and debugging obscure template errors. **MDXport difference**: Zero Setup, Visual Feedback, Modern Defaults. |
| **Notion** | **Great for wikis, but has limitations for frozen deliverables.** <br> Notion documents are "fluid"—optimized for screens. Directly exporting to PDF can sometimes encounter challenges with ultra-wide tables. **MDXport's approach**: Fixed Layout, Repo-Friendly, Local-First. |
| **Typora** | **Excellent editor, focused on personal writing experience.** <br> Typora is designed for writing, not automated publishing pipelines. PDF output can vary based on local CSS themes and specific configurations. **MDXport difference**: Aims for a 100% reproducible pipeline; team consistency across OS with unified margins and fonts. |

---

## Typesetting Demo

### Text Formatting
This is a regular paragraph with **bold**, _italic_, \`inline code\`, and an [inline link](https://example.com).

### Extended Syntax
- [toc]
- ~~Strikethrough~~
- Super^sup^ Sub~sub~
- Footnote[^Note]

[^Note]: This is a footnote example.

### Nested Lists

- Product Features
  - Client-side processing
  - Privacy protection
- Tech Stack
  1. Typst typesetting engine
  2. WebAssembly compilation
  3. PDF.js preview

### Code Block
\`\`\`typescript
const pdf = await compile(markdown);
\`\`\`

### Math Formula

Inline: $ E = m c^2 $

Block:
$$
a^2 + b^2 = c^2
$$

### Diagram (Mermaid)

\`\`\`mermaid
graph LR;
    Markdown-->Typst;
    Typst-->PDF;
\`\`\`

> **Tip**: You can drag and drop \`.md\` files into the editor, or use the templates in the top bar to get started quickly.
`,
  }

  const TEMPLATES = {
    zh: {
      empty: { name: '空白文档', content: '' },
      welcome: { name: '快速入门', content: WELCOME_MARKDOWN.zh },
      techDoc: {
        name: '技术方案',
        content: `---
title: 技术方案文档
date: ${new Date().toISOString().split('T')[0]}
---

# 项目概述

## 背景
1. Phase 1
2. Phase 2
3. Phase 3

## Risk Assessment

## Summary
`,
      },
      weeklyReport: {
        name: 'Weekly Report',
        content: `# Weekly Report - ${new Date().toISOString().split('T')[0]}

## Completed

- [ ] Task 1
- [ ] Task 2

## Next Week

- [ ] Plan 1
- [ ] Plan 2

## Issues & Risks

## Notes
`,
      },
    },
  }

  const SEO_LINKS = [
    {
      path: 'convert-chatgpt-table-to-pdf',
      title: {
        zh: 'ChatGPT 表格转 PDF',
        en: 'ChatGPT Table to PDF',
      },
    },
    {
      path: 'notion-export-pdf-layout-fix',
      title: {
        zh: 'Notion 导出 PDF 修复',
        en: 'Notion Export PDF Fix',
      },
    },
    {
      path: 'secure-offline-markdown-to-pdf-converter',
      title: {
        zh: '安全离线 PDF 工具',
        en: 'Secure Offline PDF',
      },
    },
    {
      path: 'typst-online-editor-alternative',
      title: {
        zh: 'Typst 在线替代',
        en: 'Typst Alternative',
      },
    },
  ]

  // State
  // Initialize markdown with initialMarkdown if provided, otherwise default
  let markdown = $state('')
  let hasInitialized = false

  $effect(() => {
    if (!hasInitialized) {
      markdown = initialMarkdown || WELCOME_MARKDOWN[lang] || ''
      hasInitialized = true
    }
  })

  let leftPaneWidth = $state(50)
  let isResizing = $state(false)
  let isDragging = $state(false)
  let style = $state('modern-tech') as 'modern-tech' | 'classic-editorial'

  // Mobile State
  let activeMobileTab = $state<'editor' | 'preview'>('editor')
  let isMenuOpen = $state(false)

  function toggleMenu(e?: Event) {
    if (e) {
      e.stopPropagation()
      e.preventDefault()
    }
    isMenuOpen = !isMenuOpen
  }

  function closeMenu() {
    isMenuOpen = false
  }

  // Derived filename
  let filename = $derived.by(() => {
    // Try to find first H1
    const h1Match = markdown.match(/^#\s+(.+)$/m)
    let base = h1Match ? h1Match[1].trim() : 'Untitled'

    // 1. Sanitize: Remove invalid FS chars and control chars
    // Replace invalid chars with space to preserve word separation
    base = base.replace(/[\\/:*?"<>|\x00-\x1F]/g, ' ')

    // 2. Normalize whitespace (collapse multiple spaces)
    base = base.replace(/\s+/g, ' ').trim()

    // 3. Fallback if empty
    if (!base) base = 'Untitled'

    // 4. Max length limit (e.g. 50 chars)
    const MAX_LEN = 50
    if (base.length > MAX_LEN) {
      base = base.substring(0, MAX_LEN).trim()
    }

    return `${base} - mdxport.com`
  })

  let status: 'idle' | 'compiling' | 'done' | 'error' = $state('idle')
  let errorMessage: string | null = $state(null)
  let pdfBytes = $state<Uint8Array | null>(null)
  let pdfUrl = $state<string | null>(null)

  // Loading state
  let isLoading = $state(true)
  let loadingText = $state('Initializing...')

  // PDF Viewer state
  let client = $state<TypstWorkerClient | null>(null)
  let pdfDoc = $state<PDFDocumentProxy | null>(null)
  let pdfPages = $state(0)
  let pdfPage = $state(1)
  let pdfScale = $state(1)
  let pdfViewer = $state<PDFViewer | null>(null)
  let pdfLinkService = $state<PDFLinkService | null>(null)
  let pdfViewerContainerEl = $state<HTMLDivElement | null>(null)
  let pdfViewerEl = $state<HTMLDivElement | null>(null)
  let pdfLoadTask: PDFDocumentLoadingTask | null = null
  let pdfLoadSeq = 0

  // Auto-compile
  let compileSeq = 0
  let hasEverCompiled = false
  let autoPreviewTimer: number | null = null

  // UI Text
  const UI = {
    zh: {
      new: '新建',
      template: '模板',
      export: '导出 PDF',
      loading: '正在初始化渲染引擎...',
      generating: '生成中...',
      langSwitch: 'EN',
      placeholder: '在这里输入 Markdown...',
    },
    en: {
      new: 'New',
      template: 'Template',
      export: 'Export PDF',
      loading: 'Initializing rendering engine...',
      generating: 'Generating...',
      langSwitch: '中',
      placeholder: 'Type Markdown here...',
    },
  }

  const SEO = {
    zh: {
      ogLocale: 'zh_CN',
    },
    en: {
      ogLocale: 'en_US',
    },
  }

  function t<K extends keyof typeof UI.zh>(key: K): string {
    return UI[lang][key]
  }

  // ========================================
  // Lifecycle
  // ========================================
  onMount(() => {
    // Save language preference
    try {
      localStorage.setItem('mdxport_lang', lang)
    } catch {
      // ignore
    }

    loadingText = t('loading')
    client = new TypstWorkerClient()

    let aborted = false

    void (async () => {
      const container = pdfViewerContainerEl
      const viewer = pdfViewerEl
      if (!container || !viewer) return

      await getPdfjs()
      const mod = await import('pdfjs-dist/web/pdf_viewer.mjs')
      if (aborted) return

      const eventBus = new mod.EventBus()
      const linkService = new mod.PDFLinkService({ eventBus })
      const pdfViewerInstance = new mod.PDFViewer({
        container,
        viewer,
        eventBus,
        linkService,
      })
      linkService.setViewer(pdfViewerInstance)

      eventBus.on('pagesinit', () => {
        pdfViewerInstance.currentScaleValue = 'page-width'
      })
      eventBus.on('pagechanging', (event: { pageNumber: number }) => {
        pdfPage = event.pageNumber
      })
      eventBus.on('scalechanging', (event: { scale: number }) => {
        pdfScale = event.scale
      })

      pdfLinkService = linkService
      pdfViewer = pdfViewerInstance

      // Hide loading overlay
      isLoading = false

      // Trigger first compile
      void compile(markdown, style, lang)
    })().catch((error) => {
      console.error(error)
      isLoading = false
    })

    // Close menu on click outside
    const handleClickOutside = (e: MouseEvent) => {
      // Logic handled in click handler on window or app div
      // simplified: if we are here, we clicked somewhere not stopping prop
      closeMenu()
    }
    window.addEventListener('click', handleClickOutside)

    // Debounced resize handler for auto-fit
    let resizeTimer: number | null = null
    const handleResize = () => {
      if (resizeTimer) clearTimeout(resizeTimer)
      resizeTimer = window.setTimeout(() => {
        fitWidth()
      }, 200)
    }
    window.addEventListener('resize', handleResize)

    return () => {
      aborted = true
      window.removeEventListener('click', handleClickOutside)
      window.removeEventListener('resize', handleResize)
      if (resizeTimer) clearTimeout(resizeTimer)
      client?.dispose()
      pdfLoadTask?.destroy()
      pdfDoc?.destroy()
      if (pdfUrl) URL.revokeObjectURL(pdfUrl)
    }
  })

  // Track previous language to detect changes
  let prevLang: UILang | null = null

  $effect(() => {
    if (!browser) return
    const currentLang = lang

    // Set html lang attribute
    document.documentElement.lang = currentLang

    // Save language preference
    try {
      localStorage.setItem('mdxport_lang', currentLang)
    } catch {
      // ignore
    }

    // Update default content when language changes
    if (prevLang !== null && prevLang !== currentLang) {
      // Check if current content is the old default template
      const oldDefault = WELCOME_MARKDOWN[prevLang]
      if (markdown === oldDefault || markdown.trim() === '') {
        markdown = WELCOME_MARKDOWN[currentLang]
      }
    }
    prevLang = currentLang
  })

  $effect(() => {
    if (!browser) return
    if (!client) return
    if (isLoading) return

    const md = markdown
    const _style = style
    const _lang = lang

    if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)

    const delay = hasEverCompiled ? 450 : 0
    autoPreviewTimer = window.setTimeout(() => {
      void compile(md, _style, _lang)
    }, delay)

    return () => {
      if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)
    }
  })

  // Auto-fit on mobile tab switch or resize
  $effect(() => {
    if (!browser) return
    // Trigger when switching to preview tab
    if (activeMobileTab === 'preview') {
      // Small delay to ensure layout is updated (container becomes visible)
      setTimeout(() => {
        fitWidth()
      }, 50)
    }
  })

  $effect(() => {
    if (!browser) return
    const bytes = pdfBytes
    if (!bytes) {
      pdfLoadTask?.destroy()
      pdfDoc?.destroy()
      pdfDoc = null
      pdfPages = 0
      pdfPage = 1
      pdfScale = 1
      return
    }

    const seq = ++pdfLoadSeq

    void (async () => {
      pdfLoadTask?.destroy()

      const pdfjs = await getPdfjs()
      const task: PDFDocumentLoadingTask = pdfjs.getDocument({ data: bytes })
      pdfLoadTask = task

      const doc: PDFDocumentProxy = await task.promise
      if (seq !== pdfLoadSeq) {
        void doc.destroy()
        return
      }

      void pdfDoc?.destroy()
      pdfDoc = doc
      pdfPages = doc.numPages
      pdfPage = 1

      pdfLinkService?.setDocument(doc)
      pdfViewer?.setDocument(doc)
    })().catch((error) => {
      console.error(error)
    })
  })

  // ========================================
  // Functions
  // ========================================
  async function compile(md: string, nextStyle: typeof style, docLang: UILang) {
    if (!client) return
    hasEverCompiled = true

    const seq = ++compileSeq
    status = 'compiling'
    errorMessage = null

    try {
      // Pre-process Mermaid blocks
      let processedMd = md
      const images: Record<string, Uint8Array> = {}

      const mermaidRegex = /```mermaid\n([\s\S]*?)\n```/g
      const matches = [...md.matchAll(mermaidRegex)]

      if (matches.length > 0) {
        let lastIndex = 0
        let newContent = ''

        for (const [index, match] of matches.entries()) {
          const [fullMatch, code] = match
          const id = `mermaid-${index}`
          const filename = `${id}.svg`

          try {
            const svg = await renderMermaidToSvg(code, id)
            images[filename] = svg

            newContent += md.slice(lastIndex, match.index)
            newContent += `![Mermaid Diagram](${filename})`
            lastIndex = (match.index || 0) + fullMatch.length
          } catch (e) {
            console.error('Mermaid render failed', e)
            newContent += md.slice(
              lastIndex,
              (match.index || 0) + fullMatch.length,
            )
            lastIndex = (match.index || 0) + fullMatch.length
          }
        }
        newContent += md.slice(lastIndex)
        processedMd = newContent
      }

      const mainTypst = markdownToTypst(processedMd, {
        style: nextStyle,
        lang: docLang,
      })
      // @ts-ignore
      const pdfData = await client.compilePdf(mainTypst, images)
      if (seq !== compileSeq) return
      setPdfPreview(pdfData.pdf)
      status = 'done'
    } catch (error) {
      if (seq !== compileSeq) return
      status = 'error'
      errorMessage = error instanceof Error ? error.message : String(error)
    }
  }

  function setPdfPreview(bytes: Uint8Array<ArrayBuffer>) {
    pdfBytes = bytes
    if (pdfUrl) URL.revokeObjectURL(pdfUrl)
    const blob = new Blob([bytes], { type: 'application/pdf' })
    pdfUrl = URL.createObjectURL(blob)
  }

  function downloadPdf() {
    if (!pdfUrl) return
    const a = document.createElement('a')
    a.href = pdfUrl
    a.download = filename + '.pdf'
    a.click()
  }

  function openPdfNewTab() {
    if (!pdfUrl) return
    window.open(pdfUrl, '_blank')
  }

  function handleNew() {
    markdown = ''
  }
  let fileInputEl = $state<HTMLInputElement | null>(null)

  function handleOpenFile() {
    fileInputEl?.click()
  }

  function onFileSelected(e: Event) {
    const target = e.target as HTMLInputElement
    const file = target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (evt) => {
      const content = evt.target?.result
      if (typeof content === 'string') {
        markdown = content
      }
    }
    reader.readAsText(file)
    // Reset value so same file can be selected again
    target.value = ''
  }

  function handleHelp() {
    const defaultContent = WELCOME_MARKDOWN[lang]
    if (markdown.trim() !== '' && markdown !== defaultContent) {
      const msg =
        lang === 'zh'
          ? '这将覆盖当前内容，确定吗？'
          : 'This will overwrite current content. Continue?'
      if (!confirm(msg)) return
    }
    markdown = defaultContent
  }

  function switchLang() {
    const targetLang = lang === 'zh' ? 'en' : 'zh'
    void goto(`/${targetLang}/`)
  }

  // ========================================
  // Resizer Logic
  // ========================================
  function startResize(e: MouseEvent) {
    e.preventDefault()
    isResizing = true
    document.addEventListener('mousemove', onResize)
    document.addEventListener('mouseup', stopResize)
  }

  function onResize(e: MouseEvent) {
    if (!isResizing) return
    const containerWidth = window.innerWidth
    const newWidth = (e.clientX / containerWidth) * 100
    leftPaneWidth = Math.min(Math.max(newWidth, 20), 80)
  }

  function stopResize() {
    isResizing = false
    document.removeEventListener('mousemove', onResize)
    document.removeEventListener('mouseup', stopResize)
    // Auto-fit PDF after resize
    fitWidth()
  }

  // ========================================
  // Drag & Drop Logic
  // ========================================
  function handleDragOver(e: DragEvent) {
    e.preventDefault()
    isDragging = true
  }

  function handleDragLeave(e: DragEvent) {
    e.preventDefault()
    isDragging = false
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault()
    isDragging = false

    const files = e.dataTransfer?.files
    if (!files || files.length === 0) return

    const file = files[0]
    if (
      !file.name.endsWith('.md') &&
      !file.name.endsWith('.markdown') &&
      !file.name.endsWith('.txt')
    ) {
      return
    }

    // filename derivation logic is implicit in reactivity
    // But wait, filename is derived from MARKDOWN content's H1.
    // The drop sets the markdown content.

    // Read logic
    const reader = new FileReader()
    reader.onload = (event) => {
      const content = event.target?.result
      if (typeof content === 'string') {
        markdown = content
      }
    }
    reader.readAsText(file)
  }

  function fitWidth() {
    if (!pdfViewer || !pdfViewerContainerEl) return
    // Check if visible to avoid "offsetParent is not set" error
    if (pdfViewerContainerEl.offsetParent === null) return
    pdfViewer.currentScaleValue = 'page-width'
  }
</script>

<svelte:head>
  <title>{seoTitle}</title>
  <meta name="description" content={seoDescription} />

  <!-- Canonical - logic might need to be passed in or derived from URL if we want it perfect -->

  <!-- Open Graph -->
  <meta property="og:title" content={seoTitle} />
  <meta property="og:description" content={seoDescription} />
  <meta property="og:type" content="website" />
  <meta property="og:locale" content={SEO[lang].ogLocale} />
  <meta
    property="og:locale:alternate"
    content={lang === 'zh' ? 'en_US' : 'zh_CN'}
  />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content={seoTitle} />
  <meta name="twitter:description" content={seoDescription} />
</svelte:head>

<!-- Loading Overlay -->
<div class="loading-overlay" class:hidden={!isLoading}>
  <div class="loading-spinner"></div>
  <div class="loading-progress">
    <div class="loading-progress-bar"></div>
  </div>
  <div class="loading-text">{loadingText}</div>
</div>

<!-- Main App -->
<div
  class="app"
  class:drop-zone-active={isDragging}
  ondragover={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleDrop}
  role="application"
>
  <!-- File Input (Hidden) -->
  <input
    type="file"
    accept=".md,.markdown,.txt"
    style="display: none;"
    bind:this={fileInputEl}
    onchange={onFileSelected}
  />

  <!-- Navbar -->
  <nav class="navbar">
    <div class="navbar-left">
      <a href="/{lang}/" class="logo-link">
        <img src="/logo.png" alt="MDXport" class="logo-img" />
      </a>
      <a
        href="https://github.com/cosformula/mdxport"
        target="_blank"
        rel="noopener noreferrer"
        class="nav-icon"
        title="View on GitHub"
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path
            d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"
          ></path>
        </svg>
      </a>
    </div>
    <div class="navbar-center">
      <!-- Removed filename input -->
    </div>
    <div class="navbar-right">
      <select class="style-select" bind:value={style}>
        <option value="modern-tech"
          >{lang === 'zh' ? '现代风' : 'Modern'}</option
        >
        <option value="classic-editorial"
          >{lang === 'zh' ? '经典风' : 'Classic'}</option
        >
      </select>

      <!-- New Tab / Preview Button (Visible on Desktop/Tablet, Icon on Mobile) -->
      <button
        class="btn btn-ghost btn-sm btn-icon-mobile hidden-mobile"
        onclick={openPdfNewTab}
        disabled={!pdfUrl || status === 'compiling'}
        title={lang === 'zh' ? '在新标签页打开 PDF' : 'Open PDF in New Tab'}
      >
        <span class="icon-only">
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            ><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"
            ></path><polyline points="15 3 21 3 21 9"></polyline><line
              x1="10"
              y1="14"
              x2="21"
              y2="3"
            ></line></svg
          >
        </span>
        <span class="text-label">{lang === 'zh' ? '在线预览' : 'Open PDF'}</span
        >
      </button>

      <button
        class="btn btn-primary btn-sm"
        onclick={downloadPdf}
        disabled={!pdfUrl || status === 'compiling'}
      >
        {status === 'compiling' ? t('generating') : t('export')}
      </button>

      <!-- Language Switch (Restored) -->
      <button class="btn btn-ghost btn-sm" onclick={switchLang}>
        {t('langSwitch')}
      </button>

      <!-- Menu Button (More) -->
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="menu-container" onclick={(e) => e.stopPropagation()}>
        <button
          class="btn btn-ghost btn-sm btn-icon"
          class:active={isMenuOpen}
          onclick={toggleMenu}
          aria-label="Menu"
          style="color: var(--color-gray-900);"
        >
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <circle cx="12" cy="12" r="2" fill="currentColor" stroke="none"
            ></circle>
            <circle cx="19" cy="12" r="2" fill="currentColor" stroke="none"
            ></circle>
            <circle cx="5" cy="12" r="2" fill="currentColor" stroke="none"
            ></circle>
          </svg>
        </button>

        {#if isMenuOpen}
          <div class="dropdown-menu">
            <button
              class="menu-item show-mobile"
              onclick={() => {
                openPdfNewTab()
                closeMenu()
              }}
              disabled={!pdfUrl || status === 'compiling'}
            >
              <span class="menu-icon">🌐</span>
              {lang === 'zh' ? '在新页预览 PDF' : 'Preview PDF in New Tab'}
            </button>

            <button
              class="menu-item"
              onclick={() => {
                handleNew()
                closeMenu()
              }}
            >
              <span class="menu-icon">📄</span>
              {t('new')}
            </button>

            <button
              class="menu-item"
              onclick={() => {
                handleOpenFile()
                closeMenu()
              }}
            >
              <span class="menu-icon">📂</span>
              {lang === 'zh' ? '打开本地文件' : 'Open Local File'}
            </button>

            <button
              class="menu-item"
              onclick={() => {
                handleHelp()
                closeMenu()
              }}
            >
              <span class="menu-icon">❓</span>
              {lang === 'zh' ? '查看帮助' : 'Help & Guide'}
            </button>

            <div class="menu-divider"></div>

            <a href="/{lang}/resources/" class="menu-item">
              <span class="menu-icon">🛠️</span>
              {lang === 'zh' ? '更多资源与工具' : 'Resources & Tools'}
            </a>

            <div class="menu-divider"></div>

            <a
              href="mailto:cosformula@gmail.com"
              class="menu-item small"
              title={lang === 'zh' ? '联系我们' : 'Contact Us'}
            >
              <span class="menu-icon">✉️</span>
              {lang === 'zh' ? '联系我们' : 'Contact'}
            </a>
          </div>
        {/if}
      </div>
    </div>
  </nav>

  <!-- Workspace -->
  <main class="workspace">
    <!-- Editor Pane -->
    <section
      class="pane editor-pane"
      class:mobile-hidden={activeMobileTab !== 'editor'}
      style="width: {leftPaneWidth}%"
    >
      <textarea
        class="editor"
        bind:value={markdown}
        spellcheck="false"
        placeholder={t('placeholder')}
      ></textarea>
      {#if errorMessage}
        <div class="error-bar">{errorMessage}</div>
      {/if}
    </section>

    <!-- Resizer -->
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div
      class="resizer"
      class:active={isResizing}
      onmousedown={startResize}
      role="separator"
      aria-orientation="vertical"
      tabindex="0"
    ></div>

    <!-- Mobile Tab Switcher (Visible only on mobile) -->
    <div class="mobile-tabs">
      <button
        class="mobile-tab-btn"
        class:active={activeMobileTab === 'editor'}
        onclick={() => (activeMobileTab = 'editor')}
      >
        {lang === 'zh' ? '编辑' : 'Editor'}
      </button>
      <button
        class="mobile-tab-btn"
        class:active={activeMobileTab === 'preview'}
        onclick={() => (activeMobileTab = 'preview')}
      >
        {lang === 'zh' ? '预览' : 'Preview'}
      </button>
    </div>

    <!-- Preview Pane -->
    <section
      class="pane preview-pane"
      class:mobile-hidden={activeMobileTab !== 'preview'}
      style="width: {100 - leftPaneWidth}%"
    >
      <div class="preview-toolbar">
        <div class="pager">
          <button
            onclick={() => pdfPage > 1 && (pdfPage -= 1)}
            disabled={!pdfDoc || pdfPage <= 1}>←</button
          >
          <span class="page-info">{pdfPage} / {pdfPages || '—'}</span>
          <button
            onclick={() => pdfPages && pdfPage < pdfPages && (pdfPage += 1)}
            disabled={!pdfDoc || pdfPage >= pdfPages}>→</button
          >
        </div>
        <div class="zoom">
          <span class="zoom-level">{Math.round(pdfScale * 100)}%</span>
          <button onclick={fitWidth} disabled={!pdfDoc}>Fit</button>
        </div>
      </div>
      <div class="preview-container">
        <div class="pdfjs-container" bind:this={pdfViewerContainerEl}>
          <div class="pdfViewer" bind:this={pdfViewerEl}></div>
        </div>
        {#if status === 'compiling' && !pdfBytes}
          <div class="preview-placeholder">
            <div class="loading-spinner"></div>
          </div>
        {/if}
      </div>
    </section>
  </main>
</div>

<style>
  /* ========================================
	   App Container
	   ======================================== */
  .app {
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
  }

  /* ========================================
	   Navbar
	   ======================================== */
  .navbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: var(--navbar-height);
    padding: 0 var(--space-md);
    background: var(--color-white);
    border-bottom: 1px solid var(--color-gray-200);
    flex-shrink: 0;
  }

  .navbar-left,
  .navbar-center,
  .navbar-right {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
  }

  .navbar-left {
    flex: 0 0 auto;
  }

  .navbar-center {
    flex: 1;
    justify-content: center;
  }

  .navbar-right {
    flex: 0 0 auto;
    gap: var(--space-xs);
  }

  .navbar-right > .btn {
    padding-left: var(--space-md);
    padding-right: var(--space-md);
  }

  .logo-link {
    display: flex;
    align-items: center;
    height: 100%;
    text-decoration: none;
  }

  .logo-img {
    height: 48px;
    width: auto;
    display: block;
  }

  .nav-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    color: var(--color-gray-500);
    border-radius: var(--radius-sm);
    transition: all var(--transition-fast);
  }

  .nav-icon:hover {
    background: var(--color-gray-100);
    color: var(--color-gray-900);
  }

  .style-select {
    padding: 0.375rem 0.5rem;
    font-size: 0.8125rem;
    background: var(--color-gray-50);
    border: 1px solid var(--color-gray-200);
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  /* ========================================
	   Workspace
	   ======================================== */
  .workspace {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  .pane {
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* Editor Pane */
  .editor-pane {
    background: var(--editor-bg);
    position: relative;
  }

  .editor {
    flex: 1;
    width: 100%;
    padding: var(--space-lg);
    font-family: var(--font-mono);
    font-size: 0.875rem;
    line-height: 1.7;
    color: var(--color-gray-200);
    background: transparent;
    border: none;
    resize: none;
    outline: none;
  }

  .editor::placeholder {
    color: var(--color-gray-600);
  }

  .error-bar {
    padding: var(--space-sm) var(--space-md);
    font-size: 0.75rem;
    color: #ef4444;
    background: rgba(239, 68, 68, 0.1);
    border-top: 1px solid rgba(239, 68, 68, 0.2);
  }

  /* Preview Pane */
  .preview-pane {
    background: var(--preview-bg);
  }

  .preview-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-sm) var(--space-md);
    background: var(--color-white);
    border-bottom: 1px solid var(--color-gray-200);
  }

  .pager,
  .zoom {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
  }

  .pager button,
  .zoom button {
    padding: var(--space-xs) var(--space-sm);
    font-size: 0.75rem;
    background: var(--color-gray-100);
    border: 1px solid var(--color-gray-200);
    border-radius: var(--radius-sm);
    cursor: pointer;
  }

  .pager button:disabled,
  .zoom button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .page-info,
  .zoom-level {
    font-size: 0.75rem;
    color: var(--color-gray-500);
    font-family: var(--font-mono);
  }

  .preview-container {
    flex: 1;
    overflow: hidden;
    position: relative;
  }

  .pdfjs-container {
    position: absolute;
    inset: 0;
    overflow: auto;
    padding: var(--space-lg);
  }

  .preview-placeholder {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--preview-bg);
  }

  /* PDF Viewer Overrides */
  :global(.pdfViewer .page) {
    margin: 0 auto var(--space-md);
    box-shadow: var(--paper-shadow);
  }

  /* ========================================
     Mobile Layout
     ======================================== */
  /* ========================================
     Menu
     ======================================== */
  .menu-container {
    position: relative;
    display: inline-block;
  }

  .btn-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    padding: 0;
  }

  .dropdown-menu {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    width: 200px;
    background: var(--color-white);
    border: 1px solid var(--color-gray-200);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow-md);
    z-index: 1000;
    padding: var(--space-xs) 0;
    display: flex;
    flex-direction: column;
  }

  .menu-item {
    display: flex;
    align-items: center;
    width: 100%;
    padding: var(--space-xs) var(--space-sm);
    font-size: 0.8125rem;
    color: var(--color-gray-700);
    background: transparent;
    border: none;
    text-align: left;
    cursor: pointer;
    text-decoration: none;
    transition: background-color var(--transition-fast);
  }

  .menu-item:hover {
    background-color: var(--color-gray-50);
    color: var(--color-gray-900);
  }

  .menu-item:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .menu-item.small {
    font-size: 0.75rem;
    padding: 4px var(--space-sm);
  }

  .menu-icon {
    margin-right: var(--space-sm);
    font-size: 1rem;
    line-height: 1;
  }

  .menu-divider {
    height: 1px;
    background: var(--color-gray-100);
    margin: var(--space-xs) 0;
  }

  /* ========================================
    Mobile Layout
    ======================================== */
  .mobile-tabs {
    display: none;
  }

  @media (max-width: 768px) {
    .app {
      height: 100dvh; /* Use dynamic viewport height for mobile */
    }

    .navbar {
      padding: 0 var(--space-sm);
    }

    /* Remove specific footer mobile styles as footer is gone */

    /* Hide non-essential buttons on very small screens if needed, 
       but for now let's just make them smaller or rely on overflow scrolling if needed. */

    .workspace {
      flex-direction: column;
      position: relative;
    }

    .pane {
      width: 100% !important; /* Force full width */
      height: 100%;
      position: absolute; /* Stack them */
      inset: 0;
      z-index: 1;
      padding-bottom: 50px; /* Space for mobile tabs */
    }

    .pane.mobile-hidden {
      display: none; /* simple hide */
      z-index: 0;
    }

    .resizer {
      display: none;
    }

    /* Mobile Tabs */
    .mobile-tabs {
      display: flex;
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 50px;
      background: var(--color-white);
      border-top: 1px solid var(--color-gray-200);
      z-index: 100;
    }

    .mobile-tab-btn {
      flex: 1;
      border: none;
      background: transparent;
      font-size: 0.875rem;
      font-weight: 500;
      color: var(--color-gray-500);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
    }

    .mobile-tab-btn.active {
      color: var(--color-gray-900);
      background: var(--color-gray-50);
    }

    .mobile-tab-btn.active::after {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background: var(--color-gray-900);
    }

    .hidden-mobile {
      display: none !important;
    }

    .show-mobile {
      display: flex !important;
    }
  }

  .show-mobile {
    display: none;
  }
</style>
