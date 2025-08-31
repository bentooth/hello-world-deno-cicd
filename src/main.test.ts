import { assertEquals } from "@std/assert";

Deno.test("API Health Check", async () => {
  // Start server for testing
  const ac = new AbortController();
  const server = Deno.serve(
    { port: 8000, signal: ac.signal, onListen: () => {} },
    (req: Request) => {
      const url = new URL(req.url);
      if (url.pathname === "/health") {
        return new Response(JSON.stringify({ 
          status: "healthy",
          uptime: performance.now()
        }), {
          headers: { "content-type": "application/json" },
        });
      }
      return new Response("Not Found", { status: 404 });
    }
  );
  
  // Give server time to start
  await new Promise(resolve => setTimeout(resolve, 100));
  
  // Test the endpoint
  const response = await fetch("http://localhost:8000/health");
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.status, "healthy");
  
  // Cleanup
  ac.abort();
  await server.finished;
});