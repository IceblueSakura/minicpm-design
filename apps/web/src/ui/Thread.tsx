import { memo, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { activeScenes, current, isBlank, privacyLine } from '../core/selectors';
import type { AiItem, Attachment, Conversation, ThreadItem } from '../core/types';
import { SCENES } from '../core/scenes';
import { Icon, Mark } from './Icon';
import { useApp, useStore } from './hooks';
import { useLongPress } from './longPress';
import { Markdown } from './Markdown';
import { useMenu } from './Menu';
import { MessageSheet } from './menus';
import { useShell } from './Shell';

export const AttachmentChip = ({ a, children, bad }: { a: Attachment; children?: React.ReactNode; bad?: boolean }) => (
  <span className={`att${bad ? ' bad' : ''}`}>
    <span className="thumb" style={a.url ? { backgroundImage: `url(${a.url})` } : undefined}>{!a.url && <Icon name={a.kind === 'image' ? 'image' : 'file'} />}</span>
    <span className="nm">{a.name}</span>{children}
  </span>
);

const copy = (text: string) => void navigator.clipboard?.writeText(text);
function speak(text: string) {
  speechSynthesis.cancel();
  speechSynthesis.speak(new SpeechSynthesisUtterance(text));
}

const UserMessage = memo(function UserMessage({ item }: { item: Extract<ThreadItem, { type: 'user' }> }) {
  const store = useStore(), { open } = useMenu(), { compact } = useShell();
  const press = useLongPress(compact, () => open({ key: `msg-${item.id}`, anchor: null, label: '消息操作', role: 'menu', render: () => <MessageSheet copy={() => copy(item.text)} /> }));
  return (
    <div className="msg-user" {...press}>
      {!!item.atts.length && <div className="attach-row">{item.atts.map(a => <AttachmentChip key={a.id} a={a} />)}</div>}
      {item.text && <div className="bubble">{item.text}</div>}
      {item.failed && <div className="msg-fail"><Icon name="alert" />没有发出去<button onClick={() => store.retrySend(item.id)}>重试</button></div>}
    </div>
  );
});

const AiMessage = memo(function AiMessage({ item, live, tech }: { item: AiItem; live: boolean; tech: boolean }) {
  const store = useStore(), { open } = useMenu(), { compact } = useShell();
  const press = useLongPress(compact && !live, () => open({
    key: `msg-${item.id}`, anchor: null, label: '消息操作', role: 'menu',
    render: () => <MessageSheet copy={() => copy(item.text)} regen={() => store.regenerate(item.id)} speak={() => speak(item.text)} />,
  }));
  const cut = { length: '回答太长，到这里停了', crash: '模型中断了，回答到这里' }[item.cut ?? 'none' as never];
  return (
    <article className="msg-ai" {...press}>
      <div className={`content${live ? ' caret' : ''}`}><Markdown text={item.text} /></div>
      {cut && <div className="cut">{cut}<button className="btn" onClick={() => store.continueReply(item.id)}>接着写</button></div>}
      {!live && (
        <div className="msg-tools">
          <button className="icon-btn" aria-label="复制" title="复制" onClick={() => copy(item.text)}><Icon name="copy" /></button>
          <button className="icon-btn" aria-label="重新生成" title="重新生成" onClick={() => store.regenerate(item.id)}><Icon name="retry" /></button>
          <button className="icon-btn" aria-label="朗读" title="朗读" onClick={() => speak(item.text)}><Icon name="speaker" /></button>
          {item.stat && tech && <span className="msg-stat mono">{item.stat}</span>}
        </div>
      )}
    </article>
  );
});

function Ask({ item }: { item: Extract<ThreadItem, { type: 'ask' }> }) {
  const store = useStore(), offline = useApp(s => s.prefs.offlineMode);
  if (item.state === 'denied') return <div className="net-note"><Icon name="offline" />没有联网</div>;
  return (
    <div className="ask">
      <div className="ask-head"><Icon name="globe" />要联网查一下吗？</div>
      <p>{offline ? '离线模式开着，现在不能联网。' : '只发送下面这句话，对话内容和文件都不发。'}</p>
      <span className="ask-q">{item.query}</span>
      <div className="acts">
        {offline ? <button className="btn primary" onClick={() => store.setPref('offlineMode', false)}>关闭离线模式</button>
          : <button className="btn primary" onClick={() => store.allowSearch(item.id)}>查一下</button>}
        <button className="btn" onClick={() => store.denySearch(item.id)}>不用</button>
      </div>
    </div>
  );
}

function Action({ item }: { item: Extract<ThreadItem, { type: 'action' }> }) {
  const store = useStore(), notify = item.kind === 'notify', icon = notify ? 'clock' : 'file';
  const line = `${item.when ? `${item.when} · ` : ''}${item.text}`;
  if (item.state === 'added') return <div className="net-note"><Icon name={icon} />{notify ? '已存成日历提醒' : '已复制'}：{line}</div>;
  if (item.state === 'declined') return <div className="net-note"><Icon name={icon} />{notify ? '没有添加定时通知' : '没有写到备忘录'}</div>;
  return (
    <div className="ask">
      <div className="ask-head"><Icon name={icon} />{notify ? '加一个定时通知？' : '写到备忘录？'}</div>
      <p>{notify ? '这个页面关掉后发不了通知，可以存成日历提醒。' : '浏览器写不了系统备忘录，可以复制这段文字。'}</p>
      <span className="ask-q">{line}</span>
      <div className="acts">
        <button className="btn primary" onClick={() => store.answerAction(item.id, true)}>{notify ? '存成日历提醒' : '复制'}</button>
        <button className="btn" onClick={() => store.answerAction(item.id, false)}>不用</button>
      </div>
    </div>
  );
}

/** Reads the memories list, so a deletion in settings reaches this line too, and the words go with it. */
function MemoryLine({ text }: { text: string }) {
  const store = useStore(), kept = useApp(s => s.memories.includes(text)), on = useApp(s => s.prefs.memory), { openSettings } = useShell();
  return (
    <div className="net-note mem-line"><Icon name="bulb" />
      {kept ? <>已记住：{text}<button className="link" onClick={() => store.undoMemory(text)}>撤销</button><button className="link" onClick={() => openSettings('memories')}>管理</button></>
        : <>已忘掉这条{on && <button className="link" onClick={() => store.redoMemory(text)}>重新记住</button>}</>}
    </div>
  );
}

function Item({ item, live, tech }: { item: ThreadItem; live: boolean; tech: boolean }) {
  switch (item.type) {
    case 'user': return <UserMessage item={item} />;
    case 'ai': return <AiMessage item={item} live={live} tech={tech} />;
    case 'ask': return <Ask item={item} />;
    case 'action': return <Action item={item} />;
    case 'memory': return <MemoryLine text={item.text} />;
    case 'place': return <div className="turn-gap place">{item.text}</div>;
  }
}

function Hero({ c }: { c: Conversation }) {
  const store = useStore(), s = useApp();
  return (
    <div className="hero">
      <Mark />
      <h1>{c.temp ? '这段对话不会留下' : '想一起做点什么？'}</h1>
      <p>{c.temp ? '离开后不保存记录，也不写入记忆。' : '打字，或者把图片和文档给它看。'}</p>
      <p className="privacy"><Icon name="shield" />{privacyLine(s)}</p>
      <div className="scene-row" role="radiogroup" aria-label="应用场景">
        {activeScenes(s, c).map(id => (
          <button key={id} className="scene-opt" role="radio" aria-checked={id === c.scene} title={SCENES[id].hint} onClick={() => store.setScene(id)}>{SCENES[id].name}</button>
        ))}
      </div>
    </div>
  );
}

export function Thread({ onScrolled }: { onScrolled: (scrolled: boolean) => void }) {
  const s = useApp(), c = current(s), blank = isBlank(c);
  const ref = useRef<HTMLDivElement>(null);
  const stick = useRef(true);
  const [away, setAway] = useState(false);
  const toEnd = () => { const el = ref.current; if (el) el.scrollTop = el.scrollHeight; };

  useEffect(() => { stick.current = true; }, [c.id]);
  useLayoutEffect(() => { if (stick.current) toEnd(); });

  return <>
    <section className="conv">
      <div
        ref={ref} className="scroll"
        onScroll={e => {
          const el = e.currentTarget, near = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
          stick.current = near;
          setAway(!near);
          onScrolled(el.scrollTop > 4);
        }}
      >
        <div className="thread" role="log" aria-label="对话记录" style={blank ? { paddingBottom: 0 } : undefined}>
          {blank ? <Hero c={c} /> : c.items.map(item => <Item key={item.id} item={item} live={s.reply?.itemId === item.id} tech={s.prefs.tech} />)}
        </div>
      </div>
      {away && !blank && <button className="to-latest" onClick={toEnd}><Icon name="down" />回到最新</button>}
    </section>
  </>;
}
