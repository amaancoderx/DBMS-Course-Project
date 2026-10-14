const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

const DB_NAME = process.env.DB_NAME || 'hostel_db';

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: DB_NAME,
  dateStrings: true,
});

// Tables the Records tab can touch. Table and column names only ever come
// from this list; values always go in as ? parameters.
const TABLES = {
  department: { pk: 'dept_id', cols: ['dept_code', 'dept_name'] },
  staff: { pk: 'staff_id', cols: ['full_name', 'designation', 'phone'] },
  hostel: { pk: 'hostel_id', cols: ['hostel_name', 'hostel_type', 'warden_id'] },
  room: { pk: 'room_id', cols: ['hostel_id', 'room_no', 'room_type', 'capacity', 'monthly_rent'] },
  student: { pk: 'student_id', cols: ['roll_no', 'full_name', 'gender', 'dept_id', 'year_of_study', 'phone', 'email'] },
  allocation: { pk: 'allocation_id', cols: ['student_id', 'room_id', 'check_in', 'check_out', 'status'] },
  service_type: { pk: 'service_type_id', cols: ['type_name', 'target_days'] },
  service_request: { pk: 'request_id', cols: ['student_id', 'service_type_id', 'description', 'request_date', 'status', 'resolved_on'] },
  request_update: { pk: 'update_id', cols: ['request_id', 'staff_id', 'new_status', 'remarks'] },
  fee_payment: { pk: 'payment_id', cols: ['student_id', 'fee_month', 'amount', 'payment_date', 'payment_mode'] },
};

// Which service types each trade works on.
const TRADE = {
  Electrician: ['Electrical'],
  Plumber: ['Plumbing'],
  Housekeeping: ['Housekeeping', 'Laundry'],
  'Network Technician': ['Internet'],
  'Mess Supervisor': ['Mess'],
};

const QUERIES = [
  ['Q1', 'Occupancy and free beds in every room', `SELECT hostel_name, room_no, room_type, capacity, occupied, free_beds
FROM v_room_occupancy
ORDER BY hostel_name, room_no`],
  ['Q2', "Rooms with a free bed in girls' hostels", `SELECT hostel_name, room_no, room_type, free_beds, monthly_rent
FROM v_room_occupancy
WHERE hostel_type = 'Girls' AND free_beds > 0
ORDER BY monthly_rent`],
  ['Q3', 'Who stays where', `SELECT s.roll_no, s.full_name, d.dept_code, h.hostel_name, r.room_no, a.check_in
FROM allocation a
JOIN student s    ON s.student_id = a.student_id
JOIN department d ON d.dept_id = s.dept_id
JOIN room r       ON r.room_id = a.room_id
JOIN hostel h     ON h.hostel_id = r.hostel_id
WHERE a.status = 'Active'
ORDER BY h.hostel_name, r.room_no`],
  ['Q4', 'Open service requests', `SELECT request_id, full_name, hostel_name, room_no, type_name, request_date, status
FROM v_open_requests
ORDER BY request_date`],
  ['Q5', 'History of every request', `SELECT sr.request_id, s.full_name, st.type_name, ru.new_status,
       f.full_name AS staff, ru.remarks, ru.updated_on
FROM service_request sr
JOIN student s       ON s.student_id = sr.student_id
JOIN service_type st ON st.service_type_id = sr.service_type_id
JOIN request_update ru ON ru.request_id = sr.request_id
JOIN staff f         ON f.staff_id = ru.staff_id
ORDER BY sr.request_id, ru.updated_on`],
  ['Q6', 'Residents who have not paid rent for October 2026', `SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, r.monthly_rent AS due
FROM allocation a
JOIN student s ON s.student_id = a.student_id
JOIN room r    ON r.room_id = a.room_id
JOIN hostel h  ON h.hostel_id = r.hostel_id
WHERE a.status = 'Active'
  AND NOT EXISTS (SELECT 1 FROM fee_payment f
                  WHERE f.student_id = a.student_id AND f.fee_month = '2026-10')`],
  ['Q7', 'Rent collected per hostel per month', `SELECT h.hostel_name, f.fee_month, COUNT(*) AS payments, SUM(f.amount) AS collected
FROM fee_payment f
JOIN allocation a ON a.student_id = f.student_id AND a.status = 'Active'
JOIN room r       ON r.room_id = a.room_id
JOIN hostel h     ON h.hostel_id = r.hostel_id
GROUP BY h.hostel_name, f.fee_month
ORDER BY f.fee_month, h.hostel_name`],
  ['Q8', 'Resolved requests per service type against the target', `SELECT st.type_name, st.target_days, COUNT(*) AS resolved,
       AVG(DATEDIFF(sr.resolved_on, sr.request_date)) AS avg_days
FROM service_request sr
JOIN service_type st ON st.service_type_id = sr.service_type_id
WHERE sr.status = 'Resolved'
GROUP BY st.service_type_id, st.type_name, st.target_days`],
  ['Q9', 'Hostel residents per department (at least two)', `SELECT d.dept_name, COUNT(*) AS residents
FROM allocation a
JOIN student s    ON s.student_id = a.student_id
JOIN department d ON d.dept_id = s.dept_id
WHERE a.status = 'Active'
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(*) >= 2`],
];

