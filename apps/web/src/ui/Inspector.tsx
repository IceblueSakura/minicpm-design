import { capsText, current, currentModel, isRemote, kindText, processedAt, remoteHost, specText } from '../core/selectors';
import { SCENES } from '../core/scenes';
import { Icon } from './Icon';
import { useApp } from './hooks';
import { useMenu } from './Menu';
import { SceneMenu } from './menus';
import { useShell } from './Shell';

export function Inspector() {
  const s = useApp(), c = current(s), m = currentModel(s), { toggleInspector } = useShell(), { open } = useMenu();
  return (
    <aside className="inspector" aria-label="对话详情">
      <div className="ins-top">对话详情<button className="icon-btn" aria-label="关闭对话详情" onClick={toggleInspector}><Icon name="close" /></button></div>
      <div className="ins-sec">
        <h3>处理位置</h3>
        <div className="ins-item"><Icon name="shield" /><span className="nm">{isRemote(s) ? remoteHost(s) || '还没设置远程服务' : '这台设备'}</span></div>
        <p className="ins-empty">{processedAt(s)}</p>
      </div>
      <div className="ins-sec">
        <h3>材料</h3>
        {c.sources.length ? c.sources.map((name, i) => <div className="ins-item" key={i}><Icon name="clip" /><span className="nm">{name}</span></div>) : <p className="ins-empty">发送的文件会收在这里。</p>}
      </div>
      <div className="ins-sec">
        <h3>应用场景</h3>
        <div className="ins-item">
          <span className="nm">{SCENES[c.scene].name}</span>
          <button
            className="btn" style={{ minHeight: 28, padding: '0 9px', fontSize: 12.5 }} aria-haspopup="menu"
            onClick={e => open({ key: 'scene-ins', anchor: e.currentTarget, label: '应用场景', role: 'menu', render: () => <SceneMenu /> })}
          >更换</button>
        </div>
        <p className="ins-empty">{SCENES[c.scene].hint}</p>
      </div>
      {m && (
        <div className="ins-sec">
          <h3>模型</h3>
          <div className="ins-item"><span className="nm">{m.name}</span><span className="pill">{kindText(m)}</span></div>
          <p className="ins-empty">{isRemote(s) ? '' : `${specText(m)} · `}{capsText(m)}</p>
        </div>
      )}
    </aside>
  );
}
