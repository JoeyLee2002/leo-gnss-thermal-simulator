import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';

const runtime = 'C:/Users/30698/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const require = createRequire(`${runtime}/manual_renderer.cjs`);
const {chromium} = require('playwright');
const {marked} = await import(pathToFileURL(require.resolve('marked')).href);
const root = path.resolve(process.argv[2] || 'docs');
const release = process.argv.includes('--release');
const names = release ? ['USAGE_CN', 'USAGE_EN', 'PAPER_REPRODUCTION_CN', 'PAPER_REPRODUCTION_EN'] :
  ['usage_v1.5_zh', 'quickstart_v1.5', 'reproduce_paper_v1.5_zh', 'reproduce_paper_v1.5'];
const labels = ['中文用户手册', 'English User Manual', '中文论文复现', 'English Paper Reproduction'];
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const css = `
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;color:#172831;background:#f3f6f7;font:16px/1.7 Arial,"Microsoft YaHei",sans-serif}
nav,main{max-width:1120px;margin:auto;padding:24px 36px}nav{display:flex;gap:24px;flex-wrap:wrap;background:white;border-bottom:1px solid #cbd6da}
main{background:white}h1{font-size:30px;color:#111;line-height:1.3;margin:16px 0 28px}h2{font-size:24px;color:#111;margin:42px 0 16px}h3{font-size:20px;color:#111;margin:30px 0 12px}
p,li{overflow-wrap:anywhere}li{margin:8px 0}a{color:#005e85}figure{margin:24px 0 30px;border:1px solid #d4dfe3;padding:12px;break-inside:avoid}
figure img{display:block;max-width:100%;max-height:1000px;height:auto;margin:auto}figcaption{font-size:14px;color:#465963;margin-top:12px;text-align:center}
table{border-collapse:collapse;width:100%;font-size:14px;margin:22px 0}th,td{border-bottom:1px solid #cbd6da;padding:10px 12px;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#eef3f5;color:#182a33}
code{font:0.91em Consolas,"Microsoft YaHei",monospace;background:#eef3f5;padding:2px 4px;overflow-wrap:anywhere}pre{background:#eef3f5;border:1px solid #d4dfe3;padding:16px;white-space:pre-wrap;overflow-wrap:anywhere;break-inside:avoid}pre code{padding:0;background:none}
hr{border:0;border-top:1px solid #cbd6da;margin:30px 0}.toc{padding:16px 24px;background:#f2f6f8}.toc ul{columns:2;padding-left:20px}.toc li{margin:4px 0;font-size:14px}
@media(max-width:700px){main,nav{padding:18px}h1{font-size:26px}.toc ul{columns:1}table{font-size:12px}td,th{padding:6px}}
@page{size:A4;margin:16mm 14mm 18mm}
@media print{body{background:white;font-size:10.5pt;line-height:1.5}main{padding:0;max-width:none}nav,hr{display:none}h1{font-size:24pt}h2{font-size:18pt;margin-top:24pt;break-after:avoid}h3{font-size:13pt;break-after:avoid}p,li{orphans:3;widows:3}figure{padding:5mm;margin:5mm 0;border:1px solid #d4dfe3}figure img{max-height:170mm;max-width:100%;object-fit:contain}figcaption{font-size:9pt}table{font-size:8.8pt}thead{display:table-header-group}tr{break-inside:avoid}pre{font-size:8.5pt}.toc{background:white}.toc li{font-size:9pt}a{text-decoration:none}}
`;

const browser = await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless:true});
const page = await browser.newPage({viewport:{width:1250,height:1000}});
const report = [];
try {
  for (let i=0;i<names.length;i++) {
    const name = names[i];
    let md = await fs.readFile(path.join(root,name+'.md'),'utf8');
    // Only change link destinations; retain downloadable Markdown names in prose.
    md = md.replace(/(\]\()([^)]*?)\.md(\))/g, (whole, start, target, end) =>
      names.includes(target) ? `${start}${target}.html${end}` : whole);
    let html = marked.parse(md, {gfm:true});
    let count = 0;
    const headings = [];
    html = html.replace(/<h2>(.*?)<\/h2>/g, (_,txt)=>{
      const id='section-'+(++count); headings.push([id,txt]); return `<h2 id="${id}">${txt}</h2>`;
    });
    html = html.replace(/<p><img src="([^"]+)" alt="([^"]*)"[^>]*><\/p>/g,
      (_,src,alt)=>`<figure><a href="${src}" target="_blank"><img src="${src}" alt="${alt}"></a><figcaption>${alt}</figcaption></figure>`);
    const title=(md.match(/^# (.*)$/m)||[])[1] || name;
    const toc=`<div class="toc"><strong>${i%2===0?'目录':'Contents'}</strong><ul>${headings.map(([id,txt])=>`<li><a href="#${id}">${txt}</a></li>`).join('')}</ul></div>`;
    html=html.replace(/(<\/h1>)/, '$1'+toc);
    const document=`<!doctype html><html lang="${i%2===0?'zh-CN':'en'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(title)}</title><style>${css}</style></head><body><nav>${names.map((n,j)=>`<a href="${n}.html">${labels[j]}</a>`).join('')}</nav><main>${html}</main></body></html>`;
    const htmlFile=path.join(root,name+'.html');
    await fs.writeFile(htmlFile,document,'utf8');
    await page.goto(pathToFileURL(htmlFile).href,{waitUntil:'load'});
    await page.evaluate(()=>document.fonts.ready);
    const images=await page.locator('img').evaluateAll(imgs=>imgs.map(img=>({src:img.getAttribute('src'),valid:img.complete&&img.naturalWidth>0})));
    if(images.length===0 || images.some(img=>!img.valid))throw new Error(JSON.stringify(images));
    await page.pdf({path:path.join(root,name+'.pdf'),format:'A4',printBackground:true,displayHeaderFooter:true,
      headerTemplate:'<div></div>',footerTemplate:'<div style="width:100%;text-align:center;font:9px Arial;color:#576971"><span class="pageNumber"></span> / <span class="totalPages"></span></div>'});
    await page.screenshot({path:path.join(root,name+'_preview.png'),fullPage:false});
    report.push({name,images:images.length,validImages:images.filter(img=>img.valid).length,pdf:true});
  }
} finally {await browser.close();}
await fs.writeFile(path.join(root,'manual_render_audit.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
