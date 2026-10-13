# Design and Implementation of a Database Management System for Hostel Accommodation and Student Services Management System

**Course:** Database Management Systems (Course Project)
**Section:** SECTION NAME
**Faculty:** FACULTY NAME
**Academic Year:** 2026-27

| Name | Roll Number |
|------|-------------|
| MEMBER 1 NAME | ROLL NO |
| MEMBER 2 NAME | ROLL NO |
| MEMBER 3 NAME | ROLL NO |

---

## 1. Abstract

College hostels usually track rooms, residents, complaints and fee receipts in registers or scattered spreadsheets, which leads to double allotment of beds, lost complaints and unclear dues. This project designs a normalized MySQL database and a web interface that keeps all of this in one place. The database has six related tables (hostel, room, student, allocation, service request and fee payment) with primary keys, foreign keys and check constraints. A Node.js web UI lets the hostel office insert, view and delete records, and shows reports built with joins and aggregate functions.

## 2. Introduction and Problem Statement

A hostel office must answer simple questions every day: which room has a free bed, which student stays where, which complaints are still open, and who has paid this month. With paper registers these answers are slow and often wrong.

**Problem statement:** Design and implement a database management system that stores hostel, room, student, allocation, service request and fee data consistently, and gives staff a simple interface to maintain and query it.

## 3. Objectives and Scope

**Objectives**
- Store hostel and room details with capacity and rent.
- Record student details and their room allocation history.
- Log student service requests (maintenance, laundry, mess, housekeeping, internet) and their status.
- Record fee payments and report collections.
- Enforce data integrity with keys and constraints.
- Provide a UI for insert, delete and view operations.

**Scope:** One college with multiple hostel blocks. Intended users are the hostel warden and office staff. Online payment, login roles and mess menu planning are out of scope.

## 4. Software and Hardware Requirements

| Item | Requirement |
|------|-------------|
| Database | MySQL 8.0 |
| Backend | Node.js 18 or later, Express 4, mysql2 |
| Frontend | HTML, CSS, JavaScript (any modern browser) |
| OS | Windows / Linux / macOS |
| Hardware | 4 GB RAM, 500 MB free disk, dual core processor |

## 5. ER Diagram

See `Presentation/ER-Diagram.svg`.

**Entities:** HOSTEL, ROOM, STUDENT, ALLOCATION, SERVICE_REQUEST, FEE_PAYMENT.

| Relationship | Cardinality | Participation |
|--------------|-------------|---------------|
| HOSTEL has ROOM | 1 : N | Room total, hostel partial |
| ROOM is allotted in ALLOCATION | 1 : N | Allocation total, room partial |
| STUDENT gets ALLOCATION | 1 : N | Allocation total, student partial |
| STUDENT raises SERVICE_REQUEST | 1 : N | Request total, student partial |
| STUDENT pays FEE_PAYMENT | 1 : N | Payment total, student partial |

ALLOCATION resolves the M : N relationship between STUDENT and ROOM over time.

## 6. Relational Schema and Normalization

- hostel(**hostel_id**, hostel_name, hostel_type, warden_name, warden_phone)
- room(**room_id**, *hostel_id*, room_no, room_type, capacity, monthly_rent)
- student(**student_id**, roll_no, full_name, gender, department, year_of_study, phone, email)
- allocation(**allocation_id**, *student_id*, *room_id*, check_in, check_out, status)
- service_request(**request_id**, *student_id*, service_type, description, request_date, status)
- fee_payment(**payment_id**, *student_id*, amount, payment_date, payment_mode, fee_month)

Bold = primary key, italic = foreign key.