// Every write the UI sends, shown in the Database tab.
const activity = [];

async function write(sql, params, conn = pool) {
  const text = mysql.format(sql, params);
  try {
    const [r] = await conn.query(sql, params);
    activity.push({ at: new Date().toISOString(), sql: text, ok: true, rows: r.affectedRows });
    return { r, text };
  } catch (e) {
    activity.push({ at: new Date().toISOString(), sql: text, ok: false, error: e.sqlMessage || e.message });
    e.sqlText = text;
    throw e;
  }
}

const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const wrap = (fn) => (req, res) =>
  fn(req, res).catch((e) => {
    const unreachable = ['ECONNREFUSED', 'ER_ACCESS_DENIED_ERROR', 'ER_BAD_DB_ERROR', 'ETIMEDOUT'].includes(e.code);
    res.status(unreachable ? 503 : 400).json({
      error: unreachable
        ? `Cannot reach MySQL (${e.code}). Check that the server is running, the database was created with hostel_management_system.sql, and DB_PASSWORD is set.`
        : e.sqlMessage || e.message,
      sql: e.sqlText,
    });
  });

app.get('/api/status', wrap(async (req, res) => {
  const [[v]] = await pool.query('SELECT VERSION() AS version');
  res.json({ version: v.version, database: DB_NAME });
}));

app.get('/api/people', wrap(async (req, res) => {
  const [students] = await pool.query('SELECT student_id, roll_no, full_name FROM student ORDER BY roll_no');
  const [staff] = await pool.query('SELECT staff_id, full_name, designation FROM staff ORDER BY staff_id');
  res.json({ students, staff });
}));

// ---------- Student screens ----------

app.get('/api/student/:id', wrap(async (req, res) => {
  const id = req.params.id;
  const [[profile]] = await pool.query(
    `SELECT s.*, d.dept_name FROM student s JOIN department d ON d.dept_id = s.dept_id WHERE s.student_id = ?`, [id]);
  const [[room]] = await pool.query(
    `SELECT a.allocation_id, a.check_in, r.room_id, r.room_no, r.room_type, r.capacity, r.monthly_rent,
            h.hostel_name, w.full_name AS warden, w.phone AS warden_phone
     FROM allocation a JOIN room r ON r.room_id = a.room_id JOIN hostel h ON h.hostel_id = r.hostel_id
     JOIN staff w ON w.staff_id = h.warden_id
     WHERE a.student_id = ? AND a.status = 'Active'`, [id]);
  let roommates = [];
  if (room) {
    [roommates] = await pool.query(
      `SELECT s.roll_no, s.full_name, d.dept_code, s.year_of_study FROM allocation a
       JOIN student s ON s.student_id = a.student_id JOIN department d ON d.dept_id = s.dept_id
       WHERE a.room_id = ? AND a.status = 'Active' AND a.student_id <> ?`, [room.room_id, id]);
  }
  const [history] = await pool.query(
    `SELECT h.hostel_name, r.room_no, a.check_in, a.check_out, a.status FROM allocation a
     JOIN room r ON r.room_id = a.room_id JOIN hostel h ON h.hostel_id = r.hostel_id
     WHERE a.student_id = ? ORDER BY a.check_in`, [id]);
  const [requests] = await pool.query(
    `SELECT sr.request_id, st.type_name, sr.description, sr.request_date, sr.status, sr.resolved_on
     FROM service_request sr JOIN service_type st ON st.service_type_id = sr.service_type_id
     WHERE sr.student_id = ? ORDER BY sr.request_id DESC`, [id]);
  const [trail] = await pool.query(
    `SELECT ru.request_id, ru.new_status, ru.remarks, ru.updated_on, f.full_name AS staff
     FROM request_update ru JOIN staff f ON f.staff_id = ru.staff_id
     JOIN service_request sr ON sr.request_id = ru.request_id
     WHERE sr.student_id = ? ORDER BY ru.updated_on`, [id]);
  const [payments] = await pool.query(
    'SELECT payment_id, fee_month, amount, payment_date, payment_mode FROM fee_payment WHERE student_id = ? ORDER BY fee_month', [id]);
  const [types] = await pool.query('SELECT service_type_id, type_name, target_days FROM service_type ORDER BY type_name');
  res.json({ profile, room, roommates, history, requests, trail, payments, types, today: today() });
}));

