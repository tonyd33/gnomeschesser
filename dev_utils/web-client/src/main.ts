import { Router } from "@oak/oak/router";
import { Application } from "jsr:@oak/oak/application";

const MOVES_ENDPOINT = Deno.env.get("MOVES_ENDPOINT") ||
  "http://localhost:8000/move";

const router = new Router();
router.post(
  "/api/move",
  async (ctx) => {
    await ctx.request.body.blob()
      .then((body) =>
        fetch(MOVES_ENDPOINT, {
          method: "POST",
          body,
          headers: ctx.request.headers,
        })
      )
      .then((res) => {
        ctx.response.headers = res.headers;
        ctx.response.body = res.body;
        ctx.response.status = res.status;
      })
      .catch(() => {
        ctx.response.status = 400;
      });
  },
);

const app = new Application();
app.use(router.routes());
app.use(router.allowedMethods());

app.use(
  (ctx) =>
    ctx.send({
      root: "public",
      brotli: false,
      gzip: false,
    }),
);

app.listen({ port: 3000 });
