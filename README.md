# mdxport

一个基于 Svelte 和 Typst 的 Markdown 导出工具，支持导出为高质量 PDF。

## 特性

- **Typst 驱动**: 利用 Typst 强大的排版能力生成 PDF。
- **即时预览**: 编辑 Markdown 实时预览 PDF 效果。
- **Mermaid 支持**: 集成 Mermaid 图表渲染。
- **MathJax/Katex 支持**: 完美的数学公式支持。
- **浏览器及离线运行**: 所有的转换都在浏览器中完成，无需后端。

## Creating a project

If you're seeing this, you've probably already done this step. Congrats!

```sh
# create a new project in the current directory
npx sv create

# create a new project in my-app
npx sv create my-app
```

## Developing

Once you've created a project and installed dependencies with `npm install` (or `pnpm install` or `yarn`), start a development server:

```sh
npm run dev

# or start the server and open the app in a new browser tab
npm run dev -- --open
```

## Building

To create a production version of your app:

```sh
npm run build
```

You can preview the production build with `npm run preview`.

## License

MIT [LICENSE](LICENSE)
