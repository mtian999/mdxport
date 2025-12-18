<script lang="ts">
  import MainEditor from '$lib/components/MainEditor.svelte'
  import type { UILang } from '$lib/i18n/lang'

  let { data }: { data: { lang: UILang } } = $props()

  const SEO = {
    zh: {
      title: 'Notion 导出 PDF 排版修复工具 - MDXport',
      description:
        'Notion 导出的 PDF 表格被截断？图片位置错乱？MDXport 帮你一键修复 Notion 导出 Markdown 后的所有排版问题，生成完美的 PDF。',
      content: `
# 修复 Notion 导出 PDF 排版问题

Notion 是一个很棒的笔记工具，但它的 **PDF 导出功能简直是灾难**。

你是否遇到过：
- ❌ 表格太宽被直接截断
- ❌ 图片大小无法调整
- ❌ 标题层级混乱
- ❌ 分页位置极其尴尬

## 解决方案：导出 Markdown + MDXport

不要直接导出 PDF。请尝试以下流程，获得完美结果：

1. 在 Notion 中点击右上角 \`...\` -> \`Export\`
2. 选择格式为 **Markdown & CSV**
3. 下载并解压 zip 包
4. **将解压出的 \`.md\` 文件拖入 MDXport**

## 我们会自动修复什么？

MDXport 的智能引擎会自动处理 Notion Markdown 的特有怪癖：

- **自动调整表格列宽**，确保不被截断
- **优化图片排版**，支持图注
- **美化引用块 (Callout)**，还原 Notion 风格

## 演示

模拟一个典型的 Notion 页面结构：

> 💡 **Tip**: 这是一个 Callout 块的完美还原。

### 一个宽表格
| 任务 ID | 描述 | 负责人 | 优先级 | 截止日期 | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| TASK-001 | 修复生产环境 Bug | 张三 | P0 | 2023-10-01 | 进行中 |这里的文本很长，MDXport 会自动换行而不是截断... |
`,
    },
    en: {
      title: 'Fix Notion PDF Export Layout Issues (Tables, Images) - MDXport',
      description:
        'Notion PDF export cutting off your tables? Layout broken? Export to Markdown and use MDXport to generate a perfectly formatted PDF instantly.',
      content: `
# Fix Notion PDF Export Layout Issues

Notion is great, but its **PDF export is often a disaster**.

Common issues:
- ❌ Tables cut off at the page edge
- ❌ Uncontrollable image sizes
- ❌ Awkward page breaks

## The Solution: Export Markdown + MDXport

Don't export to PDF directly. Try this workflow instead:

1. In Notion, click \`...\` -> \`Export\`
2. Select **Markdown & CSV** format
3. Unzip the downloaded file
4. **Drag & Drop the \`.md\` file here**

## What do we fix?

MDXport's engine is tuned for Notion's Markdown flavor:

- **Auto-fit Tables**: No more cut-off columns or horizontal scrolling
- **Image Optimization**: Proper scaling and captions
- **Callout Blocks**: Rendered beautifully, just like in Notion

## Demo

Here is a typical Notion-style layout:

> 💡 **Tip**: This is a Callout block, perfectly rendered.

### A Wide Table
| ID | Task Description | Owner | Priority | DDL | Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| T-001 | Fix Prod Bug | Alice | P0 | 2023-10-01 | WIP | This is a very long text that would usually be cut off in standard Notion PDF export... |
`,
    },
  }
</script>

<MainEditor
  lang={data.lang}
  seoTitle={SEO[data.lang].title}
  seoDescription={SEO[data.lang].description}
  initialMarkdown={SEO[data.lang].content}
/>
