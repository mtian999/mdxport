---
status: draft
owner: formula
version: 0.1
last_reviewed: 2025-12-17
product_name: MDXport
scope: engineering
stack: sveltekit_static_prerender
tags: [sveltekit, adapter-static, prerender, typst, wasm, worker, client-only, offline]
---

# MDXport 工程实现规范（SvelteKit 全站静态 prerender）

## 0. 结论与边界

本工程选择 **SvelteKit + adapter-static**，以“**全站静态 prerender**”方式产出一组可直接部署到任意静态托管（S3/Cloudflare Pages/GitHub Pages/OSS）的文件。adapter-static 默认会检查“要么全站都 prerender，要么你显式设置 fallback”，用于避免你意外发布半残站点。:contentReference[oaicite:0]{index=0}

### 强约束（必须接受）
- **没有任何服务端能力**：不允许 `+server.ts`、不允许 form actions（actions 需要服务器）。:contentReference[oaicite:1]{index=1}
- prerender 阶段会在构建时执行路由的 load/渲染逻辑；任何“构建期会重定向/鉴权/请求私有 API”的逻辑都会让 build 失败（这是好事，越早炸越好）。:contentReference[oaicite:2]{index=2}
- 与 Typst/WASM 相关的初始化必须是“浏览器运行时”才发生，不能在 SSR/prerender 时触发。

---

## 1. 目标

- 全站静态可部署（零后端）。
- 核心导出链路：Markdown → AST → IR → Typst source+VFS → Typst(WASM in Worker) → PDF/PNG。
- 资产与字体本地化：默认不联网，二次打开/导出秒开（CacheStorage + IndexedDB）。
- 工程层面“可回归”：Golden 文档集 + E2E 自动导出校验。

---

## 2. 技术栈选型

### 2.1 App 框架
- SvelteKit（SSR 开启，用于生成“真实 prerender HTML”，不要走 SPA 空壳模式）
- adapter-static（strict 默认开）

### 2.2 核心运行时
- Web Worker：Typst 编译专用 worker（避免主线程卡死）
- WASM：Typst 编译器 wasm（worker 内加载）
- VFS：把 main.typ/template.typ/fonts/assets 映射为“虚拟文件系统”输入给编译器

### 2.3 存储
- CacheStorage：缓存 wasm、字体包、模板包（大文件、命中率高）
- IndexedDB（Dexie 可选）：缓存文档、图片资源、导出历史、用户配置

---

## 3. 工程目录建议（单 repo）

```

mdxport/
src/
routes/
+layout.ts
+layout.svelte
+page.svelte                # / （编辑器主页）
templates/+page.svelte      # /templates
settings/+page.svelte       # /settings
lib/
editor/
pipeline/
parse_md.ts
normalize.ts
preflight/
ir/
typst_gen/
exporters/
runtime/
cache.ts
idb.ts
assets.ts
fonts.ts
workers/
typst.worker.ts
typst_client.ts
static/
icons/
fonts/                        # 可选：小字体/演示字体。大字体走 lazy-load + cache
svelte.config.js
vite.config.ts
package.json
docs/
DESIGN.md
ENGINEERING_SVELTEKIT_STATIC.md

````

---

## 4. SvelteKit 全站 prerender 配置

### 4.1 `svelte.config.js`
```js
import adapter from '@sveltejs/adapter-static';

const config = {
  kit: {
    adapter: adapter({
      // 全站都 prerender 时：不要配置 fallback
      // 如果未来你要做 SPA fallback（不推荐本模式），再加 fallback: '200.html'
    }),
    prerender: {
      // 让构建期尽早失败：任何不可 prerender 的路径/错误都要暴露出来
      handleHttpError: 'fail'
    }
  }
};

export default config;
````

`kit.prerender.handleHttpError` 是官方配置项。([Svelte][1])

### 4.2 `src/routes/+layout.ts`

```ts
export const prerender = true;
```

> 不要在全站 prerender 模式下设置 `export const ssr = false`。你会得到“空壳 HTML”，对 SEO/首屏没有意义，还更容易埋下运行时差异问题。SvelteKit 官方也明确：能 prerender 就不必 SPA mode。([Svelte][2])

---

