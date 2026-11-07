import { useState } from 'react';
import type { ReactNode } from 'react';
import { backendState, capsText, currentModel, isBlank, isRemote, modelChoices, privacySummary, remoteHost, sendingOut, specText } from '../core/selectors';
import { SCENES, SCENE_IDS } from '../core/scenes';
import { PRESETS } from '../core/types';
import type { AppState, Prefs } from '../core/types';
import type { GenerationParams, ModelOption } from '../engine/types';
import { Icon } from './Icon';
import { MOD, useApp, useStore } from './hooks';
import { DownloadBar } from './Onboard';
import { useShell } from './Shell';
import type { SettingsTab } from './Shell';

const NAV: [string, [SettingsTab, string, string][]][] = [
  ['常用', [['general', '通用', 'gear'], ['voice', '回答与人设', 'speaker'], ['models', '模型', 'cpu'], ['privacy', '隐私与数据', 'shield'], ['applications', '应用场景', 'grid']]],
  ['', [['advanced', '高级', 'more']]],
];
const SUBPAGES: Partial<Record<SettingsTab, [string, SettingsTab]>> = {
  memories: ['已记住的内容', 'privacy'], network: ['联网记录', 'privacy'], resources: ['资源服务', 'advanced'],
};
const titleOf = (tab: SettingsTab) => SUBPAGES[tab]?.[0] ?? NAV.flatMap(([, items]) => items).find(([id]) => id === tab)?.[1] ?? '设置';

const Row = ({ name, desc, children }: { name: ReactNode; desc?: ReactNode; children?: ReactNode }) => (
  <div className="row"><div><b>{name}</b>{desc && <small>{desc}</small>}</div><div className="ctrl">{children}</div></div>
);
const Pill = ({ kind = '', children }: { kind?: string; children: ReactNode }) => <span className={`pill ${kind}`}>{children}</span>;

function Switch({ k, label }: { k: BooleanPref; label: string }) {
  const store = useStore(), on = useApp(s => s.prefs[k]);
  return <button className="sw" role="switch" aria-checked={on} aria-label={label} onClick={() => store.setPref(k, !on)} />;
}
type BooleanPref = { [K in keyof Prefs]: Prefs[K] extends boolean ? K : never }[keyof Prefs];

function Pick<K extends keyof Prefs>({ k, options, label }: { k: K; options: [string, string][]; label: string }) {
  const store = useStore(), value = useApp(s => s.prefs[k]);
  return <select aria-label={label} value={String(value)} onChange={e => store.setPref(k, e.target.value as Prefs[K])}>{options.map(([v, n]) => <option key={v} value={v}>{n}</option>)}</select>;
}

const LANGS: [string, string][] = [['zh-Hans', '简体中文'], ['zh-Hant-TW', '繁體中文（台灣）'], ['zh-Hant-HK', '繁體中文（香港）'], ['en', 'English']];

function General() {
  const store = useStore(), s = useApp(), { compact } = useShell();
  return <>
    <h2>通用</h2><p>外观和输入习惯。</p>
    <Row name="外观" desc="跟随系统时，会随日夜自动切换。">
      <select aria-label="外观" value={s.theme} onChange={e => store.setTheme(e.target.value as AppState['theme'])}><option value="system">跟随系统</option><option value="light">浅色</option><option value="dark">深色</option></select>
    </Row>
    {!compact && <Row name="发送方式" desc="输入法选词时按回车不会发送。">
      <select aria-label="发送方式" value={s.sendKey} onChange={e => store.setSendKey(e.target.value as AppState['sendKey'])}><option value="enter">Enter 发送，Shift+Enter 换行</option><option value="mod">{MOD}Enter 发送，Enter 换行</option></select>
    </Row>}
    <Row name="界面语言" desc="切换后立即生效。"><Pick k="lang" label="界面语言" options={[['system', '跟随系统'], ...LANGS]} /></Row>
    <Row name="文字大小"><Pick k="textSize" label="文字大小" options={[['s', '小'], ['m', '标准'], ['l', '大'], ['xl', '特大']]} /></Row>
    <h3>打开时</h3>
    <Row name="打开时进入"><Pick k="openTo" label="打开时进入" options={[['new', '新对话'], ['last', '上次的对话']]} /></Row>
    <Row name="新对话的场景"><Pick k="defaultScene" label="新对话的场景" options={SCENE_IDS.map(id => [id, SCENES[id].name])} /></Row>
  </>;
}

