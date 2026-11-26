// Spike checks for the gyo WebView shell. Can the web layer load community
// media directly, and receive community HTML through the native relay?

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';
const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Mobile Safari/537.36';

const SITES = {
  humoruniv: {
    label: '웃대',
    url: 'https://m.humoruniv.com/board/list.html?table=pds&pg=0',
    headers: { 'User-Agent': MOBILE_UA, Referer: 'https://m.humoruniv.com/board/pds/' },
  },
  ppomppu: {
    label: '뽐뿌',
    url: 'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor&page=1',
    headers: { 'User-Agent': DESKTOP_UA, Referer: 'https://www.ppomppu.co.kr/zboard/zboard.php?id=humor' },
  },
  dogdrip: {
    label: '개드립',
    url: 'https://www.dogdrip.net/index.php?mid=dogdrip&page=1',
    headers: { 'User-Agent': DESKTOP_UA, Referer: 'https://www.dogdrip.net/index.php?mid=dogdrip' },
    mediaHost: 'dogdrip\\.net',
  },
  bobaedream: {
    label: '보배드림',
    url: 'https://www.bobaedream.co.kr/list?code=humor&page=1',
    headers: { 'User-Agent': DESKTOP_UA, Referer: 'https://www.bobaedream.co.kr/list?code=humor' },
    mediaHost: 'bobaedream\\.co\\.kr',
  },
  ruliweb: {
    label: '루리웹',
    url: 'https://bbs.ruliweb.com/best/humor?page=1',
    headers: { 'User-Agent': DESKTOP_UA, Referer: 'https://bbs.ruliweb.com/best/humor' },
    mediaHost: 'ruliweb\\.com',
  },
  natepann: {
    label: '네이트판n',
    url: 'https://pann.nate.com/talk?page=1',
    headers: { 'User-Agent': DESKTOP_UA, Referer: 'https://pann.nate.com/talk' },
    mediaHost: 'pann\\.com',
  },
};

// Captured from live pages while writing the spike. Used only when discovery
// in the relay-fetched list finds nothing (or the fetch failed).
const FALLBACK_MEDIA = {
  humoruniv: ['https://down-webp.humoruniv.com/28/28a1ef5635f9bfc0f25b018184300234491072db.webp'],
  dogdrip: [
    'https://www.dogdrip.net/dvs/d/26/11/25/218f3a45f0296b0ada76977d4fd9aa1e.jpg',
    'https://rc.dogdrip.net/files/thumbnails/567/538/736/100x100.crop.jpg?t=1795582796',
  ],
  bobaedream: ['https://file1.bobaedream.co.kr/humor/2026/11/19/09/AVQS1795049348_784752664.jpg'],
  ruliweb: ['https://i1.ruliweb.com/img/26/11/26/1a214bfd99257d2f2.webp'],
  natepann: ['https://fimg6.pann.com/new/download.jsp?FileID=69704104'],
  todayhumor: [
    'https://thimg.todayhumor.co.kr/upfile/202607/1785147568f6bc5df46d3247b1b3b8093ce417d37d__mn537055__w600__h8628__f601159__Ym202607.jpg',
  ],
};
const FALLBACK_VIDEO = 'https://i2.ruliweb.com/ori/26/11/26/1a214b20fd8513930.mp4';

// --- gyo bridge protocol (same shape as @gyo-framework/bridge) -------------
// The shell injects `window.gyo.__bridge.postMessage` once the page has
// loaded; the web side owns `window.gyoBridge`.
const pending = new Map();
window.gyoBridge = {
  resolve(callbackId, data) {
    const entry = pending.get(callbackId);
    if (entry) {
      pending.delete(callbackId);
      entry.resolve(data);
    }
  },
  reject(callbackId, error) {
    const entry = pending.get(callbackId);
    if (entry) {
      pending.delete(callbackId);
      entry.reject(new Error(error));
    }
  },
  publish() {},
};

const hasNativeBridge = () => Boolean(window.gyo && window.gyo.__bridge);

async function waitForNativeBridge(timeoutMs) {
  const deadline = performance.now() + timeoutMs;
  while (!hasNativeBridge() && performance.now() < deadline) {
    await new Promise((done) => setTimeout(done, 50));
  }
  return hasNativeBridge();
}

