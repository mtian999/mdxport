// 方案二：经典阅读风 (The "Classic Editorial" Style)
// 特点：正文衬线、标题无衬线对比、首行缩进、引用块左侧竖线。

#let article(title: "", authors: (), body) = {
  set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
  set document(title: title, author: authors)

  // 1) 字体：正文使用衬线体，沉浸感更强
  set text(
    font: ("Libertinus Serif", "Noto Serif CJK SC", "SimSun"),
    size: 12pt,
    lang: "zh",
  )

  // 2) 段落：传统书籍排版
  set par(
    justify: true,
    leading: 1em,
    first-line-indent: 2em,
    spacing: 0.65em,
  )

  // 3) 标题：无衬线形成对比
  show heading: set text(font: ("Helvetica", "Libertinus Sans", "Noto Sans CJK SC", "SimHei"))
  show heading.where(level: 1): it => {
    set align(center)
    set text(size: 1.4em)
    block(above: 2em, below: 1em, it)
  }

  // 4) 引用块：左侧竖线
  set quote(block: true)
  show quote: it => {
    set par(first-line-indent: 0pt)
    block(
      stroke: (left: 2pt + gray),
      inset: (left: 0.9em, right: 0.2em, top: 0.15em, bottom: 0.15em),
      width: 100%,
      it.body,
    )
  }

  // 标题区（可选）
  if title != "" {
    align(center)[
      #text(2em, weight: "bold", font: "Noto Serif CJK SC", title)
      #if authors.len() > 0 [
        #v(0.35em)
        #text(0.95em, authors.join(", "))
      ]
      #v(0.5em)
      #line(length: 100%, stroke: 0.5pt + gray)
      #v(2em)
    ]
  }

  body
}
