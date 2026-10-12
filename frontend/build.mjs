/**
 * frontend/src → ../dist (device deploy root)
 */
import { cpSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const fe = __dirname;
const root = resolve(fe, '..');
const dist = resolve(root, 'dist');

function ensureDirs() {
  for (const d of ['js', 'css', 'vendor', 'cgi-bin/lib']) {
    mkdirSync(resolve(dist, d), { recursive: true });
  }
}

function findEsbuild() {
  if (process.env.ESBUILD) return process.env.ESBUILD;
  const local = resolve(fe, 'node_modules/esbuild/bin/esbuild');
  if (existsSync(local)) return local;
  const rootLocal = resolve(root, 'node_modules/esbuild/bin/esbuild');
  if (existsSync(rootLocal)) return rootLocal;
  return 'esbuild';
}

ensureDirs();
const bin = findEsbuild();
const r = spawnSync(
  bin,
  [
    resolve(fe, 'src/main.js'),
    '--bundle',
    '--outfile=' + resolve(dist, 'js/app.bundle.js'),
    '--format=iife',
    '--platform=browser',
    '--target=es2018',
    '--minify',
  ],
  { stdio: 'inherit' }
);
if (r.status !== 0) {
  console.error('esbuild failed. npm i in frontend/ or ESBUILD=/path/to/esbuild');
  process.exit(r.status || 1);
}

cpSync(resolve(fe, 'assets/css/app.css'), resolve(dist, 'css/app.css'));
cpSync(resolve(fe, 'assets/vendor/vue.global.prod.js'), resolve(dist, 'vendor/vue.global.prod.js'));
cpSync(resolve(fe, 'index.html'), resolve(dist, 'index.html'));
cpSync(resolve(root, 'backend/api.cgi'), resolve(dist, 'cgi-bin/api.cgi'));
cpSync(resolve(root, 'backend/lib/common.sh'), resolve(dist, 'cgi-bin/lib/common.sh'));
cpSync(resolve(root, 'backend/lib/sms.sh'), resolve(dist, 'cgi-bin/lib/sms.sh'));
cpSync(resolve(root, 'backend/lib/time.sh'), resolve(dist, 'cgi-bin/lib/time.sh'));
cpSync(resolve(root, 'init/start-sms-monitor.sh'), resolve(dist, 'start-sms-monitor.sh'));

console.log('OK → dist/');
