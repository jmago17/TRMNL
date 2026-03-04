interface Env {
  IMAGES: R2Bucket;
  SLIDESHOW_STATE: KVNamespace;
  AUTH_SECRET: string;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "PUT, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
};

const BASE_URL = "https://trmnl-image-worker.pttpk8wmgy.workers.dev";
const MAX_BYTES = 500 * 1024; // 500 KB — real 800×480 1-bit BMPs are ~47 KB

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // GET /slideshow?type=portrait|landscape&count=N — cycles through uploaded photos
    if (request.method === "GET" && url.pathname === "/slideshow") {
      const count = parseInt(url.searchParams.get("count") ?? "0", 10);
      if (count < 1 || count > 5) {
        return Response.json({ error: "count must be between 1 and 5" }, { status: 400 });
      }

      const type = url.searchParams.get("type") ?? "landscape";
      if (type !== "portrait" && type !== "landscape") {
        return Response.json({ error: "type must be portrait or landscape" }, { status: 400 });
      }

      const kvKey = `${type}_index`;
      const indexStr = await env.SLIDESHOW_STATE.get(kvKey) ?? "0";
      const currentIndex = parseInt(indexStr, 10) % count;
      const nextIndex = (currentIndex + 1) % count;
      await env.SLIDESHOW_STATE.put(kvKey, String(nextIndex));

      const imageUrl = `${BASE_URL}/${type}-${currentIndex + 1}.jpg`;
      return Response.json({ image_url: imageUrl });
    }

    // GET /{key} — serve image from R2
    if (request.method === "GET") {
      const key = url.pathname.slice(1);
      if (!key || key.includes("..")) {
        return new Response("Not found", { status: 404 });
      }

      const object = await env.IMAGES.get(key);
      if (!object) {
        return new Response("Not found", { status: 404 });
      }

      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("Cache-Control", "public, max-age=60");
      return new Response(object.body, { headers });
    }

    // PUT /{key} — upload image to R2 (auth required)
    if (request.method === "PUT") {
      const auth = request.headers.get("Authorization");
      if (auth !== `Bearer ${env.AUTH_SECRET}`) {
        return Response.json({ error: "Unauthorized" }, { status: 401, headers: CORS_HEADERS });
      }

      const key = url.pathname.slice(1);
      if (!key || key.includes("..")) {
        return Response.json({ error: "Invalid key" }, { status: 400, headers: CORS_HEADERS });
      }

      const contentLength = parseInt(request.headers.get("Content-Length") ?? "0", 10);
      if (contentLength > MAX_BYTES) {
        return Response.json({ error: "Payload too large" }, { status: 413, headers: CORS_HEADERS });
      }

      const contentType = request.headers.get("Content-Type") || "image/bmp";
      const body = await request.arrayBuffer();

      if (body.byteLength > MAX_BYTES) {
        return Response.json({ error: "Payload too large" }, { status: 413, headers: CORS_HEADERS });
      }

      await env.IMAGES.put(key, body, { httpMetadata: { contentType } });

      return Response.json({ url: `${BASE_URL}/${key}` }, { status: 200, headers: CORS_HEADERS });
    }

    return Response.json({ error: "Method not allowed" }, { status: 405, headers: CORS_HEADERS });
  },
} satisfies ExportedHandler<Env>;
