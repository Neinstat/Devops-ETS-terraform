const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
app.use(express.json());

const dbConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT) || 6033,
  user: process.env.DB_USER || 'kelompok2user',
  password: process.env.DB_PASSWORD || 'Kelompok2devops!',
  database: process.env.DB_NAME || 'ecommerce_kel2',
};

// Halaman utama UI
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>E-Commerce Kelompok 2</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f0f2f5; }
        .header { background: #2d3e50; color: white; padding: 20px 40px; }
        .header h1 { font-size: 24px; }
        .header p { font-size: 13px; opacity: 0.7; margin-top: 4px; }
        .container { max-width: 900px; margin: 30px auto; padding: 0 20px; }
        .card { background: white; border-radius: 8px; padding: 24px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .card h2 { font-size: 18px; margin-bottom: 16px; color: #2d3e50; }
        .status-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
        .status-item { background: #f8f9fa; border-radius: 6px; padding: 16px; text-align: center; }
        .status-item .label { font-size: 12px; color: #888; margin-bottom: 6px; }
        .status-item .value { font-size: 20px; font-weight: bold; color: #2d3e50; }
        .btn { background: #2d3e50; color: white; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; font-size: 14px; }
        .btn:hover { background: #3d5166; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #f8f9fa; padding: 10px 12px; text-align: left; font-size: 13px; color: #555; }
        td { padding: 10px 12px; border-top: 1px solid #f0f0f0; font-size: 14px; }
        .badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 12px; }
        .badge-ok { background: #e6f4ea; color: #2d7a3a; }
        .badge-err { background: #fce8e6; color: #c62828; }
        #result { margin-top: 12px; font-size: 13px; color: #555; }
        .form-row { display: flex; gap: 10px; flex-wrap: wrap; }
        .form-row input { flex: 1; min-width: 140px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 6px; font-size: 14px; }
        .infra { font-size: 13px; color: #555; line-height: 1.8; }
        .infra span { font-weight: bold; color: #2d3e50; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🛒 E-Commerce App — Kelompok 2</h1>
        <p>DevOps Mini Project · Institut Teknologi Sepuluh Nopember</p>
      </div>
      <div class="container">

        <div class="card">
          <h2>📊 System Status</h2>
          <div class="status-grid">
            <div class="status-item">
              <div class="label">App Server</div>
              <div class="value">🟢</div>
              <div class="label" style="margin-top:4px">Running</div>
            </div>
            <div class="status-item">
              <div class="label">ProxySQL</div>
              <div class="value">🟢</div>
              <div class="label" style="margin-top:4px">Port 6033</div>
            </div>
            <div class="status-item">
              <div class="label">DB Connection</div>
              <div class="value" id="dbStatus">⏳</div>
              <div class="label" style="margin-top:4px" id="dbLabel">Checking...</div>
            </div>
          </div>
        </div>

        <div class="card">
          <h2>📦 Products</h2>
          <button class="btn" onclick="loadProducts()">Load Products</button>
          <div style="margin-top:16px; overflow-x:auto;">
            <table id="productTable">
              <thead><tr><th>ID</th><th>Name</th><th>Price</th><th>Stock</th></tr></thead>
              <tbody id="productBody"><tr><td colspan="4" style="color:#aaa;text-align:center;padding:20px">Click "Load Products" to fetch data</td></tr></tbody>
            </table>
          </div>
        </div>

        <div class="card">
          <h2>➕ Add Product</h2>
          <div class="form-row">
            <input id="pName" placeholder="Product name" />
            <input id="pPrice" placeholder="Price" type="number" />
            <input id="pStock" placeholder="Stock" type="number" />
            <button class="btn" onclick="addProduct()">Add</button>
          </div>
          <div id="result"></div>
        </div>

        <div class="card">
          <h2>🏗️ Infrastructure</h2>
          <div class="infra">
            <div>🖥️ <span>VM1 (App + ProxySQL)</span> — 10.0.1.10 | Public: 4.193.169.181</div>
            <div>🗄️ <span>VM2 (Master DB)</span> — 10.0.1.20 | Write traffic</div>
            <div>🗄️ <span>VM3 (Slave DB)</span> — 10.0.1.21 | Read traffic</div>
            <div>🐳 <span>Containerized</span> — Docker + Docker Scout security scan</div>
          </div>
        </div>

      </div>
      <script>
        // Check DB status on load
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
              tbody.innerHTML = '<tr><td colspan="4" style="color:#aaa;text-align:center;padding:20px">No products found</td></tr>';
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
              ? '<span style="color:green">✅ Product added! ID: '+d.insertedId+'</span>'
              : '<span style="color:red">❌ Error: '+d.error+'</span>';
            if (d.success) loadProducts();
          });
        }
      </script>
    </body>
    </html>
  `);
});

// Health check endpoint
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

// GET semua produk
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

// POST tambah produk
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
  console.log(`App Kelompok 2 running on port ${PORT}`);
});