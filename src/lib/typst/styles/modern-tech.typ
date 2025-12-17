// 方案一：现代科技风 (The "Modern Tech" Style)
// 特点：全无衬线（更像网页阅读）、段间距、无首行缩进、代码块现代风格。

#let article(title: "", authors: (), body) = {
  // 1) 页面设置：宽边距，利于阅读
  set page(
    paper: "a4",
    margin: (x: 1.8cm, y: 2cm),
    numbering: "1",
  )
  set document(title: title, author: authors)

  // 2) 字体栈：英文优先，中文兜底（无衬线）
  set text(
    font: ("Inter", "Roboto", "Noto Sans CJK SC", "Microsoft YaHei"),
    size: 11pt,
    lang: "zh",
  )

  // 3) 段落：放弃首行缩进，采用“段间距”模式
  set par(
    justify: true,
    leading: 0.8em,
    first-line-indent: 0pt,
    spacing: 1.2em,
  )

  // 4) 标题：加粗、深灰、带间距
  show heading: it => {
    set text(weight: "bold", fill: rgb("#333333"))
    block(below: 0.8em, above: 1.5em, it)
  }

  // 5) 链接颜色：科技蓝
  show link: set text(fill: rgb("#0074de"))

  // 6) 引用块：左侧高亮线 + 浅背景
  set quote(block: true)
  show quote: it => {
    set par(first-line-indent: 0pt)
    block(
      fill: luma(248),
      stroke: (left: 2pt + rgb("#0074de")),
      inset: (left: 0.9em, right: 0.9em, top: 0.7em, bottom: 0.7em),
      radius: 6pt,
      width: 100%,
      it.body,
    )
  }

  // 6) 代码块：圆角 + 浅灰背景
  show raw.where(block: true): block.with(
    fill: luma(245),
    inset: 12pt,
    radius: 6pt,
    width: 100%,
    stroke: none,
  )
  show raw: set text(font: ("JetBrains Mono", "Fira Code", "Consolas", "DejaVu Sans Mono"))

  // 标题区（可选）
  if title != "" {
    align(center)[
      #text(1.8em, weight: "black", title)
      #if authors.len() > 0 [
        #v(0.35em)
        #text(0.95em, fill: rgb("#555555"), authors.join(", "))
      ]
    ]
    v(1em)
  }

  body
}