/** GET `url` with `headers` through the native relay (or the dev relay). */
function relay(url, headers = {}) {
  if (hasNativeBridge()) {
    return new Promise((resolve, reject) => {
      const callbackId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
      const timer = setTimeout(() => {
        pending.delete(callbackId);
        reject(new Error('bridge timeout'));
      }, 45000);
      pending.set(callbackId, {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      });
      window.gyo.__bridge.postMessage({
        bridgeName: 'http',
        methodName: 'request',
        data: { url, headers },
        callbackId,
      });
    });
  }
  const query = new URLSearchParams({ url, headers: btoa(JSON.stringify(headers)) });
  return fetch(`/__relay?${query}`).then(async (response) => {
    if (!response.ok) throw new Error(`dev relay HTTP ${response.status}`);
    return response.json();
  });
}

function b64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// --- rendering --------------------------------------------------------------
function h(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else node.setAttribute(key, value);
  }
  for (const child of children) if (child != null) node.append(child);
  return node;
}

const checks = document.querySelector('#checks');

function section(letter, title, why) {
  const chip = h('span', { class: 'chip', text: '…' });
  const body = h('div');
  const detail = h('div');
  checks.append(
    h(
      'section',
      { class: 'check', id: `check-${letter}` },
      h('h2', {}, `${letter} · ${title}`, chip),
      h('p', { class: 'why', text: why }),
      body,
      detail,
    ),
  );
  return {
    chip,
    body,
    detail,
    pass(ok, text) {
      chip.className = `chip ${ok ? 'pass' : 'fail'}`;
      chip.textContent = text;
    },
    info(text, cls = '') {
      detail.append(h('p', { class: `line ${cls}`, text }));
    },
  };
}

// --- checks ----------------------------------------------------------------
async function checkPages() {
  const s = section(
    'B',
    '릴레이로 HTML 받기',
    'WebView가 직접 받으면 CORS·Referer·UA에 막힙니다. 셸의 http.request가 헤더를 그대로 보내는지 확인합니다.',
  );
  const pages = {};
  for (const [key, site] of Object.entries(SITES)) {
    const started = performance.now();
    try {
      const response = await relay(site.url, site.headers);
      const bytes = response.bodyBase64 ? Math.floor((response.bodyBase64.length * 3) / 4) : 0;
      pages[key] = {
        ...response,
        bytes,
        clientMs: Math.round(performance.now() - started),
      };
      s.info(
        `${site.label}: ${response.status} · ${(bytes / 1024).toFixed(0)} KB · `
          + `네이티브 ${response.elapsedMs} ms / 왕복 ${pages[key].clientMs} ms`,
        response.status === 200 ? 'ok' : 'bad',
      );
    } catch (error) {
      pages[key] = { status: 0, error: error.message };
      s.info(`${site.label}: 실패 — ${error.message}`, 'bad');
    }
  }

  const controls = [
    ['뽐뿌', SITES.ppomppu.url, { 'User-Agent': DESKTOP_UA }, 'Referer 없음 (curl로는 403, 클라이언트에 따라 다름)'],
    ['루리웹', SITES.ruliweb.url, { 'User-Agent': navigator.userAgent }, '이 WebView의 UA → 302 기대'],
    ['네이트판n', SITES.natepann.url, { 'User-Agent': navigator.userAgent }, '이 WebView의 UA → 302 기대'],
  ];
  for (const [label, url, headers, note] of controls) {
    try {
      const response = await relay(url, headers);
      s.info(`대조 · ${label}: ${response.status} (${note})`, 'muted');
    } catch (error) {
      s.info(`대조 · ${label}: 실패 — ${error.message}`, 'muted');
    }
  }

  const ok = Object.keys(SITES).every((key) => pages[key].status === 200);
  s.pass(ok, ok ? 'PASS' : 'FAIL');
  return pages;
}

