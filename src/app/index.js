const express = require("express");
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");
const { Connection, Request } = require("tedious");

const app = express();
const PORT = process.env.PORT || 8080;

const credential = new DefaultAzureCredential();

const KV_URL = process.env.AZURE_KEYVAULT_URL || "";
const SQL_SERVER = process.env.AZURE_SQL_SERVER || "";
const SQL_DATABASE = process.env.AZURE_SQL_DATABASE || "";

app.get("/", (req, res) => {
  res.json({
    status: "running",
    service: "azure-dev-harness-hello",
    endpoints: ["/health", "/secret", "/sql"],
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "healthy", timestamp: new Date().toISOString() });
});

app.get("/secret", async (req, res) => {
  if (!KV_URL) {
    return res.status(503).json({ error: "AZURE_KEYVAULT_URL not set" });
  }
  try {
    const client = new SecretClient(KV_URL, credential);
    const secret = await client.getSecret("hello-secret");
    res.json({
      status: "ok",
      secretName: "hello-secret",
      value: secret.value,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/sql", (req, res) => {
  if (!SQL_SERVER || !SQL_DATABASE) {
    return res.status(503).json({ error: "AZURE_SQL_SERVER or AZURE_SQL_DATABASE not set" });
  }

  const config = {
    server: SQL_SERVER,
    authentication: {
      type: "azure-active-directory-default",
      options: {},
    },
    options: {
      database: SQL_DATABASE,
      encrypt: true,
      port: 1433,
    },
  };

  const connection = new Connection(config);
  let rows = [];

  connection.on("connect", (err) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    const request = new Request(
      "SELECT 'hello-from-sql' AS message, GETDATE() AS server_time",
      (err, rowCount) => {
        connection.close();
        if (err) {
          return res.status(500).json({ error: err.message });
        }
        res.json({ status: "ok", rowCount, rows });
      }
    );
    request.on("row", (columns) => {
      const row = {};
      columns.forEach((col) => { row[col.metadata.colName] = col.value; });
      rows.push(row);
    });
    connection.execSql(request);
  });

  connection.connect();
});

app.listen(PORT, () => {
  console.log(`Listening on port ${PORT}`);
});
