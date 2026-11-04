// Kjør: node test.js
const assert = require("assert");
const fs = require("fs");
const { parseCsv, pickIndexes, countdownText, listNameFromUrl } = require("./app.js");

// CSV: ekte filer + Excel-sitater
for (const f of ["gifs.csv", "dax.csv"]) {
  const g = parseCsv(fs.readFileSync(f, "utf8"));
  assert(g.length > 0 && g.every(x => x.gif.startsWith("http")), f);
  console.log(`${f}: ${g.length} GIF-er, f.eks. «${g[g.length - 1].header}»`);
}
const q = parseCsv('Header;Gif\r\n"Når en kollega gjør noe ""lurt""";http://x/a.gif\r\n\r\n');
assert.deepStrictEqual(q, [{ header: 'Når en kollega gjør noe "lurt"', gif: "http://x/a.gif" }]);
assert(parseCsv("Header;Gif\nÆØÅ;x").at(0).header === "ÆØÅ");

// Plukking: alltid ulike, første fra nyeste halvdel, tåler små lister
for (let k = 0; k < 10000; k++) {
  const p = pickIndexes(45, 2, true);
  assert(p.length === 2 && p[0] !== p[1] && p[0] >= 22 && p[0] < 45 && p[1] >= 0 && p[1] < 45);
}
assert.deepStrictEqual(pickIndexes(1, 2, true), [0]); // gamle skriptet hang her
assert.deepStrictEqual(pickIndexes(0, 2, true), []);

// Nedtelling
assert.strictEqual(countdownText("Julebord", new Date("2026-12-04T16:00:00"), new Date("2026-12-03T15:00:00")),
  "Det er nå bare 1 dag og 1 time til Julebord!");
assert.strictEqual(countdownText("Julebord", new Date("2019-12-06"), new Date()), null); // passert = skjult

// ?liste= kan ikke brukes til å hente vilkårlige filer
assert.strictEqual(listNameFromUrl("?liste=dax", "gifs"), "dax");
assert.strictEqual(listNameFromUrl("?liste=../../x", "gifs"), "gifs");

console.log("Alle tester OK");