function discoverImages(html, hostPattern) {
  if (!html) return [];
  const pattern = new RegExp(
    `(?:https?:)?//([a-z0-9.-]+\\.(?:${hostPattern}))(/[^"'\\s<>)]*?\\.(?:jpe?g|png|webp))(?:\\?[^"'\\s<>)]*)?`,
    'gi',
  );
  const uiAsset = /logo|icon|noimage|btn|badge|sprite|\/images\//i;
  const seen = new Set();
  return [...html.replaceAll('\\/', '&').matchAll(pattern)]
    .map((match) => `https://${match[1]}${match[2]}`)
    .filter((url) => !uiAsset.test(url) && !seen.has(url) && seen.add(url))
    .slice(0, 2);
}

function loadImage(url) {
  return new Promise((resolve) => {
    const image = new Image();
    const timer = setTimeout(() => resolve({ ok: false, note: 'timeout' }), 20000);
    image.onload = () => {
      clearTimeout(timer);
      resolve({ ok: true, note: `${image.naturalWidth}x${image.naturalHeight}` });
    };
    image.onerror = () => {
      clearTimeout(timer);
      resolve({ ok: false, note: 'error' });
    };
    image.src = url;
  });
}

async function checkMedia(pages) {
  const s = section(
    'A',
    '미디어 직접 로드',
    '문서의 referrer 정책이 no-referrer일 때, WebView가 커뮤니티 CDN의 이미지를 네이티브 도움 없이 받는지 확인합니다.',
  );
  const thumbs = h('div', { class: 'thumbs' });
  s.body.append(thumbs);

  const targets = [];
  for (const [key, site] of Object.entries(SITES)) {
    const discovered = site.mediaHost
      ? discoverImages(pages[key]?.bodyBase64 ? utf8(pages[key]) : '', site.mediaHost)
      : [];
    for (const url of [...discovered, ...(FALLBACK_MEDIA[key] || [])].slice(0, 2)) {
      targets.push({ key, url, origin: discovered.includes(url) ? '목록에서 찾음' : '고정 URL' });
    }
  }
  for (const url of FALLBACK_MEDIA.todayhumor) {
    targets.push({ key: 'todayhumor', url, origin: '고정 URL' });
  }

  const loaded = {};
  await Promise.all(
    targets.map(async ({ key, url, origin }) => {
      const result = await loadImage(url);
      if (result.ok) loaded[key] = (loaded[key] || 0) + 1;
      const host = new URL(url).host;
      thumbs.append(
        h(
          'figure',
          { class: `thumb ${result.ok ? '' : 'broken'}` },
          h('img', { src: url, alt: host }),
          h('figcaption', {
            text: `${result.ok ? '✓' : '✗'} ${SITES[key]?.label || '오유'} · ${host} · ${origin} · ${result.note}`,
          }),
        ),
      );
    }),
  );

  const sitesLoaded = Object.keys(loaded).length;
  const total = Object.values(loaded).reduce((sum, n) => sum + n, 0);
  s.info(`로드된 이미지 ${total}개 / ${targets.length}개, 사이트 ${sitesLoaded}개`, 'ok');
  const ok = total >= 5 && sitesLoaded >= 4;
  s.pass(ok, ok ? 'PASS' : 'FAIL');

  // Control: the same image from a document that does send a Referer. It has
  // to be a real document — a srcdoc iframe inherits this page's policy.
  const controlUrl = FALLBACK_MEDIA.bobaedream[0];
  const frame = h('iframe', { title: 'referer control', src: `/control.html?src=${encodeURIComponent(controlUrl)}` });
  window.addEventListener('message', (event) => {
    if (event.origin !== location.origin || event.data?.source !== 'referer-control') return;
    const blocked = event.data.result === 'blocked';
    s.info(
      `대조 결과: ${blocked ? '차단됨' : '로드됨'} — Referer "${event.data.referer}"를 보냄 `
        + `(이 주소의 Referer 기준, 실제 호스팅 주소에서는 다를 수 있음)`,
      'muted',
    );
  });
  s.body.append(h('p', { class: 'line muted', text: '대조 · Referer를 보내는 문서에서 같은 이미지 (차단되어야 정상):' }), frame);

  // The control document sits on a private LAN address, which CDNs tend to
  // allow. The hosted app will send a public origin, so ask for the same
  // image with one to see the rule the app will actually meet.
  const withHeaders = async (label, headers) => {
    try {
      const response = await relay(controlUrl, headers);
      s.info(`대조 · 릴레이로 같은 이미지, ${label}: ${response.status}`, 'muted');
    } catch (error) {
      s.info(`대조 · 릴레이로 같은 이미지, ${label}: 실패 — ${error.message}`, 'muted');
    }
  };
  await withHeaders('공개 주소 Referer', { 'User-Agent': navigator.userAgent, Referer: 'https://keek-news.github.io/' });
  await withHeaders('Referer 없음', { 'User-Agent': navigator.userAgent });
}

