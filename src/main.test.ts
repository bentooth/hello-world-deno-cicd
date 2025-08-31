import { assertEquals } from "jsr:@std/assert";

Deno.test("API Health Check", async () => {
  const response = await fetch("http://localhost:8000/health");
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.status, "healthy");
});