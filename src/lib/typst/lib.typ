// MDXport Typst 模板（MVP）
//
// 约定：正文只负责内容（heading/paragraph/list/raw...），样式集中在这里。
// 使用方式（由生成器写入 main.typ）：
//   #import "lib.typ": project
//   #show: project.with(title: "...", authors: (...))

#let project(title: "", authors: (), body) = {
  // 1) 全局页面设置
  set page(paper: "a4", margin: 2cm, numbering: "1 / 1")
  set document(title: title, author: authors)

  // 2) 字体栈（西文字体优先，中文兜底）
  set text(font: ("Libertinus Serif", "Noto Serif CJK SC"), lang: "zh")
  show heading: set text(font: ("Roboto", "Noto Serif CJK SC"), weight: "bold")
  show raw: set text(font: ("DejaVu Sans Mono", "Noto Serif CJK SC"))

  // 3) 段落规范：两端对齐 + 首行缩进
  set par(justify: true, first-line-indent: 2em, leading: 0.9em, spacing: 0.85em)
  set list(spacing: 0.25em)

  // 4) 章节规则：自动编号 + 章节间距
  set heading(numbering: "1.1.1")
  show heading: set block(above: 1.2em, below: 0.5em)
  show heading.where(level: 1): it => [
    #set text(size: 1.6em)
    #it
    #v(0.35em)
  ]
  show heading.where(level: 2): set text(size: 1.3em)
  show heading.where(level: 3): set text(size: 1.15em)

  // 5) 代码块美化（raw block）
  show raw.where(block: true): block.with(
    fill: luma(240),
    inset: 10pt,
    radius: 4pt,
    stroke: luma(200),
    width: 100%,
  )

  // 6) 常用 helper：文件路径（可选）
  let path(p) = raw(p, lang: none)

  // 标题页（可选）
  if title != "" {
    align(center)[
      #v(0.75cm)
      #text(2em, weight: "bold", title)
      #v(0.5em)
      #if authors.len() > 0 [
        #text(0.95em, authors.join(", "))
      ]
    ]
  }

  body
}