function utf8(response) {
  return new TextDecoder().decode(b64ToBytes(response.bodyBase64));
}

async function checkDecode(pages) {
  const s = section(
    'C',
    '디코딩과 파싱',
    '릴레이가 돌려준 바이트를 웹이 직접 디코딩·파싱합니다. 뽐뿌는 EUC-KR, 웃대는 UTF-8입니다.',
  );
  let ok = true;

  const ppomppu = pages.ppomppu;
  if (ppomppu?.status === 200) {
    const bytes = b64ToBytes(ppomppu.bodyBase64);
    try {
      const text = new TextDecoder('euc-kr').decode(bytes);
      const doc = new DOMParser().parseFromString(text, 'text/html');
      const titles = [...doc.querySelectorAll('a[href*="view.php?id=humor"]')]
        .map((a) => a.textContent.trim())
        .filter(Boolean);
      const hangul = (text.match(/[\uAC00-\uD7A3]/g) || []).length;
      const replaced = (text.match(/\uFFFD/g) || []).length;
      s.info(`뽐뿌 TextDecoder('euc-kr'): 한글 ${hangul}자, 깨진 문자 ${replaced}개, 제목 ${titles.length}개`);
      for (const title of titles.slice(0, 3)) s.info(`  · ${title.slice(0, 60)}`, 'muted');
      const wrong = new TextDecoder().decode(bytes).replace(/<[^>]+>/g, ' ').match(/[\uAC00-\uD7A3]{2,}/g);
      s.info(`대조 · 같은 바이트를 UTF-8로 디코딩: ${wrong ? wrong.slice(0, 3).join(' ') : '(한글 없음)'}`, 'muted');
      ok = ok && hangul > 500 && replaced === 0 && titles.length >= 1;
    } catch (error) {
      s.info(`뽐뿌 디코딩 실패 — ${error.message}`, 'bad');
      ok = false;
    }
  } else {
    s.info('뽐뿌 페이지를 못 받아 디코딩을 건너뜁니다.', 'bad');
    ok = false;
  }

  const humoruniv = pages.humoruniv;
  if (humoruniv?.status === 200) {
    const doc = new DOMParser().parseFromString(utf8(humoruniv), 'text/html');
    const rows = doc.querySelectorAll('a.post_link');
    const titles = [...doc.querySelectorAll('a.post_link span.link_hover')].map((n) => n.textContent.trim());
    s.info(`웃대 DOMParser: 게시글 ${rows.length}건`);
    for (const title of titles.slice(0, 3)) s.info(`  · ${title.slice(0, 60)}`, 'muted');
    ok = ok && rows.length >= 10;
  } else {
    s.info('웃대 페이지를 못 받아 파싱을 건너뜁니다.', 'bad');
    ok = false;
  }

  s.pass(ok, ok ? 'PASS' : 'FAIL');
  return humoruniv;
}

