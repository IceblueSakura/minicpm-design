import { backendState, currentModel, dlText, isRemote, option } from '../core/selectors';
import { Icon } from './Icon';
import { useApp, useStore } from './hooks';
import { useMenu } from './Menu';
import { ModelMenu } from './menus';
import { useShell } from './Shell';
import type { ReactNode } from 'react';

const Text = ({ b, children }: { b: string; children: ReactNode }) => <span className="txt"><b>{b}</b> <span>{children}</span></span>;
const KEPT = '你写的内容会留在这里。';

export function DownloadActions() {
  const store = useStore(), dl = useApp(s => s.dl);
  if (!dl) return null;
  const again = () => store.startDownload(dl.optionId);
  return {
    running: <button className="btn" onClick={() => store.pauseDownload()}>暂停</button>,
    paused: <><button className="btn" onClick={() => store.resumeDownload()}>继续</button><button className="btn" onClick={() => store.cancelDownload()}>取消下载</button></>,
    wifi: <><button className="btn" onClick={() => store.resumeDownload()}>用移动网络继续</button><button className="btn" onClick={() => store.cancelDownload()}>取消下载</button></>,
    failed: <><button className="btn" onClick={() => store.resumeDownload()}>重试</button><button className="btn" onClick={() => store.cancelDownload()}>取消下载</button></>,
    verifying: null,
    badfile: <><button className="btn primary" onClick={again}>重新下载</button><button className="btn" onClick={() => store.cancelDownload()}>取消下载</button></>,
    done: null,
  }[dl.status];
}

export function Banner() {
  const store = useStore(), s = useApp(), { open } = useMenu(), { openSettings } = useShell();
  const st = backendState(s), m = currentModel(s), remote = isRemote(s);

  // A failure names the other place as a button. Only the user changes place.
  const other = remote
    ? s.device.canRunLocal && <button className="btn" onClick={() => store.setBackend('local')}>改用这台设备</button>
    : (s.remote.url || st === 'nogpu') && <button className="btn" onClick={() => { store.setBackend('remote'); if (!s.remote.url) openSettings('models'); }}>改用远程服务</button>;

  let bad = false, body: ReactNode = null;
  if (st === 'unset') {
    bad = true;
    body = <><Icon name="alert" /><Text b="还没配置远程服务">填好服务地址后才能发送。{KEPT}</Text><button className="btn" onClick={() => openSettings('models')}>去设置</button>{other}</>;
  } else if (st === 'nonet') {
    bad = true;
    body = <><Icon name="alert" /><Text b="离线模式开着，连不了远程服务">{KEPT}</Text><button className="btn" onClick={() => store.setPref('offlineMode', false)}>关闭离线模式</button>{other}</>;
  } else if (st === 'nogpu') {
    bad = true;
    body = <><Icon name="alert" /><Text b="这个浏览器跑不了本机模型">换一个浏览器，或者改用远程服务。{KEPT}</Text>{other}</>;
  } else if (st === 'offline') {
    bad = true;
    body = <><Icon name="alert" /><Text b={`连不上${remote ? '远程服务' : '本机模型'}`}>它没有响应。{KEPT}</Text><button className="btn" onClick={() => store.reconnect()}>重试</button>{other || <button className="btn" onClick={() => openSettings('models')}>检查设置</button>}</>;
  } else if (st === 'nomodel') {
    const d = s.dl;
    body = d ? <><Icon name="download" /><Text b={option(s, d.optionId)?.name ?? ''}>{dlText(s)}</Text><DownloadActions /></>
      : <><Icon name="alert" /><Text b={`这个浏览器里还没有 ${m?.name ?? '模型'}`}>下载后才能用，{KEPT}</Text>
        {s.model && <button className="btn" onClick={() => store.startDownload(s.model!)}>下载</button>}
        <button className="btn" aria-haspopup="menu" onClick={e => open({ key: 'model', anchor: e.currentTarget, label: '模型', role: 'menu', render: () => <ModelMenu /> })}>换模型</button></>;
  } else if (s.swapFail) {
    bad = true;
    const name = option(s, s.swapFail.id)?.name, cold = s.swapFail.cold;
    body = <><Icon name="alert" /><Text b={`载不下 ${name}`}>内存不够{cold ? '' : `，已换回 ${m?.name}`}。关掉其他应用后可以重试。{cold ? KEPT : ''}</Text>
      <button className="btn" onClick={() => store.retryLoad()}>重试</button>{!cold && <button className="btn" onClick={() => store.dismissSwapFail()}>知道了</button>}</>;
  } else if (s.loadCrashed) {
    bad = true;
    body = <><Icon name="alert" /><Text b={`上次载入 ${m?.name} 时应用退出了`}>可能是内存不够，这次没有自动载入。{KEPT}</Text>
      <button className="btn" onClick={() => store.retryLoad()}>再试一次</button><button className="btn" onClick={() => openSettings('models')}>换模型</button></>;
  } else if (s.loading && s.swapFrom) {
    const o = option(s, s.loading);
    body = <><Icon name="clock" /><Text b={`正在换到 ${o?.name}`}>约 {o?.loadSeconds} 秒。可以先写，发送后会自动接上。</Text><button className="btn" onClick={() => store.cancelLoad()}>取消</button></>;
  } else if (s.loading) {
    const o = option(s, s.loading);
    body = <><Icon name="clock" /><Text b={`正在准备 ${o?.name}`}>约 {o?.loadSeconds} 秒。可以先写，发送后会自动接上。</Text></>;
  }
  if (!body) return null;
  return <div className={`banner${bad ? ' bad' : ''}`}>{body}</div>;
}