app.post('/api/requests', wrap(async (req, res) => {
  const { student_id, service_type_id, description } = req.body;
  const { text } = await write('CALL sp_raise_request(?, ?, ?, ?)', [student_id, service_type_id, description, today()]);
  const [[row]] = await pool.query('SELECT MAX(request_id) AS id FROM service_request WHERE student_id = ?', [student_id]);
  res.json({ id: row.id, sql: text });
}));

app.post('/api/requests/:id/cancel', wrap(async (req, res) => {
  const { r, text } = await write(
    "UPDATE service_request SET status = 'Cancelled' WHERE request_id = ? AND status = 'Open'", [req.params.id]);
  if (!r.affectedRows) return res.status(400).json({ error: 'Only an Open request can be cancelled', sql: text });
  res.json({ sql: text });
}));

app.post('/api/fees', wrap(async (req, res) => {
  const { student_id, fee_month, amount, payment_mode } = req.body;
  const { r, text } = await write(
    'INSERT INTO fee_payment (student_id, fee_month, amount, payment_date, payment_mode) VALUES (?, ?, ?, ?, ?)',
    [student_id, fee_month, amount, today(), payment_mode]);
  res.json({ id: r.insertId, sql: text });
}));

// ---------- Warden screens ----------

app.get('/api/office', wrap(async (req, res) => {
  const month = /^\d{4}-\d{2}$/.test(req.query.month || '') ? req.query.month : today().slice(0, 7);
  const [occupancy] = await pool.query('SELECT * FROM v_room_occupancy ORDER BY hostel_name, room_no');
  const [residents] = await pool.query(
    `SELECT a.allocation_id, s.roll_no, s.full_name, s.gender, h.hostel_name, r.room_no, a.check_in
     FROM allocation a JOIN student s ON s.student_id = a.student_id JOIN room r ON r.room_id = a.room_id
     JOIN hostel h ON h.hostel_id = r.hostel_id WHERE a.status = 'Active' ORDER BY h.hostel_name, r.room_no`);
  const [unallotted] = await pool.query(
    `SELECT s.student_id, s.roll_no, s.full_name, s.gender FROM student s
     WHERE NOT EXISTS (SELECT 1 FROM allocation a WHERE a.student_id = s.student_id AND a.status = 'Active')
     ORDER BY s.roll_no`);
  const [allStudents] = await pool.query('SELECT student_id, roll_no, full_name, gender FROM student ORDER BY roll_no');
  const [dues] = await pool.query(
    `SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, r.monthly_rent AS rent,
            f.payment_date, f.payment_mode,
            CASE WHEN f.payment_id IS NULL THEN 'Due' ELSE 'Paid' END AS fee_status
     FROM allocation a JOIN student s ON s.student_id = a.student_id JOIN room r ON r.room_id = a.room_id
     JOIN hostel h ON h.hostel_id = r.hostel_id
     LEFT JOIN fee_payment f ON f.student_id = a.student_id AND f.fee_month = ?
     WHERE a.status = 'Active' ORDER BY fee_status, h.hostel_name, r.room_no`, [month]);
  const [summary] = await pool.query('SELECT * FROM v_fee_summary ORDER BY roll_no');
  res.json({ month, occupancy, residents, unallotted, allStudents, dues, summary, today: today() });
}));