async function checkLargePage(pages) {
  const s = section(
    'D',
    '큰 페이지 왕복',
    '웃대 상세 페이지 약 300KB가 릴레이를 왕복하는 데 시간이 얼마나 더 걸리는지 측정합니다. 기준은 사이트 응답 시간 위에 0.5초까지.',
  );
  const site = SITES.humoruniv;
  let doc = null;
  if (pages.humoruniv?.status === 200) {
    doc = new DOMParser().parseFromString(utf8(pages.humoruniv), 'text/html');
  }
  const href = doc?.querySelector('a.post_link')?.getAttribute('href');
  if (!href) {
    s.info('웃대 목록에서 상세 링크를 찾지 못했습니다.', 'bad');
    s.pass(false, 'FAIL');
    return;
  }
  const url = new URL(href, site.url).href;

  // Longest gap between animation frames while the request is in flight.
  let last = performance.now();
  let maxGap = 0;
  let running = true;
  (function frame(now) {
    maxGap = Math.max(maxGap, now - last);
    last = now;
    if (running) requestAnimationFrame(frame);
  })(last);

  try {
    const started = performance.now();
    const response = await relay(url, site.headers);
    const totalMs = Math.round(performance.now() - started);
    const decodeStarted = performance.now();
    const bytes = response.bodyBase64 ? b64ToBytes(response.bodyBase64) : new Uint8Array(0);
    const decodeMs = (performance.now() - decodeStarted).toFixed(1);
    running = false;
    // The site's own latency (humoruniv answers in ~2 s) is not the relay's
    // fault: judge only the time spent on top of it.
    const overheadMs = totalMs - (response.elapsedMs ?? 0);
    s.info(
      `${url}\n${response.status} · ${(bytes.length / 1024).toFixed(0)} KB · `
        + `사이트 응답 ${response.elapsedMs} ms / 왕복 ${totalMs} ms / 릴레이 오버헤드 ${overheadMs} ms / `
        + `base64 디코딩 ${decodeMs} ms`,
    );
    await new Promise((done) => setTimeout(done, 200));
    s.info(`요청 중 가장 긴 프레임 간격 ${maxGap.toFixed(0)} ms`, 'muted');
    const ok = response.status === 200 && overheadMs < 500;
    s.pass(ok, ok ? 'PASS' : 'FAIL');
  } catch (error) {
    running = false;
    s.info(`실패 — ${error.message}`, 'bad');
    s.pass(false, 'FAIL');
  }
}

function setupVideo() {
  const s = section(
    'E',
    '동영상 재생·전체화면',
    '직접 눌러서 확인합니다. 셸에 전체화면 콜백이 없어 전체화면은 실패할 것으로 예상합니다.',
  );
  const video = h('video', { controls: '', playsinline: '', preload: 'metadata', src: FALLBACK_VIDEO });
  video.addEventListener('loadedmetadata', () =>
    s.info(`메타데이터 로드: ${video.videoWidth}x${video.videoHeight}, ${video.duration.toFixed(1)}초`, 'ok'),
  );
  video.addEventListener('error', () =>
    s.info(`동영상 오류 code=${video.error?.code ?? '?'} (헤드리스 Chromium은 H.264 코덱이 없음)`, 'bad'),
  );
  const play = h('button', { text: '재생' });
  play.addEventListener('click', () =>
    video.play().then(() => s.info('play(): 시작됨', 'ok')).catch((error) => s.info(`play(): ${error.message}`, 'bad')),
  );
  const fullscreen = h('button', { text: '전체화면' });
  fullscreen.addEventListener('click', () => {
    const request = video.requestFullscreen?.();
    if (request?.then) {
      request.then(() => s.info('전체화면: 성공', 'ok')).catch((error) => s.info(`전체화면: ${error.message}`, 'bad'));
    } else {
      s.info('전체화면: API 없음', 'bad');
    }
  });
  s.body.append(video, play, fullscreen);
  s.chip.className = 'chip info';
  s.chip.textContent = '직접 확인';
}

function renderSummary() {
  const summary = document.querySelector('#summary');
  for (const node of document.querySelectorAll('.check')) {
    const chip = node.querySelector('.chip');
    const title = node.querySelector('h2').textContent.replace(chip.textContent, '').trim();
    summary.append(h('li', {}, h('span', { class: chip.className, text: chip.textContent }), ` ${title}`));
  }
}

async function main() {
  const native = await waitForNativeBridge(2500);
  document.querySelector('#env').textContent =
    `${native ? '네이티브 브리지' : '네이티브 브리지 없음 (데스크톱: 개발용 릴레이 사용)'} · `
    + `UA에 "wv" ${navigator.userAgent.includes('; wv') ? '있음' : '없음'} · ${navigator.userAgent}`;
  document.querySelector('#rerun').addEventListener('click', () => location.reload());

  const pages = await checkPages();
  await checkDecode(pages);
  await checkMedia(pages);
  await checkLargePage(pages);
  setupVideo();
  renderSummary();
  document.body.dataset.done = 'true';
}

main();
