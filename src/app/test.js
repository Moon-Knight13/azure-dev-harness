const http = require("http");

const PORT = process.env.PORT || 8080;
const BASE = `http://localhost:${PORT}`;

async function get(path) {
  return new Promise((resolve, reject) => {
    http.get(`${BASE}${path}`, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    }).on("error", reject);
  });
}

async function main() {
  let failures = 0;

  const root = await get("/");
  if (root.status === 200 && root.body.status === "running") {
    console.log("PASS: / returns running");
  } else {
    console.log("FAIL: /", root);
    failures++;
  }

  const health = await get("/health");
  if (health.status === 200 && health.body.status === "healthy") {
    console.log("PASS: /health returns healthy");
  } else {
    console.log("FAIL: /health", health);
    failures++;
  }

  const secret = await get("/secret");
  if (secret.body.error === "AZURE_KEYVAULT_URL not set" || secret.body.status === "ok") {
    console.log("PASS: /secret handles missing config gracefully");
  } else {
    console.log("FAIL: /secret", secret);
    failures++;
  }

  const sql = await get("/sql");
  if (sql.body.error || sql.body.status === "ok") {
    console.log("PASS: /sql handles missing config gracefully");
  } else {
    console.log("FAIL: /sql", sql);
    failures++;
  }

  process.exit(failures > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Test failed to connect — is the app running?", err.message);
  process.exit(1);
});