function Voice() {
  const store = useStore(), s = useApp();
  return <>
    <h2>回答与人设</h2><p>下一条消息生效。</p>
    <h3>回答</h3>
    <Row name="回答语言"><Pick k="replyLang" label="回答语言" options={[['ui', '跟随界面语言'], ...LANGS]} /></Row>
    <Row name="回答长度"><Pick k="replyLength" label="回答长度" options={[['short', '简短'], ['normal', '适中'], ['long', '详细']]} /></Row>
    <Row name="怎么称呼你"><input type="text" value={s.prefs.callName} placeholder="可不填" aria-label="怎么称呼你" onChange={e => store.setPref('callName', e.target.value)} /></Row>
    <h3>人设</h3>
    <label className="sr" htmlFor="persona">系统提示词</label>
    <textarea id="persona" value={s.persona} onChange={e => store.setPersona(e.target.value)} />
  </>;
}

function SpecPicker({ current }: { current: ModelOption }) {
  const store = useStore(), s = useApp();
  const [ask, setAsk] = useState<ModelOption | null>(null);
  const options = s.catalog.filter(o => o.family === current.family);
  if (options.length < 2) return null;
  return <>
    <h3>规格</h3>
    <p className="res-note">{current.name} 现在是{specText(current)}。换规格要重新下载，下载时可以继续用现在的。</p>
    <div className="voices specs" role="radiogroup" aria-label="规格">
      {options.map(o => {
        const tight = s.device.memoryGB !== null && o.memoryGB > s.device.memoryGB;
        return (
          <button key={o.id} className="voice" role="radio" aria-checked={(ask ?? current).id === o.id} disabled={tight} onClick={() => setAsk(o.id === current.id ? null : o)}>
            <span>
              <b>{o.spec.label} <span className="spec-tag">{o.spec.tag}</span></b>
              <small>{tight ? `需要约 ${o.memoryGB} GB 内存，这个浏览器不够` : o.spec.tag === 'Q4' ? '占用小，响应快' : '回答最接近原版，占用大'}</small>
              <small>{o.sizeGB.toFixed(1)} GB</small>
            </span>
          </button>
        );
      })}
    </div>
    {ask && (
      <div className="swap-ask" role="group" aria-label="确认换规格">
        <p>要下载 {ask.sizeGB.toFixed(1)} GB，下好后替换现在的 {current.sizeGB.toFixed(1)} GB。</p>
        <div className="acts">
          <button className="btn" onClick={() => { store.startDownload(ask.id); setAsk(null); }}>下载并替换</button>
          <button className="btn" onClick={() => setAsk(null)}>先不换</button>
        </div>
      </div>
    )}
  </>;
}

