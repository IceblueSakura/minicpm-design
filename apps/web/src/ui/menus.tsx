// The content of every menu and sheet. Each reads state through hooks, so it stays live while open.
import { useState } from 'react';
import { activeScenes, backendState, capsText, current, currentModel, engineStatus, isBlank, isRemote, kindText, modelChoices, option, remoteHost, sendingOut, specText } from '../core/selectors';
import { SCENES } from '../core/scenes';
import { Icon } from './Icon';
import { useApp, useStore } from './hooks';
import { MenuItem, useMenu } from './Menu';
import { useShell } from './Shell';

export function ModelItems() {
  const store = useStore(), s = useApp(), { close } = useMenu(), { openSettings } = useShell();
  const [ask, setAsk] = useState<string | null>(null);
  const remote = isRemote(s);
  return <>
    <div className="ttl">{remote ? '模型 · 所有对话共用' : '模型 · 一次只运行一个，所有对话共用'}</div>
    {modelChoices(s).map(o => {
      const missing = !remote && !s.installed.includes(o.id);
      const sub = missing ? '未下载，去设置里下载' : [kindText(o), ...(remote ? [] : [specText(o)])].join(' · ');
      return <div key={o.id}>
        <MenuItem
          title={o.name} sub={sub} tick={o.id === s.model} role="menuitemradio"
          onClick={() => {
            if (missing) { close(); openSettings('models'); return; }
            if (o.id === s.model) { close(); return; }
            if (s.reply) { close(); store.setModel(o.id); return; }
            setAsk(o.id);
          }}
        />
        {ask === o.id && (
          <div className="swap-ask" role="group" aria-label="确认换模型">
            <p>所有对话都会改用 {o.name}{remote ? '' : `，要等约 ${o.loadSeconds} 秒`}。</p>
            <div className="acts">
              <button className="btn" onClick={() => { close(); store.setModel(o.id); }}>换用</button>
              <button className="btn" onClick={() => setAsk(null)}>先不换</button>
            </div>
          </div>
        )}
      </div>;
    })}
  </>;
}

export function PlaceItems() {
  const store = useStore(), s = useApp(), { close } = useMenu(), { openSettings } = useShell();
  return <>
    <div className="ttl">运行位置</div>
    <MenuItem
      title="这台设备" role="menuitemradio" tick={!isRemote(s)}
      sub={s.device.canRunLocal ? '在这个浏览器里运行，内容不离开本机' : '这个浏览器跑不了'}
      onClick={() => { close(); store.setBackend('local'); }}
    />
    <MenuItem
      title="远程服务" role="menuitemradio" tick={isRemote(s)}
      sub={s.remote.url ? `内容会发送到 ${remoteHost(s)}` : '还没设置，去填写地址'}
      onClick={() => { close(); store.setBackend('remote'); if (!s.remote.url) openSettings('models'); }}
    />
  </>;
}

export const ModelMenu = () => <><ModelItems /><div className="sep" /><PlaceItems /></>;

export function SceneMenu() {
  const store = useStore(), s = useApp(), { close } = useMenu(), c = current(s);
  return <>{activeScenes(s, c).map(id => (
    <MenuItem key={id} title={SCENES[id].name} sub={SCENES[id].hint} tick={id === c.scene} role="menuitemradio" onClick={() => { store.setScene(id); close(); }} />
  ))}</>;
}

export function ConversationMenu({ id }: { id: string }) {
  const store = useStore(), { close } = useMenu(), { setRenaming } = useShell();
  return <>
    <MenuItem title="重命名" onClick={() => { close(); store.select(id); setRenaming(id); }} />
    <MenuItem title="导出" onClick={() => { close(); store.notYet(); }} />
    <MenuItem title="删除" danger onClick={() => { close(); store.deleteConversation(id); }} />
  </>;
}