**1NF:** Every column holds a single atomic value; there are no repeating groups (a student's many payments and requests are separate rows in their own tables).

**2NF:** Every table has a single-column primary key, so no non-key attribute can depend on part of a key.

**3NF:** No non-key attribute depends on another non-key attribute. For example, hostel name and warden are not repeated in `room`; they are reached through `hostel_id`. Room rent is not repeated in `allocation`; it is reached through `room_id`.

## 7. Data Dictionary

**hostel**

| Column | Type | Constraint |
|--------|------|-----------|
| hostel_id | INT | PK, AUTO_INCREMENT |
| hostel_name | VARCHAR(50) | NOT NULL, UNIQUE |
| hostel_type | ENUM('Boys','Girls') | NOT NULL |
| warden_name | VARCHAR(50) | NOT NULL |
| warden_phone | CHAR(10) | NOT NULL |

**room**

| Column | Type | Constraint |
|--------|------|-----------|
| room_id | INT | PK, AUTO_INCREMENT |
| hostel_id | INT | NOT NULL, FK to hostel |
| room_no | VARCHAR(10) | NOT NULL, UNIQUE with hostel_id |
| room_type | ENUM('Single','Double','Triple') | NOT NULL |
| capacity | INT | NOT NULL, CHECK 1 to 3 |
| monthly_rent | DECIMAL(8,2) | NOT NULL, CHECK > 0 |

**student**

| Column | Type | Constraint |
|--------|------|-----------|
| student_id | INT | PK, AUTO_INCREMENT |
| roll_no | VARCHAR(15) | NOT NULL, UNIQUE |
| full_name | VARCHAR(60) | NOT NULL |
| gender | ENUM('Male','Female') | NOT NULL |
| department | VARCHAR(30) | NOT NULL |
| year_of_study | INT | NOT NULL, CHECK 1 to 4 |
| phone | CHAR(10) | NOT NULL |
| email | VARCHAR(60) | UNIQUE |

**allocation**

| Column | Type | Constraint |
|--------|------|-----------|
| allocation_id | INT | PK, AUTO_INCREMENT |
| student_id | INT | NOT NULL, FK to student, ON DELETE CASCADE |
| room_id | INT | NOT NULL, FK to room |
| check_in | DATE | NOT NULL |
| check_out | DATE | NULL, CHECK >= check_in |
| status | ENUM('Active','Vacated') | NOT NULL, DEFAULT 'Active' |

**service_request**

| Column | Type | Constraint |
|--------|------|-----------|
| request_id | INT | PK, AUTO_INCREMENT |
| student_id | INT | NOT NULL, FK to student, ON DELETE CASCADE |
| service_type | ENUM('Maintenance','Laundry','Mess','Housekeeping','Internet') | NOT NULL |
| description | VARCHAR(200) | NOT NULL |
| request_date | DATE | NOT NULL |
| status | ENUM('Open','In Progress','Resolved') | NOT NULL, DEFAULT 'Open' |

**fee_payment**

| Column | Type | Constraint |
|--------|------|-----------|
| payment_id | INT | PK, AUTO_INCREMENT |
| student_id | INT | NOT NULL, FK to student, ON DELETE CASCADE |
| amount | DECIMAL(8,2) | NOT NULL, CHECK > 0 |
| payment_date | DATE | NOT NULL |
| payment_mode | ENUM('Cash','UPI','Card','NetBanking') | NOT NULL |
| fee_month | VARCHAR(15) | NOT NULL |

## 8. SQL Commands Used (DDL, DML)

The full script is in `Presentation/hostel.sql`. Examples:

```sql
CREATE TABLE room (
  room_id      INT AUTO_INCREMENT PRIMARY KEY,
  hostel_id    INT NOT NULL,
  room_no      VARCHAR(10) NOT NULL,
  room_type    ENUM('Single','Double','Triple') NOT NULL,
  capacity     INT NOT NULL CHECK (capacity BETWEEN 1 AND 3),
  monthly_rent DECIMAL(8,2) NOT NULL CHECK (monthly_rent > 0),
  UNIQUE (hostel_id, room_no),
  FOREIGN KEY (hostel_id) REFERENCES hostel(hostel_id)
);

INSERT INTO student (roll_no, full_name, gender, department, year_of_study, phone, email)
VALUES ('CS2401','Arjun Mehta','Male','CSE',2,'9000000001','arjun@college.edu');

DELETE FROM service_request WHERE request_id = 4;
```

*(Paste the MySQL output screenshots here after running the script.)*

## 9. Queries with Outputs

```sql
-- Students and their rooms (JOIN)
SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, a.check_in, a.status
FROM allocation a
JOIN student s ON s.student_id = a.student_id
JOIN room r    ON r.room_id = a.room_id
JOIN hostel h  ON h.hostel_id = r.hostel_id;

-- Occupancy and free beds per room (LEFT JOIN, COUNT, GROUP BY)
SELECT h.hostel_name, r.room_no, r.capacity,
       COUNT(a.allocation_id) AS occupied,
       r.capacity - COUNT(a.allocation_id) AS free_beds
FROM room r
JOIN hostel h ON h.hostel_id = r.hostel_id
LEFT JOIN allocation a ON a.room_id = r.room_id AND a.status = 'Active'
GROUP BY r.room_id, h.hostel_name, r.room_no, r.capacity;

-- Total fees paid per student (SUM)
SELECT s.roll_no, s.full_name, COUNT(f.payment_id) AS payments, SUM(f.amount) AS total_paid
FROM student s
LEFT JOIN fee_payment f ON f.student_id = s.student_id
GROUP BY s.student_id, s.roll_no, s.full_name;

-- Service types with more than one request (HAVING)
SELECT service_type, COUNT(*) AS requests
FROM service_request GROUP BY service_type HAVING COUNT(*) > 1;
```

*(Paste the output screenshots here.)*

## 10. UI Design and Screenshots

The UI is a single web page with one tab per table and a Reports tab.

- **Insert:** a form at the top of each tab; on submit the row is written to MySQL and the table below refreshes.
- **View:** all rows of the selected table are listed with a record count.
- **Delete:** a Delete button on every row, with a confirmation prompt.
- **Reports:** runs the join and aggregate queries and shows the SQL next to each result.

*(Add screenshots from `Presentation/screenshots/`: view, insert before and after, delete before and after, reports.)*

## 11. Implementation Details

**Technology stack:** MySQL 8, Node.js, Express, mysql2, HTML/CSS/JavaScript.

**DB connectivity:** the server opens a mysql2 connection pool; credentials come from environment variables.

```js
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'hostel_db',
});
```

**Insert and delete** use parameterized queries, so user input is never joined into the SQL text. Table and column names come from a fixed whitelist in the server.

```js
app.delete('/api/:table/:id', table, wrap(async (req, res) => {
  const [r] = await pool.query(`DELETE FROM ${req.params.table} WHERE ${req.t.pk} = ?`, [req.params.id]);
  res.json({ deleted: r.affectedRows });
}));
```

Database errors (duplicate roll number, missing foreign key, failed check) are returned to the page and shown as a red message.

## 12. Testing

| # | Test case | Expected result | Result |
|---|-----------|-----------------|--------|
| 1 | Insert a valid student | Row appears in UI and in `SELECT * FROM student` | |
| 2 | Insert a student with an existing roll_no | Rejected: duplicate entry | |
| 3 | Insert a room with hostel_id that does not exist | Rejected: foreign key constraint fails | |
| 4 | Insert a room with capacity 5 | Rejected: check constraint violated | |
| 5 | Delete a service request | Row removed in UI and in MySQL | |
| 6 | Delete a student who has allocations and payments | Student and child rows removed (ON DELETE CASCADE) | |
| 7 | Delete a hostel that still has rooms | Rejected: foreign key constraint fails | |
| 8 | Open the Reports tab | Join and aggregate results match the same queries in MySQL | |

*(Fill in the Result column after running each test.)*

## 13. Conclusion and Future Enhancements

The project delivers a 3NF database for hostel operations with integrity enforced by the database itself, and a working interface for the day-to-day insert, view and delete tasks.

Future enhancements: login with warden and student roles, update/edit forms, a trigger that blocks allocation when a room is full, automatic monthly due calculation, mess billing, and email or SMS alerts for service request status.

## 14. References

1. Silberschatz, Korth, Sudarshan, *Database System Concepts*, 7th edition, McGraw Hill.
2. Elmasri, Navathe, *Fundamentals of Database Systems*, 7th edition, Pearson.
3. MySQL 8.0 Reference Manual, https://dev.mysql.com/doc/refman/8.0/en/
4. Express documentation, https://expressjs.com/
5. mysql2 documentation, https://sidorares.github.io/node-mysql2/docs

## 15. Contribution of Each Member

| Member | Contribution |
|--------|--------------|
| MEMBER 1 NAME | |
| MEMBER 2 NAME | |
| MEMBER 3 NAME | |

## 16. Appendix: GitHub Repository Link

https://github.com/amaancoderx/DBMS-Course-Project