app.post('/api/allocate', wrap(async (req, res) => {
  const { student_id, room_id, check_in } = req.body;
  const { text } = await write('CALL sp_allocate_room(?, ?, ?)', [student_id, room_id, check_in || today()]);
  res.json({ sql: text });
}));

app.post('/api/vacate/:id', wrap(async (req, res) => {
  const { r, text } = await write(
    "UPDATE allocation SET status = 'Vacated', check_out = ? WHERE allocation_id = ? AND status = 'Active'",
    [req.body.check_out || today(), req.params.id]);
  if (!r.affectedRows) return res.status(400).json({ error: 'Allocation is not active', sql: text });
  res.json({ sql: text });
}));

// ---------- Service queue ----------

app.get('/api/queue', wrap(async (req, res) => {
  const [[me]] = await pool.query('SELECT staff_id, full_name, designation FROM staff WHERE staff_id = ?', [req.query.staff_id]);
  const types = (me && TRADE[me.designation]) || null;
  const [requests] = await pool.query(
    `SELECT sr.request_id, s.full_name, s.roll_no, h.hostel_name, r.room_no, st.type_name, sr.description,
            sr.request_date, sr.status, sr.resolved_on, st.target_days
     FROM service_request sr JOIN student s ON s.student_id = sr.student_id
     JOIN service_type st ON st.service_type_id = sr.service_type_id
     LEFT JOIN allocation a ON a.student_id = s.student_id AND a.status = 'Active'
     LEFT JOIN room r ON r.room_id = a.room_id LEFT JOIN hostel h ON h.hostel_id = r.hostel_id
     ${types ? 'WHERE st.type_name IN (?)' : ''}
     ORDER BY FIELD(sr.status,'Open','Assigned','In Progress','Resolved','Cancelled'), sr.request_date`, types ? [types] : []);
  const [trail] = await pool.query(
    `SELECT ru.request_id, ru.new_status, ru.remarks, ru.updated_on, f.full_name AS staff
     FROM request_update ru JOIN staff f ON f.staff_id = ru.staff_id ORDER BY ru.updated_on`);
  res.json({ me, types, requests, trail });
}));

app.post('/api/requests/:id/update', wrap(async (req, res) => {
  const { staff_id, new_status, remarks } = req.body;
  const { text } = await write(
    'INSERT INTO request_update (request_id, staff_id, new_status, remarks) VALUES (?, ?, ?, ?)',
    [req.params.id, staff_id, new_status, remarks || null]);
  const [[sr]] = await pool.query('SELECT status, resolved_on FROM service_request WHERE request_id = ?', [req.params.id]);
  res.json({ sql: text, status: sr.status, resolved_on: sr.resolved_on });
}));

// ---------- Records tab ----------

const table = (req, res, next) => {
  req.t = TABLES[req.params.table];
  if (!req.t) return res.status(404).json({ error: 'Unknown table' });
  next();
};

app.get('/api/tables', wrap(async (req, res) => {
  const [cols] = await pool.query(
    `SELECT TABLE_NAME AS t, COLUMN_NAME AS c, DATA_TYPE AS type, COLUMN_TYPE AS ctype, IS_NULLABLE AS nullable
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME, ORDINAL_POSITION`, [DB_NAME]);
  const [fks] = await pool.query(
    `SELECT TABLE_NAME AS t, COLUMN_NAME AS c, REFERENCED_TABLE_NAME AS rt, REFERENCED_COLUMN_NAME AS rc
     FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = ? AND REFERENCED_TABLE_NAME IS NOT NULL`, [DB_NAME]);
  const out = {};
  for (const [name, t] of Object.entries(TABLES)) {
    out[name] = {
      pk: t.pk,
      cols: t.cols.map((c) => {
        const info = cols.find((x) => x.t === name && x.c === c) || {};
        const fk = fks.find((x) => x.t === name && x.c === c);
        const en = /^enum\((.*)\)$/.exec(info.ctype || '');
        return {
          name: c, type: info.type, nullable: info.nullable === 'YES',
          options: en ? en[1].split(',').map((s) => s.slice(1, -1)) : null,
          ref: fk ? { table: fk.rt, col: fk.rc } : null,
        };
      }),
    };
  }
  res.json(out);
}));

app.get('/api/table/:table', table, wrap(async (req, res) => {
  const [rows] = await pool.query(`SELECT * FROM ${req.params.table} ORDER BY ${req.t.pk}`);
  res.json({ rows });
}));