## 5. Worker 与 Vite 打包规则（硬性）

### 5.1 Worker 创建（主线程）

使用 Vite 推荐写法：

```ts
const worker = new Worker(
  new URL('$lib/workers/typst.worker.ts', import.meta.url),
  { type: 'module' }
);
```

这是 Vite 官方推荐的 worker 引用方式，并支持 module worker。([vitejs][3])

### 5.2 禁止在 prerender/SSR 阶段触发 Worker/WASM

* 不要在模块顶层 `new Worker(...)`、不要顶层初始化 Typst。
* 在组件里用 `onMount` 后再创建 worker。
* 任何访问 `window/document/cacheStorage/indexedDB` 都只能在浏览器分支执行。

---

## 6. 运行时链路（从输入到导出）

### 6.1 Pipeline（单向、可复现）

1. Markdown → AST（parser）
2. AST → 标准 AST（profile/normalize）
3. Preflight：输出 diagnostics + patches（可一键修复）
4. 标准 AST → Document IR（versioned）
5. IR → Typst 生成：`main.typ` + `template.typ` + `meta.json` + assets
6. 调用 Worker 编译：输入（VFS + entry），输出（pdf bytes + typst diagnostics）
7. PDF.js 预览 + 下载

### 6.2 VFS 规范（Worker 输入）

* `/main.typ`
* `/template/template.typ`
* `/assets/img_*.{png,jpg,webp}`
* `/fonts/*.ttf|*.otf`
* `/meta.json`

---

## 7. 字体与缓存策略（必须工程化）

### 7.1 MVP（先活下来）

* 内置：1 套简中字体 Regular + 1 套等宽字体
* lazy-load：首次导出时下载字体包（显示进度）
* CacheStorage：缓存字体与 wasm，二次导出不再下载

### 7.2 进阶（否则移动端迟早炸）

* Basic/Full 分档
* 子集化（按文档用字裁剪）——如果不做，你迟早会被“内存峰值 + 包体”击穿

---

## 8. 安全策略（默认不联网）

* 默认禁止远程 URL（图片/字体）；用户显式开关才允许。
* Markdown 中的内嵌 HTML：sanitize 后降级（别试图“兼容一切”，这类需求会拖死你）。
* 资源限额：单图上限、总资源上限、最大页数/字符数（防浏览器崩溃）。

---

## 9. 测试与回归（上线前必须做）

### 9.1 Golden 文档集

覆盖：表格、长文、代码、多图片、中英混排、极端宽表格、极长 URL、emoji、零宽字符等。

### 9.2 自动化校验（CI）

* Playwright：打开页面 → 导入样例 → 导出 PDF → 校验文件大小/页数/目录存在
* PDF 文本抽取一致性（确保中文可复制、无豆腐块）
* 性能预算：导出耗时、内存峰值（至少做“阈值告警”）

---

## 10. 部署规范

* 产物目录：adapter-static 输出的静态目录（按 SvelteKit 默认）
* 托管平台：Cloudflare Pages / GitHub Pages / S3+CDN 均可
* 若部署在子路径：配置 `kit.paths.base`（否则资源路径会错）

---

## 11. 约束清单（给所有贡献者看的“红线”）

* ❌ 不允许新增 `+server.ts`
* ❌ 不允许 form actions
* ❌ 不允许在模块顶层访问浏览器 API（window/document/indexedDB/cache）
* ✅ Worker/WASM 初始化必须 `onMount` 后进行
* ✅ 所有 exporter 只吃 Document IR，不允许重复解析 Markdown

```

如果你愿意，我可以顺手把这个文档拆成两份“更能开工的”工程规格：  
1) `Markdown Profile v0.1`（允许/禁止/降级 + 样例）  
2) `IR → Typst 映射规范 v0.1`（逐节点渲染规则 + escape 策略 + 测试用例）
::contentReference[oaicite:6]{index=6}
```

[1]: https://svelte.dev/docs/kit/configuration?utm_source=chatgpt.com "Configuration • SvelteKit Docs"
[2]: https://svelte.dev/docs/kit/single-page-apps?utm_source=chatgpt.com "Single-page apps • SvelteKit Docs"
[3]: https://vite.dev/guide/features?utm_source=chatgpt.com "Features"
