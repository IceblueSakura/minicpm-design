import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { loadMark } from './core/persist';
import { AppStore } from './core/store';
import { createBackends } from './engine';
import { App } from './ui/App';
import { StoreContext } from './ui/hooks';
import './styles/app.css';

const store = new AppStore(createBackends());
void store.boot();
// A reload or a closed tab during a load is not a crash. A killed tab never fires this.
addEventListener('pagehide', loadMark.clear);

createRoot(document.getElementById('root')!).render(
  <StrictMode><StoreContext.Provider value={store}><App /></StoreContext.Provider></StrictMode>,
);
