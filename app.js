// GIF-veggen – plukker tilfeldige GIF-er i nettleseren. Ingen server, ingen Azure.
// Rediger CONFIG under for å endre oppførsel.

const CONFIG = {
  // Hvilken liste som brukes. Kan overstyres i URL-en: ?liste=dax  -> dax.csv
  defaultList: "gifs",
  // Hvor ofte nye GIF-er plukkes (sekunder). Lista hentes på nytt hver gang,
  // så endringer i CSV-en dukker opp uten at noen må laste siden på nytt.
  refreshSeconds: 200,
  // Antall GIF-er som vises samtidig.
  gifCount: 2,
  // Første GIF hentes fra den nyeste halvdelen av lista (nederst i CSV-en).
  favorNewest: true,
  // Dad joke fra icanhazdadjoke.com. Sett til false for å skru av.
  dadJoke: true,
  // Nedtelling. Sett til null for å skru av. Skjules automatisk når datoen har passert.
  countdown: { label: "Julebord", date: "2026-12-04T16:00:00" },
};

// --- Ren logikk (testbar uten nettleser) -----------------------------------

// Leser CSV med ; som skilletegn. Støtter "sitater" og "" inne i sitater,
// slik Excel lagrer dem.
function parseCsv(text) {
  text = text.replace(/^\uFEFF/, "");
  const rows = [];
  let row = [], field = "", inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ";") { row.push(field); field = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(field); rows.push(row); row = []; field = "";
    } else field += c;
  }
  if (field !== "" || row.length) { row.push(field); rows.push(row); }

  const [header, ...data] = rows.filter(r => r.some(f => f.trim() !== ""));
  if (!header) return [];
  const h = header.map(s => s.trim().toLowerCase());
  const iText = h.indexOf("header"), iGif = h.indexOf("gif");
  if (iText < 0 || iGif < 0) throw new Error("CSV mangler kolonnene Header og Gif");
  return data
    .map(r => ({ header: (r[iText] || "").trim(), gif: (r[iGif] || "").trim() }))
    .filter(g => g.gif);
}

// Velger inntil `count` ulike indekser. Første kan hentes fra nyeste halvdel.
function pickIndexes(n, count, favorNewest, rnd = Math.random) {
  count = Math.min(count, n);
  const picked = [];
  if (count === 0) return picked;
  const start = favorNewest ? Math.floor(n / 2) : 0;
  picked.push(start + Math.floor(rnd() * (n - start)));
  const rest = [...Array(n).keys()].filter(i => i !== picked[0]);
  while (picked.length < count) {
    const j = Math.floor(rnd() * rest.length);
    picked.push(rest.splice(j, 1)[0]);
  }
  return picked;
}

function countdownText(label, target, now = new Date()) {
  const ms = target - now;
  if (!(ms > 0)) return null;
  const days = Math.floor(ms / 86400000);
  const hours = Math.floor((ms % 86400000) / 3600000);
  return `Det er nå bare ${days} ${days === 1 ? "dag" : "dager"} og ${hours} ${hours === 1 ? "time" : "timer"} til ${label}!`;
}

function listNameFromUrl(search, fallback) {
  const name = new URLSearchParams(search).get("liste") || fallback;
  return /^[a-z0-9_-]+$/i.test(name) ? name : fallback; // bare trygge filnavn
}

// --- Nettleserdelen ---------------------------------------------------------

async function render() {
  const listName = listNameFromUrl(location.search, CONFIG.defaultList);
  const gifsEl = document.getElementById("gifs");
  try {
    const res = await fetch(`${listName}.csv`, { cache: "no-store" });
    if (!res.ok) throw new Error(`Fant ikke ${listName}.csv (${res.status})`);
    const gifs = parseCsv(await res.text());
    const cards = pickIndexes(gifs.length, CONFIG.gifCount, CONFIG.favorNewest).map(i => {
      const fig = document.createElement("figure");
      const h1 = document.createElement("h1");
      h1.textContent = gifs[i].header; // textContent = ingen HTML-injeksjon
      const img = document.createElement("img");
      img.src = gifs[i].gif;
      img.alt = gifs[i].header;
      img.onerror = () => { img.replaceWith(Object.assign(document.createElement("p"),
        { className: "broken", textContent: `(GIF-en finnes ikke lenger: ${gifs[i].gif})` })); };
      fig.append(h1, img);
      return fig;
    });
    gifsEl.replaceChildren(...cards);
  } catch (err) {
    gifsEl.replaceChildren(Object.assign(document.createElement("p"),
      { className: "broken", textContent: String(err.message || err) }));
  }

  const jokeEl = document.getElementById("joke");
  if (CONFIG.dadJoke) {
    try {
      const res = await fetch("https://icanhazdadjoke.com/", { headers: { Accept: "application/json" } });
      jokeEl.textContent = (await res.json()).joke;
    } catch { jokeEl.textContent = ""; }
  }

  const cdEl = document.getElementById("countdown");
  cdEl.textContent = CONFIG.countdown
    ? countdownText(CONFIG.countdown.label, new Date(CONFIG.countdown.date)) || ""
    : "";
}

if (typeof document !== "undefined") {
  render();
  setInterval(render, CONFIG.refreshSeconds * 1000);
}

if (typeof module !== "undefined") {
  module.exports = { parseCsv, pickIndexes, countdownText, listNameFromUrl };
}