function Models() {
  const store = useStore(), s = useApp(), st = backendState(s), remote = isRemote(s), m = currentModel(s);
  const [ask, setAsk] = useState<ModelOption | null>(null);
  const status = st === 'ready' ? <Pill kind="ok">已连接</Pill> : st === 'unset' ? <Pill kind="warn">未配置</Pill> : <Pill kind="bad">未连接</Pill>;
  return <>
    <h2>模型</h2>
    <p>{remote ? '所有对话共用当前模型。' : '这个浏览器一次只运行一个模型，所有对话共用。换模型要等它重新载入。'}</p>
    <h3>可用模型</h3>
    {modelChoices(s).map(o => {
      const missing = !remote && !s.installed.includes(o.id);
      const sub = `${capsText(o)}${remote ? '' : ` · ${specText(o)} · ${o.sizeGB.toFixed(1)} GB`}`;
      if (s.dl?.optionId === o.id) return <div key={o.id}><Row name={o.name} desc={sub}><Pill>下载中</Pill></Row><DownloadBar /></div>;
      return <div key={o.id}>
        <Row name={o.name} desc={sub}>
          {missing ? <><Pill>未下载</Pill><button className="btn" disabled={!!s.dl} onClick={() => store.startDownload(o.id)}>下载</button></>
            : o.id === s.model ? <Pill kind="ok">{s.loading ? '载入中' : '使用中'}</Pill>
              : <><button className="btn" disabled={!!s.loading} onClick={() => (s.reply ? store.setModel(o.id) : setAsk(o))}>换用</button>{!remote && <button className="btn" onClick={() => void store.removeModel(o.id)}>移除</button>}</>}
        </Row>
        {ask?.id === o.id && (
          <div className="swap-ask" role="group" aria-label="确认换模型">
            <p>所有对话都会改用 {o.name}{remote ? '' : `，要等约 ${o.loadSeconds} 秒`}。</p>
            <div className="acts"><button className="btn" onClick={() => { setAsk(null); store.setModel(o.id); }}>换用</button><button className="btn" onClick={() => setAsk(null)}>先不换</button></div>
          </div>
        )}
      </div>;
    })}
    {!remote && m && s.installed.includes(m.id) && <SpecPicker current={m} />}
    {!remote && <p className="res-note">模型保存在这个浏览器里，清除网站数据时会一起删除。</p>}
    <h3>看图</h3>
    <Row name="高清细节" desc="看清小字和细节，响应会变慢。"><Switch k="hd" label="高清细节" /></Row>
    <h3>运行方式</h3>
    <div className="voices" role="radiogroup" aria-label="运行方式">
      {(Object.keys(PRESETS) as (keyof typeof PRESETS)[]).map(id => (
        <button key={id} className="voice" role="radio" aria-checked={s.preset === id} onClick={() => store.setPreset(id)}><span><b>{PRESETS[id].label}</b><small>{PRESETS[id].sub}</small></span></button>
      ))}
    </div>
    {s.preset === 'custom' && <p className="res-note">当前使用自定义参数，在“高级”里查看。</p>}
    <h3>电量与发热</h3>
    <Row name="空闲后释放内存" desc="让出内存给其他应用，下次使用时要重新载入。"><Pick k="idleRelease" label="空闲后释放内存" options={[['5', '5 分钟后'], ['15', '15 分钟后'], ['60', '1 小时后'], ['never', '不释放']]} /></Row>
    <Row name="发热时降低负载" desc="响应会变慢，设备会更凉快。"><Switch k="thermal" label="发热时降低负载" /></Row>
    <details className="disclose" open={remote || undefined}>
      <summary><Icon name="chev" />运行位置<span>{remote ? '远程服务' : '这台设备'}</span></summary>
      <div className="voices" role="radiogroup" aria-label="运行位置">
        <button className="voice" role="radio" aria-checked={!remote} onClick={() => store.setBackend('local')}>
          <Icon name="shield" /><span><b>这台设备</b><small>{s.device.canRunLocal ? `在这个浏览器里运行，内容不离开本机${s.prefs.tech ? ' · WebGPU' : ''}` : '这个浏览器跑不了，换一个浏览器后可用'}</small></span>
        </button>
        <button className="voice" role="radio" aria-checked={remote} onClick={() => store.setBackend('remote')}>
          <Icon name="server" /><span><b>远程服务</b><small>内容会发送到你指定的服务器</small></span>
        </button>
      </div>
      {remote && <>
        <Row name="服务地址" desc="MiniCPM 服务的 WebSocket 地址。"><input type="text" value={s.remote.url} placeholder="wss://example.com/omni" aria-label="服务地址" onChange={e => store.setRemoteUrl(e.target.value)} /></Row>
        <Row name="访问令牌" desc="服务要求鉴权时填写。"><input type="password" autoComplete="off" placeholder={s.remote.hasToken ? '已保存' : '未设置'} aria-label="访问令牌" onChange={e => store.setRemoteToken(e.target.value)} /></Row>
        <Row name="连接状态">{status}<button className="btn" onClick={() => store.notYet()}>测试连接</button></Row>
      </>}
    </details>
  </>;
}