app.post('/api/table/:table', table, wrap(async (req, res) => {
  const cols = req.t.cols.filter((c) => req.body[c] !== undefined && req.body[c] !== '');
  const { r, text } = await write(
    `INSERT INTO ${req.params.table} (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`,
    cols.map((c) => req.body[c]));
  res.json({ id: r.insertId, sql: text });
}));

app.delete('/api/table/:table/:id', table, wrap(async (req, res) => {
  const { r, text } = await write(`DELETE FROM ${req.params.table} WHERE ${req.t.pk} = ?`, [req.params.id]);
  res.json({ deleted: r.affectedRows, sql: text });
}));

// ---------- Database tab ----------

app.get('/api/db/overview', wrap(async (req, res) => {
  const [counts] = await pool.query(
    `SELECT TABLE_NAME AS name FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME`, [DB_NAME]);
  for (const c of counts) {
    const [[n]] = await pool.query(`SELECT COUNT(*) AS n FROM \`${c.name}\``);
    c.rows = n.n;
  }
  const one = async (sql) => (await pool.query(sql, [DB_NAME]))[0][0].n;
  res.json({
    tables: counts,
    foreignKeys: await one(`SELECT COUNT(*) AS n FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = ?`),
    indexes: await one(`SELECT COUNT(DISTINCT TABLE_NAME, INDEX_NAME) AS n FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = ? AND INDEX_NAME LIKE 'idx%'`),
    checks: await one(`SELECT COUNT(*) AS n FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = ?`),
    views: await one(`SELECT COUNT(*) AS n FROM information_schema.VIEWS WHERE TABLE_SCHEMA = ?`),
    triggers: await one(`SELECT COUNT(*) AS n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = ?`),
    procedures: await one(`SELECT COUNT(*) AS n FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = ? AND ROUTINE_TYPE = 'PROCEDURE'`),
  });
}));

app.get('/api/db/schema', wrap(async (req, res) => {
  const out = [];
  const [tables] = await pool.query(
    `SELECT TABLE_NAME AS n, TABLE_TYPE AS k FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? ORDER BY TABLE_TYPE, TABLE_NAME`, [DB_NAME]);
  for (const t of tables.filter((x) => x.k === 'BASE TABLE')) {
    const [[r]] = await pool.query(`SHOW CREATE TABLE \`${t.n}\``);
    out.push({ kind: 'Table', name: t.n, sql: r['Create Table'] });
  }
  for (const t of tables.filter((x) => x.k === 'VIEW')) {
    const [[r]] = await pool.query(`SHOW CREATE VIEW \`${t.n}\``);
    out.push({ kind: 'View', name: t.n, sql: r['Create View'].replace(/ALGORITHM=\S+ DEFINER=\S+ SQL SECURITY DEFINER /, '') });
  }
  const [procs] = await pool.query(`SELECT ROUTINE_NAME AS n FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = ?`, [DB_NAME]);
  for (const p of procs) {
    const [[r]] = await pool.query(`SHOW CREATE PROCEDURE \`${p.n}\``);
    out.push({ kind: 'Procedure', name: p.n, sql: r['Create Procedure'].replace(/DEFINER=\S+ /, '') });
  }
  const [trgs] = await pool.query(`SELECT TRIGGER_NAME AS n FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = ?`, [DB_NAME]);
  for (const t of trgs) {
    const [[r]] = await pool.query(`SHOW CREATE TRIGGER \`${t.n}\``);
    out.push({ kind: 'Trigger', name: t.n, sql: r['SQL Original Statement'].replace(/DEFINER=\S+ /, '') });
  }
  res.json(out);
}));

app.get('/api/db/queries', wrap(async (req, res) => {
  const out = [];
  for (const v of ['v_room_occupancy', 'v_open_requests', 'v_fee_summary']) {
    const sql = `SELECT * FROM ${v}`;
    const [rows] = await pool.query(sql);
    out.push({ id: 'View', title: v, sql, rows });
  }
  for (const [id, title, sql] of QUERIES) {
    const [rows] = await pool.query(sql);
    out.push({ id, title, sql, rows });
  }
  res.json(out);
}));

app.get('/api/db/log', (req, res) => res.json(activity));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Hostel Management UI running at http://localhost:${port}`));
