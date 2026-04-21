const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json());

const dbConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT) || 6033,
  user: process.env.DB_USER || 'app_user',
  password: process.env.DB_PASSWORD || 'app_password',
  database: process.env.DB_NAME || 'ecommerce',
  ssl: { rejectUnauthorized: false }
};

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>ShopKel2 — E-Commerce</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f4f6fb; color: #222; }
        
        .header {
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 60%, #0f3460 100%);
          color: white;
          padding: 28px 48px;
          display: flex;
          align-items: center;
          gap: 18px;
          box-shadow: 0 4px 24px rgba(0,0,0,0.18);
        }
        .header-logo {
          font-size: 42px;
        }
        .header-text h1 {
          font-size: 28px;
          font-weight: 700;
          letter-spacing: 0.5px;
        }
        .header-text p {
          font-size: 13px;
          opacity: 0.6;
          margin-top: 3px;
          letter-spacing: 1px;
          text-transform: uppercase;
        }

        .container { max-width: 960px; margin: 36px auto; padding: 0 24px; }

        .card {
          background: white;
          border-radius: 14px;
          padding: 28px;
          margin-bottom: 24px;
          box-shadow: 0 2px 16px rgba(0,0,0,0.07);
        }
        .card h2 {
          font-size: 17px;
          font-weight: 700;
          margin-bottom: 20px;
          color: #1a1a2e;
          display: flex;
          align-items: center;
          gap: 8px;
        }

        .status-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
        .status-item {
          background: #f8f9fb;
          border-radius: 10px;
          padding: 18px;
          text-align: center;
          border: 1px solid #eef0f5;
        }
        .status-item .label { font-size: 12px; color: #999; margin-bottom: 8px; letter-spacing: 0.5px; text-transform: uppercase; }
        .status-item .dot { font-size: 28px; }
        .status-item .val { font-size: 13px; font-weight: 600; margin-top: 6px; color: #444; }

        .btn {
          background: linear-gradient(135deg, #0f3460, #16213e);
          color: white;
          border: none;
          padding: 10px 22px;
          border-radius: 8px;
          cursor: pointer;
          font-size: 14px;
          font-weight: 600;
          letter-spacing: 0.3px;
          transition: opacity 0.2s;
        }
        .btn:hover { opacity: 0.85; }

        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th {
          background: #f4f6fb;
          padding: 11px 14px;
          text-align: left;
          font-size: 12px;
          color: #888;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          font-weight: 600;
        }
        td { padding: 11px 14px; border-top: 1px solid #f0f2f7; font-size: 14px; }
        tr:hover td { background: #fafbff; }

        .form-row { display: flex; gap: 10px; flex-wrap: wrap; }
        .form-row input {
          flex: 1;
          min-width: 140px;
          padding: 10px 14px;
          border: 1.5px solid #e8eaf0;
          border-radius: 8px;
          font-size: 14px;
          outline: none;
          transition: border 0.2s;
        }
        .form-row input:focus { border-color: #0f3460; }

        #result { margin-top: 14px; font-size: 13px; }

        .infra {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
        }
        .infra-item {
          background: #f8f9fb;
          border-radius: 8px;
          padding: 13px 16px;
          font-size: 13px;
          color: #555;
          border: 1px solid #eef0f5;
        }
        .infra-item strong { color: #1a1a2e; display: block; margin-bottom: 3px; }
      </style>
    </head>
    <body>
      <div class="header">
        <div class="header-logo">🛒</div>
        <div class="header-text">
          <h1>ShopKel2</h1>
          <p>E-Commerce · DevOps Mini Project · Kelompok 2</p>
        </div>
      </div>

      <div class="container">

        <div class="card">
          <h2>📊 System Status</h2>
          <div class="status-grid">
            <div class="status-item">
              <div class="label">App Server</div>
              <div class="dot">🟢</div>
              <div class="val">Running</div>
            </div>
            <div class="status-item">
              <div class="label">ProxySQL</div>
              <div class="dot">🟢</div>
              <div class="val">Port 6033</div>
            </div>
            <div class="status-item">
              <div class="label">DB Connection</div>
              <div class="dot" id="dbStatus">⏳</div>
              <div class="val" id="dbLabel">Checking...</div>
            </div>
          </div>
        </div>

        <div class="card">
          <h2>📦 Products</h2>
          <button class="btn" onclick="loadProducts()">Load Products</button>
          <div style="overflow-x:auto">
            <table id="productTable">
              <thead><tr><th>ID</th><th>Name</th><th>Price</th><th>Stock</th></tr></thead>
              <tbody id="productBody">
                <tr><td colspan="4" style="color:#bbb;text-align:center;padding:24px">Click "Load Products" to fetch data</td></tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="card">
          <h2>➕ Add Product</h2>
          <div class="form-row">
            <input id="pName" placeholder="Product name" />
            <input id="pPrice" placeholder="Price (Rp)" type="number" />
            <input id="pStock" placeholder="Stock" type="number" />
            <button class="btn" onclick="addProduct()">Add</button>
          </div>
          <div id="result"></div>
        </div>

        <div class="card">
          <h2>🏗️ Infrastructure</h2>
          <div class="infra">
            <div class="infra-item">
              <strong>🖥️ VM1 — App + ProxySQL</strong>
              10.0.1.10 · Public: 4.193.169.181
            </div>
            <div class="infra-item">
              <strong>🗄️ VM2 — Master DB</strong>
              10.0.1.20 · Write traffic
            </div>
            <div class="infra-item">
              <strong>🗄️ VM3 — Slave DB</strong>
              10.0.1.21 · Read traffic
            </div>
            <div class="infra-item">
              <strong>🐳 Containerized</strong>
              Docker · Docker Scout security scan
            </div>
          </div>
        </div>

      </div>

      <script>
        fetch('/health').then(r=>r.json()).then(d=>{
          document.getElementById('dbStatus').innerText = d.db === 'ok' ? '🟢' : '🔴';
          document.getElementById('dbLabel').innerText = d.db === 'ok' ? 'Connected' : 'Error';
        }).catch(()=>{
          document.getElementById('dbStatus').innerText = '🔴';
          document.getElementById('dbLabel').innerText = 'Error';
        });

        function loadProducts() {
          fetch('/products').then(r=>r.json()).then(d=>{
            const tbody = document.getElementById('productBody');
            if (!d.data || d.data.length === 0) {
              tbody.innerHTML = '<tr><td colspan="4" style="color:#bbb;text-align:center;padding:24px">No products found</td></tr>';
              return;
            }
            tbody.innerHTML = d.data.map(p =>
              '<tr><td>'+p.id+'</td><td>'+p.name+'</td><td>Rp '+Number(p.price).toLocaleString('id-ID')+'</td><td>'+p.stock+'</td></tr>'
            ).join('');
          });
        }

        function addProduct() {
          const name = document.getElementById('pName').value;
          const price = document.getElementById('pPrice').value;
          const stock = document.getElementById('pStock').value;
          fetch('/products', {
            method: 'POST',
            headers: {'Content-Type':'application/json'},
            body: JSON.stringify({name, price, stock})
          }).then(r=>r.json()).then(d=>{
            document.getElementById('result').innerHTML = d.success
              ? '<span style="color:#2d7a3a">✅ Product added! ID: '+d.insertedId+'</span>'
              : '<span style="color:#c62828">❌ Error: '+d.error+'</span>';
            if (d.success) loadProducts();
          });
        }
      </script>
    </body>
    </html>
  `);
});

app.get('/health', async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    await conn.execute('SELECT 1');
    await conn.end();
    res.json({ status: 'ok', db: 'ok', proxysql: '127.0.0.1:6033' });
  } catch (err) {
    res.json({ status: 'ok', db: 'error', error: err.message });
  }
});

app.get('/products', async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.execute('SELECT * FROM products');
    await conn.end();
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/products', async (req, res) => {
  const { name, price, stock } = req.body;
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [result] = await conn.execute(
      'INSERT INTO products (name, price, stock) VALUES (?, ?, ?)',
      [name, price, stock]
    );
    await conn.end();
    res.json({ success: true, insertedId: result.insertId });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`ShopKel2 running on port ${PORT}`);
});