function Privacy() {
  const store = useStore(), s = useApp(), { openTab } = useTabs();
  const [title, body] = privacySummary(s);
  const count = s.conversations.filter(c => !c.temp && !isBlank(c)).length;
  const [ask, setAsk] = useState(false);
  return <>
    <h2>隐私与数据</h2><p>决定哪些内容留在这台设备上。</p>
    <div className="assure"><Icon name="shield" /><div><b>{title}</b><small>{body}</small></div></div>
    <h3>联网</h3>
    <Row name="离线模式" desc="关闭所有联网功能，包括更新、联网搜索和远程服务。"><Switch k="offlineMode" label="离线模式" /></Row>
    <Row name="联网搜索" desc="需要时让它上网查资料，搜索词会离开这台设备。"><Pick k="webSearch" label="联网搜索" options={[['off', '关闭'], ['ask', '每次询问'], ['auto', '自动']]} /></Row>
    <Row name="自动检查更新" desc="只发送版本号。"><Switch k="updates" label="自动检查更新" /></Row>
    <Row name="匿名使用统计" desc="不包含对话和文件。"><Switch k="analytics" label="匿名使用统计" /></Row>
    <Row name="崩溃报告"><Pick k="crash" label="崩溃报告" options={[['ask', '每次询问'], ['never', '不发送'], ['auto', '自动发送']]} /></Row>
    <Row name="联网记录" desc={sendingOut(s) ? `内容正发送到 ${remoteHost(s)}。` : '最近 7 天没有内容离开这台设备。'}><button className="btn" onClick={() => openTab('network')}>查看</button></Row>
    <h3>对话记录</h3>
    <Row name="保存对话记录" desc="关闭后，对话只在打开期间存在。"><Switch k="keepHistory" label="保存对话记录" /></Row>
    <Row name="新对话默认为临时对话" desc="临时对话结束后不留记录。"><Switch k="tempDefault" label="新对话默认为临时对话" /></Row>
    <Row name="自动清理" desc="到期的对话会从这台设备上删除。"><Pick k="retention" label="自动清理" options={[['never', '不清理'], ['90', '90 天后'], ['30', '30 天后'], ['7', '7 天后']]} /></Row>
    <h3>记忆</h3>
    <Row name="记住我的偏好" desc="从对话里记下习惯和常用信息。"><Switch k="memory" label="记住我的偏好" /></Row>
    <Row name="已记住的内容" desc={`${s.memories.length} 条`}><button className="btn" onClick={() => openTab('memories')}>管理</button></Row>
    <h3>备份与迁移</h3>
    <Row name="导出对话" desc={`把 ${count} 个对话存成一个文件，换设备时可以导入。文件里有对话全文，由你保管。`}><button className="btn" onClick={() => store.notYet()}>导出</button></Row>
    <Row name="导入对话" desc="从导出的文件恢复。不覆盖现有对话，重复的会跳过。"><button className="btn" onClick={() => store.notYet()}>导入</button></Row>
    <h3>数据</h3>
    <Row name="清除全部对话" desc="对话和材料都会从这台设备上删除。"><button className="btn danger" onClick={() => setAsk(true)}>清除</button></Row>
    {ask && (
      <div className="swap-ask" role="group" aria-label="确认清除">
        <p>关掉这个页面后不能再撤销。</p>
        <div className="acts"><button className="btn danger" onClick={() => { setAsk(false); store.clearAll(); }}>清除全部</button><button className="btn" onClick={() => setAsk(false)}>先不</button></div>
      </div>
    )}
  </>;
}

function Memories() {
  const store = useStore(), s = useApp(), out = sendingOut(s);
  return <>
    <h2>已记住的内容</h2>
    <p>这些内容{out ? '' : '只'}保存在这台设备上，用来让回答更贴合你。{out && `用远程服务时，用得上的内容会随请求发送到 ${remoteHost(s)}。`}</p>
    {s.memories.length ? s.memories.map((m, i) => <Row key={m} name={m}><button className="btn" onClick={() => store.forget(i)}>删除</button></Row>) : <p className="ins-empty">还没有记住任何内容。</p>}
  </>;
}

function Network() {
  const s = useApp(), out = sendingOut(s), week = s.netLog.filter(n => Date.now() - n.at < 7 * 864e5);
  return <>
    <h2>联网记录</h2><p>列出最近 7 天这台设备发出的所有请求。</p>
    <div className="assure"><Icon name="shield" /><div>
      <b>{out ? `内容正发送到 ${remoteHost(s)}` : '没有内容离开这台设备'}</b>
      <small>{out ? '下面写明了发送什么、发到哪里。' : '下面的请求不包含你的对话或文件。'}</small>
    </div></div>
    <h3>最近 7 天</h3>
    {out && <Row name="远程服务" desc={`每次使用 · 图片和文字发送到 ${remoteHost(s)}`}><Pill kind="warn">进行中</Pill></Row>}
    {week.map(n => <Row key={n.at} name={n.kind} desc={n.detail}><Pill>1 次</Pill></Row>)}
    {!out && !week.length && <p className="ins-empty">最近 7 天没有请求。</p>}
  </>;
}

const PARAMS: [keyof GenerationParams, string, string, number, number, number][] = [
  ['max_tokens', '回答长度上限', '回答最长能写多少。', 256, 4096, 256],
  ['temperature', '随机程度', '越高越有变化，越低越稳定。', 0, 1.5, .05],
  ['top_p', '选词范围', '越小用词越保守。', .1, 1, .05],
  ['top_k', '候选词数量', '每一步考虑多少个候选词。', 1, 100, 1],
  ['repeat_penalty', '避免重复', '越高越不容易重复同样的话。', 1, 1.5, .01],
];

