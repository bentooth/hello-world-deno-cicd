const port = parseInt(Deno.env.get("PORT") || "8000");

const handler = (req: Request): Response => {
  const url = new URL(req.url);

  switch (url.pathname) {
    case "/":
      return new Response(
        JSON.stringify({
          message: "Hello World from Deno 2!",
          timestamp: new Date().toISOString(),
          version: "1.0.0",
        }),
        {
          headers: { "content-type": "application/json" },
        },
      );

    case "/health":
      return new Response(
        JSON.stringify({
          status: "healthy",
          uptime: performance.now(),
        }),
        {
          headers: { "content-type": "application/json" },
        },
      );

    default:
      return new Response("Not Found", { status: 404 });
  }
};

console.log(`Server running on http://localhost:${port}/`);
Deno.serve({ port }, handler);
