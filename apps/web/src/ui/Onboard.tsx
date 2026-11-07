import { dlText, option, specText } from '../core/selectors';
import type { ModelOption } from '../engine/types';
import { DownloadActions } from './Banner';
import { Icon, Mark } from './Icon';
import { useApp, useStore } from './hooks';
import { useShell } from './Shell';

export const DownloadBar = () => {
  const s = useApp(), d = s.dl;
  if (!d) return null;
  return (
    <div className="dl" data-status={d.status}>
      <div className="dl-bar"><i style={{ width: `${d.pct}%` }} /></div>
      <small>{dlText(s)}</small>
      <div className="acts"><DownloadActions /></div>
    </div>
  );
};

function Welcome() {
  const store = useStore();
  return <>
    <Mark />
    <h1>在你自己的设备上运行</h1>
    <p>MiniCPM 能看图、读文档，全部在这台设备上完成。</p>
    <ul className="ob-list">
      <li><Icon name="shield" /><span><b>内容不离开这台设备</b><small>图片和文件都在本机处理。只有你同意时，搜索词才会离开。</small></span></li>
      <li><Icon name="offline" /><span><b>断网也能用</b><small>模型下载好之后就不需要网络了。</small></span></li>
      <li><Icon name="file" /><span><b>都由你决定</b><small>记住了什么、联网做了什么，都能看到和删除。</small></span></li>
    </ul>
    <div className="ob-foot"><button className="btn primary ob-cta" onClick={() => store.obNext()}>继续</button></div>
  </>;
}

function Pick() {
  const store = useStore(), s = useApp(), { openSettings } = useShell();
  const remote = () => { store.obRemote(); openSettings('models'); };
  if (!s.device.canRunLocal) return <>
    <h1>这个浏览器跑不了本机模型</h1>
    <p>换一个浏览器就能在这台设备上运行。也可以连接你自己的服务器，内容会发送到那台服务器。</p>
    <div className="ob-foot"><button className="btn primary ob-cta" onClick={remote}>连接远程服务</button></div>
  </>;
  const picked: ModelOption | undefined = option(s, s.obPick) ?? s.catalog.find(o => o.recommended);
  const free = s.device.freeStorageGB, short = picked && free !== null ? picked.sizeGB + .5 - free : 0;
  const smaller = s.catalog.filter(o => free !== null && o.sizeGB + .5 <= free).toSorted((a, b) => a.sizeGB - b.sizeGB)[0];
  return <>
    <h1>选一个模型</h1>
    <p>这是这个浏览器能用的模型。下载后不再需要网络，清除网站数据时会一起删除。</p>
    {free !== null && <p className="ob-device">这个浏览器：可用空间约 {free < 10 ? free.toFixed(1) : Math.round(free)} GB</p>}
    <div className="ob-models" role="radiogroup" aria-label="模型">
      {s.catalog.map(o => (
        <button key={o.id} className="voice" role="radio" aria-checked={picked?.id === o.id} onClick={() => store.obPick(o.id)}>
          <Icon name="image" />
          <span>
            <b>{o.name}{o.recommended && <span className="pill ok">推荐</span>}</b>
            <small>看图、读文档，用文字回答</small>
            <small>{specText(o)} · {o.sizeGB.toFixed(1)} GB</small>
          </span>
        </button>
      ))}
    </div>
    {short > 0 && (
      <div className="note"><Icon name="alert" /><div className="grow">
        <strong>还差 {short.toFixed(1)} GB 空间</strong>
        <p>清理后回到这里继续{smaller ? '，或者改下载小一些的模型。' : '。'}</p>
        {smaller && <div className="acts"><button className="btn" onClick={() => store.obPick(smaller.id)}>改下载 {smaller.name}，{smaller.sizeGB.toFixed(1)} GB</button></div>}
      </div></div>
    )}
    <div className="ob-foot">
      <button className="btn primary ob-cta" disabled={short > 0 || !picked} onClick={() => store.obDownload()}>下载 {picked?.sizeGB.toFixed(1)} GB</button>
      <button className="link ob-alt" onClick={remote}>我有自己的服务器</button>
    </div>
  </>;
}

function Downloading() {
  const store = useStore(), s = useApp(), o = option(s, s.dl?.optionId ?? null);
  if (!s.dl || !o) return null;
  return <>
    <h1>{s.dl.status === 'verifying' ? '马上就好' : `正在下载 ${o.name}`}</h1>
    <p>{specText(o)} · {o.sizeGB.toFixed(1)} GB。下载在后台继续，可以先离开这个页面。</p>
    <DownloadBar />
    <div className="ob-foot"><button className="btn primary ob-cta" onClick={() => store.obLeave()}>先进去看看</button></div>
  </>;
}

export function Onboard() {
  const step = useApp(s => s.onboard);
  if (!step) return null;
  return (
    <section className="gate" aria-label="开始使用">
      <div className="gate-in">{step === 'welcome' ? <Welcome /> : step === 'model' ? <Pick /> : <Downloading />}</div>
    </section>
  );
}