/** Compact form: everything the desktop header and composer show at once lives here. */
export function TitleSheet() {
  const store = useStore(), s = useApp(), { close } = useMenu(), { toggleInspector, setRenaming } = useShell();
  const c = current(s), named = !isBlank(c);
  return <>
    <ModelItems />
    <PlaceItems />
    <div className="ttl">场景</div>
    <div className="scene-row" role="radiogroup" aria-label="应用场景">
      {activeScenes(s, c).map(id => (
        <button key={id} className="scene-opt" role="radio" aria-checked={id === c.scene} onClick={() => store.setScene(id)}>{SCENES[id].name}</button>
      ))}
    </div>
    <div className="sep" />
    {named && !c.temp && <MenuItem title="重命名" onClick={() => { close(); setRenaming(c.id); }} />}
    <MenuItem title="对话详情" sub="处理位置、材料和产物" onClick={() => { close(); toggleInspector(); }} />
    {named && <MenuItem title="导出这段对话" onClick={() => { close(); store.notYet(); }} />}
    {named && <MenuItem title="删除对话" danger onClick={() => { close(); store.deleteConversation(c.id); }} />}
  </>;
}

export function AttachSheet() {
  const store = useStore(), thinking = useApp(s => s.thinking), { close } = useMenu(), { pickFile, takePhoto } = useShell();
  const tile = (name: string, icon: string, run: () => void) => (
    <button type="button" className="mi tile" role="menuitem" onClick={() => { close(); run(); }}><Icon name={icon} /><b>{name}</b></button>
  );
  return <>
    <div className="tiles">{tile('相机', 'camera', takePhoto)}{tile('相册', 'image', pickFile)}{tile('文件', 'file', pickFile)}</div>
    <div className="sep" />
    <MenuItem title="深度思考" sub="先思考再回答，适合复杂问题" icon={<Icon name="bulb" />} tick={thinking} role="menuitemcheckbox" onClick={() => store.toggleThinking()} />
  </>;
}

export function MessageSheet({ copy, regen, speak }: { copy: () => void; regen?: () => void; speak?: () => void }) {
  const { close } = useMenu();
  const run = (fn: () => void) => () => { close(); fn(); };
  return <>
    <MenuItem title="复制" icon={<Icon name="copy" />} onClick={run(copy)} />
    {regen && <MenuItem title="重新生成" icon={<Icon name="retry" />} onClick={run(regen)} />}
    {speak && <MenuItem title="朗读" icon={<Icon name="speaker" />} onClick={run(speak)} />}
  </>;
}

const Stat = ({ k, v }: { k: string; v: string }) => <div className="stat"><span>{k}</span><span className="mono">{v}</span></div>;
const gb = (v: number | null) => (v === null ? '读不到' : `${v < 10 ? v.toFixed(1) : Math.round(v)} GB`);

export function ResourcesMenu() {
  const s = useApp(), st = backendState(s), m = currentModel(s), [, text] = engineStatus(s);
  const hint = {
    unset: '填好服务地址后，这里会显示连接情况。', nonet: '离线模式开着，连不了远程服务。', nogpu: '这个浏览器跑不了本机模型，可以换一个浏览器或改用远程服务。',
    nomodel: '模型下载好之后就能用了。', offline: `${isRemote(s) ? `${remoteHost(s)} 没有响应。` : '本机模型没有响应。'}检查后重试。`,
    ready: sendingOut(s) ? '图片和文字会发送到这台服务器处理。' : '',
  }[st];
  return <>
    <div className="perf-head"><b>{m?.name ?? '还没有模型'}</b><small>{text}</small></div>
    {m && <Stat k="能力" v={capsText(m)} />}
    {isRemote(s) ? <Stat k="服务" v={remoteHost(s) || '未设置'} /> : <>
      <Stat k="内存" v={gb(s.device.memoryGB)} />
      <Stat k="可用空间" v={gb(s.device.freeStorageGB)} />
      {s.loaded && <Stat k="已载入" v={option(s, s.loaded)?.short ?? ''} />}
    </>}
    {hint && <div className="hint">{hint}</div>}
  </>;
}
