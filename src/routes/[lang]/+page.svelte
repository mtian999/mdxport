<script lang="ts">
  import { browser } from '$app/environment'
  import { goto } from '$app/navigation'
  import { onMount } from 'svelte'
  import { getPdfjs } from '$lib/pdf/pdfjs'
  import { markdownToTypst } from '$lib/pipeline/markdownToTypst'
  import { TypstWorkerClient } from '$lib/workers/typstClient'
  import type { UILang } from '$lib/i18n/lang'
  import { renderMermaidToSvg } from '$lib/mermaid/render'

  import 'pdfjs-dist/web/pdf_viewer.css'

  import type { PDFDocumentLoadingTask, PDFDocumentProxy } from 'pdfjs-dist'
  import type { PDFLinkService, PDFViewer } from 'pdfjs-dist/web/pdf_viewer.mjs'

  // Get language from route params
  let { data }: { data: { lang: UILang } } = $props()

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

# 欢迎使用 MDXport

*试着修改这段文字，右侧会实时更新...*

## 核心亮点

| 特性 | 说明 |
| :--- | :--- |
| **🛡️ 隐私优先** | 基于 WASM 技术，所有数据都在浏览器本地处理，绝不上传服务器 |
| **✨ 智能修复** | 自动修复 AI 生成的 Markdown 排版问题：表格溢出、层级混乱、格式错误 |
| **📄 商务排版** | 内置思源宋体等中文字体，专业文档一键生成，所见即所得 |
| **⚡ 即开即用** | 无需安装、无需登录，打开网页直接使用 |

## 快速开始

1. 粘贴你的 **ChatGPT / Claude** 草稿到左侧编辑器
2. 观察右侧预览，排版问题会被自动修正
3. 点击右上角 **"导出 PDF"** 下载文档

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

# Welcome to MDXport

*Try editing this text — the preview updates in real-time...*

## Key Features

|Feature|Description|
|:---|:---|
|**🛡️ Privacy First**|Powered by WASM, all processing happens locally in your browser. No data upload.|
|**✨ Smart Cleanup**|Auto-fix AI-generated Markdown issues: table overflow, broken hierarchy, formatting errors|
|**📄 Pro Typesetting**|Built-in professional fonts, business-ready documents, what you see is what you get|
|**⚡ Zero Setup**|No installation, no login required. Just open and use.|

## Quick Start
1. Paste your **ChatGPT / Claude** draft into the left editor
2. Watch the right panel — formatting issues are auto-corrected
3. Click **"Export PDF"** in the top-right corner to download

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

  // ========================================
  // State
  // ========================================
  let markdown = $state(WELCOME_MARKDOWN[data.lang] || '')
  let leftPaneWidth = $state(50)
  let isResizing = $state(false)
  let isDragging = $state(false)
  let style = $state('modern-tech') as 'modern-tech' | 'classic-editorial'

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

  // Compile state
  // let status = $state<'idle' | 'compiling' | 'done' | 'error'>('idle')
  // let errorMessage = $state<string | null>(null)
  // let pdfBytes = $state<Uint8Array<ArrayBuffer> | null>(null)
  // let pdfUrl = $state<string | null>(null)

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

  // SEO Metadata
  const SEO = {
    zh: {
      title: 'MDXport · Markdown 转 PDF，排版一步到位',
      description:
        '专为 AI 生成内容设计的交付引擎。纯客户端运行，数据绝不上传，隐私零风险。自动修复排版错乱，一键解决表格溢出与层级问题。',
      ogLocale: 'zh_CN',
    },
    en: {
      title: 'MDXport · Markdown to PDF, Perfect Typesetting',
      description:
        'A delivery engine for AI-generated content. Runs entirely client-side, your data never leaves your browser. Auto-fix formatting issues with one click.',
      ogLocale: 'en_US',
    },
  }

  function t<K extends keyof typeof UI.zh>(key: K): string {
    return UI[data.lang][key]
  }

  // ========================================
  // Lifecycle
  // ========================================
  onMount(() => {
    // Save language preference
    try {
      localStorage.setItem('mdxport_lang', data.lang)
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
      void compile(markdown, style, data.lang)
    })().catch((error) => {
      console.error(error)
      isLoading = false
    })

    return () => {
      aborted = true
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
    const currentLang = data.lang

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
    const _lang = data.lang

    if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)

    const delay = hasEverCompiled ? 450 : 0
    autoPreviewTimer = window.setTimeout(() => {
      void compile(md, _style, _lang)
    }, delay)

    return () => {
      if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)
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
            // Fallback to original code block on error? Or show error text
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
    const defaultContent = WELCOME_MARKDOWN[data.lang]
    if (markdown.trim() !== '' && markdown !== defaultContent) {
      const msg =
        data.lang === 'zh'
          ? '这将覆盖当前内容，确定吗？'
          : 'This will overwrite current content. Continue?'
      if (!confirm(msg)) return
    }
    markdown = defaultContent
  }

  function switchLang() {
    const targetLang = data.lang === 'zh' ? 'en' : 'zh'
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

    filename = file.name.replace(/\.(markdown|txt)$/i, '.md')

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
    if (!pdfViewer) return
    pdfViewer.currentScaleValue = 'page-width'
  }
