const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'hostel_db',
  dateStrings: true,
});

// Whitelist of tables and their columns; nothing else can reach the SQL text.
const TABLES = {
  hostel: { pk: 'hostel_id', cols: ['hostel_name', 'hostel_type', 'warden_name', 'warden_phone'] },
  room: { pk: 'room_id', cols: ['hostel_id', 'room_no', 'room_type', 'capacity', 'monthly_rent'] },
  student: { pk: 'student_id', cols: ['roll_no', 'full_name', 'gender', 'department', 'year_of_study', 'phone', 'email'] },
  allocation: { pk: 'allocation_id', cols: ['student_id', 'room_id', 'check_in', 'check_out', 'status'] },
  service_request: { pk: 'request_id', cols: ['student_id', 'service_type', 'description', 'request_date', 'status'] },
  fee_payment: { pk: 'payment_id', cols: ['student_id', 'amount', 'payment_date', 'payment_mode', 'fee_month'] },
};

const REPORTS = {
  'Students and their rooms (JOIN)': `
    SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, a.check_in, a.status
    FROM allocation a JOIN student s ON s.student_id = a.student_id
    JOIN room r ON r.room_id = a.room_id JOIN hostel h ON h.hostel_id = r.hostel_id`,
  'Room occupancy and free beds (COUNT)': `
    SELECT h.hostel_name, r.room_no, r.capacity, COUNT(a.allocation_id) AS occupied,
           r.capacity - COUNT(a.allocation_id) AS free_beds
    FROM room r JOIN hostel h ON h.hostel_id = r.hostel_id
    LEFT JOIN allocation a ON a.room_id = r.room_id AND a.status = 'Active'
    GROUP BY r.room_id, h.hostel_name, r.room_no, r.capacity`,
  'Total fees paid per student (SUM)': `
    SELECT s.roll_no, s.full_name, COUNT(f.payment_id) AS payments, SUM(f.amount) AS total_paid
    FROM student s LEFT JOIN fee_payment f ON f.student_id = s.student_id
    GROUP BY s.student_id, s.roll_no, s.full_name`,
  'Pending service requests (JOIN)': `
    SELECT sr.request_id, s.full_name, sr.service_type, sr.description, sr.request_date, sr.status
    FROM service_request sr JOIN student s ON s.student_id = sr.student_id
    WHERE sr.status <> 'Resolved'`,
  'Fee collection by month (SUM)': `
    SELECT fee_month, SUM(amount) AS collected FROM fee_payment GROUP BY fee_month`,
};

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const table = (req, res, next) => {
  req.t = TABLES[req.params.table];
  if (!req.t) return res.status(404).json({ error: 'Unknown table' });
  next();
};
const wrap = (fn) => (req, res) => fn(req, res).catch((e) => res.status(400).json({ error: e.sqlMessage || e.message || `Database error: ${e.code}` }));

app.get('/api/meta', (req, res) => res.json({ tables: TABLES, reports: Object.keys(REPORTS) }));

app.get('/api/report/:i', wrap(async (req, res) => {
  const sql = Object.values(REPORTS)[Number(req.params.i)];
  if (!sql) return res.status(404).json({ error: 'Unknown report' });
  const [rows] = await pool.query(sql);
  res.json({ rows, sql: sql.trim() });
}));

app.get('/api/:table', table, wrap(async (req, res) => {
  const [rows] = await pool.query(`SELECT * FROM ${req.params.table} ORDER BY ${req.t.pk}`);
  res.json({ rows });
}));

app.post('/api/:table', table, wrap(async (req, res) => {
  const cols = req.t.cols;
  const values = cols.map((c) => (req.body[c] === '' || req.body[c] === undefined ? null : req.body[c]));
  const [r] = await pool.query(
    `INSERT INTO ${req.params.table} (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`, values);
  res.json({ id: r.insertId });
}));

app.delete('/api/:table/:id', table, wrap(async (req, res) => {
  const [r] = await pool.query(`DELETE FROM ${req.params.table} WHERE ${req.t.pk} = ?`, [req.params.id]);
  res.json({ deleted: r.affectedRows });
}));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Hostel Management UI running at http://localhost:${port}`));
