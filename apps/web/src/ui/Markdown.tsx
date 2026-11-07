import DOMPurify from 'dompurify';
import { Marked } from 'marked';
import { memo, useMemo } from 'react';

const escape = (s: string) => s.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

const marked = new Marked({
  gfm: true,
  breaks: true,
  renderer: {
    // Thread styles have one heading size, matching the prototype.
    heading({ tokens }) { return `<h3>${this.parser.parseInline(tokens)}</h3>`; },
    code({ text, lang }) {
      return `<div class="code"><div class="code-head"><span>${escape(lang || '代码')}</span><button type="button" data-copy-code>复制</button></div><pre><code>${escape(text)}</code></pre></div>`;
    },
    link({ href, tokens }) { return `<a href="${escape(href)}" target="_blank" rel="noreferrer">${this.parser.parseInline(tokens)}</a>`; },
  },
});

// Model output is untrusted text, so it is sanitized before it reaches the page.
export const Markdown = memo(function Markdown({ text }: { text: string }) {
  const html = useMemo(() => DOMPurify.sanitize(marked.parse(text, { async: false }), { ADD_ATTR: ['target', 'data-copy-code'] }), [text]);
  return (
    <div
      dangerouslySetInnerHTML={{ __html: html }}
      onClick={e => {
        const button = (e.target as HTMLElement).closest('[data-copy-code]');
        const code = button?.closest('.code')?.querySelector('code')?.textContent;
        if (code) void navigator.clipboard?.writeText(code);
      }}
    />
  );
});
