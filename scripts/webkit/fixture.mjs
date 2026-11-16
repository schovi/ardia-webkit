import { createServer } from "node:http";

export const DOWNLOAD = "Ardia WebKit smoke download\n";
export const AD_PATH = "/fixture.ar/ads/banner.js";
export const titleOf = (path) => `Cobalt Violet ${path.replace(/^\//, "")}`;

export async function startFixture() {
  const hits = [];
  const refused = createServer();
  await new Promise((resolve, reject) => { refused.once("error", reject); refused.listen(0, "127.0.0.1", resolve); });
  const refusedOrigin = `http://127.0.0.1:${refused.address().port}`;
  await new Promise(resolve => refused.close(resolve));
  const server = createServer((request, response) => {
    const url = new URL(request.url, "http://localhost");
    hits.push(url.pathname);
    response.setHeader("Cache-Control", "no-store");
    if (url.pathname.startsWith("/auth")) {
      if (request.headers.authorization !== "Basic " + Buffer.from("fixture:correct").toString("base64")) {
        response.writeHead(401, {"WWW-Authenticate": `Basic realm="WebKit fixture ${url.pathname}"`, "Content-Type": "text/html"});
        return response.end("<title>Unauthorized</title><h1>401 Unauthorized</h1>");
      }
    }
    if (url.pathname === "/popup-auto") {
      response.setHeader("Content-Type", "text/html");
      return response.end('<title>Cobalt Violet popup-auto</title><script>setTimeout(()=>window.open("/automatic-child"),200)</script>');
    }
    if (url.pathname === "/loop") {
      response.setHeader("Content-Type", "text/html");
      return response.end('<title>Cobalt Violet loop</title><button onclick="while(true){}">Hang</button>');
    }
    if (url.pathname === "/favicon.ico") { response.writeHead(404); return response.end(); }
    if (url.pathname === AD_PATH || url.pathname === "/control.js") {
      response.setHeader("Content-Type", "application/javascript");
      return response.end("document.documentElement.dataset.control = 'loaded';");
    }
    if (url.pathname === "/slow-download") {
      const total = 8 * 1024 * 1024;
      const start = Number(/^bytes=(\d+)-/.exec(request.headers.range ?? "")?.[1] ?? 0);
      response.writeHead(start ? 206 : 200, {"Content-Disposition": 'attachment; filename="slow.bin"', "Content-Type":"application/octet-stream", "Accept-Ranges":"bytes", "Content-Length":total-start, ...(start ? {"Content-Range":`bytes ${start}-${total-1}/${total}`} : {})});
      let sent = start;
      const timer = setInterval(() => {
        const size = Math.min(32768, total-sent);
        response.write(Buffer.alloc(size, 42)); sent += size;
        if (sent === total) { clearInterval(timer); response.end(); }
      }, 25);
      response.on("close", () => clearInterval(timer));
      return;
    }
    if (url.pathname === "/suggest") {
      response.setHeader("Content-Type", "application/json");
      return response.end(JSON.stringify([url.searchParams.get("q"),["fixture suggestion"]]));
    }
    if (url.pathname === "/download") {
      response.setHeader("Content-Disposition", 'attachment; filename="smoke.txt"');
      response.setHeader("Content-Type", "application/octet-stream");
      return response.end(DOWNLOAD);
    }
    response.setHeader("Content-Type", "text/html; charset=utf-8");
    const title = titleOf(url.pathname);
    response.end(`<!doctype html><html><head><title>${title}</title></head><body><h1>${title}</h1><p>needle needle browser smoke</p><a id="next" href="/second">Next</a><a id="blank" href="/blank" target="_blank">Blank</a><button id="popup" onclick="window.open('/popup','smoke-popup','width=500,height=400')">Popup</button><a id="download" href="/download">Download</a></body></html>`);
  });
  await new Promise((resolve, reject) => { server.once("error", reject); server.listen(0, "127.0.0.1", resolve); });
  return {
    origin: `http://127.0.0.1:${server.address().port}`,
    hits,
    refusedOrigin,
    async close() { server.closeAllConnections(); await new Promise((resolve) => server.close(resolve)); },
  };
}