</script>

<svelte:head>
  <title>{SEO[data.lang].title}</title>
  <meta name="description" content={SEO[data.lang].description} />

  <!-- Canonical & Hreflang -->
  <link rel="canonical" href={`/${data.lang}/`} />
  <link rel="alternate" hreflang="zh-Hans" href="/zh/" />
  <link rel="alternate" hreflang="en" href="/en/" />
  <link rel="alternate" hreflang="x-default" href="/en/" />

  <!-- Open Graph -->
  <meta property="og:title" content={SEO[data.lang].title} />
  <meta property="og:description" content={SEO[data.lang].description} />
  <meta property="og:type" content="website" />
  <meta property="og:locale" content={SEO[data.lang].ogLocale} />
  <meta
    property="og:locale:alternate"
    content={data.lang === 'zh' ? 'en_US' : 'zh_CN'}
  />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content={SEO[data.lang].title} />
  <meta name="twitter:description" content={SEO[data.lang].description} />
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
      <span class="logo"><strong>MDXport</strong></span>
    </div>
    <div class="navbar-center">
      <!-- Removed filename input -->
    </div>
    <div class="navbar-right">
      <button class="btn btn-ghost btn-sm" onclick={handleNew}>
        {t('new')}
      </button>

      <button class="btn btn-ghost btn-sm" onclick={handleOpenFile}>
        {data.lang === 'zh' ? '打开' : 'Open'}
      </button>

      <button
        class="nav-icon btn-ghost btn-sm"
        onclick={handleHelp}
        title={data.lang === 'zh' ? '查看说明书' : 'View Guide'}
        style="width: 32px; padding: 0;"
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
          <circle cx="12" cy="12" r="10"></circle>
          <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
          <line x1="12" y1="17" x2="12.01" y2="17"></line>
        </svg>
      </button>

      <select class="style-select" bind:value={style}>
        <option value="modern-tech"
          >{data.lang === 'zh' ? '现代风' : 'Modern'}</option
        >
        <option value="classic-editorial"
          >{data.lang === 'zh' ? '经典风' : 'Classic'}</option
        >
      </select>

      <button
        class="btn btn-ghost btn-sm"
        onclick={openPdfNewTab}
        disabled={!pdfUrl || status === 'compiling'}
      >
        {data.lang === 'zh' ? '在线预览' : 'Open PDF'}
      </button>

      <button
        class="btn btn-primary btn-sm"
        onclick={downloadPdf}
        disabled={!pdfUrl || status === 'compiling'}
      >
        {status === 'compiling' ? t('generating') : t('export')}
      </button>

      <button class="btn btn-ghost btn-sm" onclick={switchLang}>
        {t('langSwitch')}
      </button>

      <a
        href="mailto:cosformula@gmail.com"
        class="nav-icon"
        title={data.lang === 'zh' ? '联系我们' : 'Contact Us'}
        aria-label="Contact"
      >
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path
            d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"
          ></path>
          <polyline points="22,6 12,13 2,6"></polyline>
        </svg>
      </a>
    </div>
  </nav>

  <!-- Workspace -->
  <main class="workspace">
    <!-- Editor Pane -->
    <section class="pane editor-pane" style="width: {leftPaneWidth}%">
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

    <!-- Preview Pane -->
    <section class="pane preview-pane" style="width: {100 - leftPaneWidth}%">
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

  .navbar-right .btn {
    padding-left: var(--space-md);
    padding-right: var(--space-md);
  }

  .logo {
    font-size: 1rem;
    letter-spacing: -0.02em;
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

  /* Dropdown */
  .dropdown {
    position: relative;
  }

  .dropdown-menu {
    display: none;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 50;
    min-width: 140px;
    padding: var(--space-xs);
    background: var(--color-white);
    border: 1px solid var(--color-gray-200);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-lg);
  }

  .dropdown:hover .dropdown-menu,
  .dropdown:focus-within .dropdown-menu {
    display: block;
  }

  .dropdown-item {
    display: block;
    width: 100%;
    padding: var(--space-sm) var(--space-md);
    text-align: left;
    font-size: 0.8125rem;
    background: none;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background var(--transition-fast);
  }

  .dropdown-item:hover {
    background: var(--color-gray-100);
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
</style>