function Advanced() {
  const store = useStore(), s = useApp(), { openTab } = useTabs();
  return <>
    <h2>高级</h2><p>大多数情况下不用改。改动后，运行方式会显示为“自定义”。</p>
    <h3>回答</h3>
    {PARAMS.map(([key, name, desc, min, max, step]) => (
      <div className="param" key={key}>
        <div className="param-top"><b>{name}</b><span className="tech">{key}</span><output className="mono">{s.params[key]}</output></div>
        <input type="range" min={min} max={max} step={step} value={s.params[key]} aria-label={name} onChange={e => store.setParam(key, Number(e.target.value))} />
        <small>{desc}</small>
      </div>
    ))}
    <h3>设备</h3>
    <Row name={<>对话记忆长度 <span className="tech">n_ctx</span></>} desc="记得更多会占用更多内存。">
      <select aria-label="对话记忆长度" value={s.params.n_ctx} onChange={e => store.setParam('n_ctx', Number(e.target.value))}>{[2048, 4096, 8192, 16384].map(v => <option key={v} value={v}>{v}</option>)}</select>
    </Row>
    <h3>显示</h3>
    <Row name="显示技术信息" desc="在回答里显示速度。"><Switch k="tech" label="显示技术信息" /></Row>
    <Row name="恢复默认" desc="把上面的参数改回“均衡”。"><button className="btn" onClick={() => store.resetParams()}>恢复</button></Row>
    <h3>开发者</h3>
    <Row name="资源服务" desc="媒体、工具与外部通道"><button className="btn" onClick={() => openTab('resources')}>查看</button></Row>
  </>;
}

function Applications() {
  const store = useStore(), s = useApp();
  return <>
    <h2>应用场景</h2><p>不同场景下，建议不一样。</p>
    <h3>场景</h3>
    {SCENE_IDS.map(id => (
      <Row key={id} name={SCENES[id].name} desc={`${SCENES[id].hint} · ${SCENES[id].source}`}>
        <button className="sw" role="switch" aria-checked={!s.sceneOff.includes(id)} aria-label={`显示${SCENES[id].name}`} disabled={id === s.prefs.defaultScene} onClick={() => store.toggleScene(id)} />
      </Row>
    ))}
    <p className="res-note">关闭后不再出现在新对话里，已有对话不受影响。默认场景不能关闭。</p>
  </>;
}

const Resources = () => <>
  <h2>资源服务</h2><p>Resource 层对接媒体、工具与外部通道。</p>
  <Row name="Online Service" desc="在线能力与服务配置。"><Pill>未配置</Pill></Row>
  <Row name="Computer Use" desc="工具执行与权限边界。"><Pill>未配置</Pill></Row>
  <Row name="Gateway" desc="外部消息通道。"><Pill kind="warn">未配置</Pill></Row>
</>;

const PAGES: Record<Exclude<SettingsTab, 'index'>, () => ReactNode> = {
  general: General, voice: Voice, models: Models, privacy: Privacy, applications: Applications, advanced: Advanced, memories: Memories, network: Network, resources: Resources,
};

const useTabs = () => { const { openSettings } = useShell(); return { openTab: openSettings }; };

export function Settings() {
  const { settings: tab, compact, openSettings, closeSettings } = useShell();
  if (!tab) return null;
  const root = tab === 'index', parent = SUBPAGES[tab]?.[1], back = parent || (compact && !root), closable = !compact || root;
  const Page = root ? null : PAGES[tab];
  return (
    <section className={`settings${root ? ' at-root' : ''}`} aria-label="设置">
      <div className="set-head">
        {back ? <><button className="icon-btn" aria-label="返回" onClick={() => openSettings(parent ?? 'index')}><Icon name="chev" className="i back" /></button>{titleOf(tab)}</> : '设置'}
        <span className="grow" />
        {closable && <button className="icon-btn" aria-label="关闭设置" title="关闭 (Esc)" onClick={closeSettings}><Icon name="close" /></button>}
      </div>
      <nav className="set-nav" aria-label="设置分类">
        {NAV.map(([group, items]) => <div key={group}>
          <div className="grp">{group}</div>
          {items.map(([id, name, icon]) => (
            <button key={id} aria-current={id === tab || id === parent ? 'page' : undefined} onClick={() => openSettings(id)}><Icon name={icon} />{name}</button>
          ))}
        </div>)}
      </nav>
      <div className="set-body"><div className="set-in">{Page && <Page />}</div></div>
    </section>
  );
}
