<div align="center">

<img src="ER_Diagram.png" alt="ER diagram of the Hostel Accommodation and Student Services Management System" width="900" />

<br/>
<br/>

<strong>Design and Implementation of a Database Management System for<br/>Hostel Accommodation and Student Services Management System</strong>

<br/>
<br/>

[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white)](https://dev.mysql.com/doc/refman/8.0/en/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-4-000000?style=flat-square&logo=express&logoColor=white)](https://expressjs.com/)
[![Tables](https://img.shields.io/badge/tables-10-blue?style=flat-square)](#database-at-a-glance)
[![Normal form](https://img.shields.io/badge/schema-3NF-2e6da4?style=flat-square)](#database-at-a-glance)
[![Course](https://img.shields.io/badge/DBMS-Course%20Project-c0602b?style=flat-square)](#group-members)

</div>

# Hostel Accommodation and Student Services Management System

A MySQL database with a web interface that runs the day to day work of college hostels: room allotment, service requests (electrical, plumbing, housekeeping, internet, mess, laundry) and monthly rent. The rules live inside the database as constraints, stored procedures and triggers, so a full room, a wrong hostel or a wrong rent amount is refused no matter where the data comes from.

### Group Members

| Name | Roll Number |
|------|-------------|
| Mohammed Amaan Khan | 25WU0101075 |
| Arslan Alam | 25WU0101016 |
| Jaswant Reddy | 25WU0101056 |

## Contents

- [Project Files](#project-files)
- [Database at a Glance](#database-at-a-glance)
- [Rules Enforced by the Database](#rules-enforced-by-the-database)
- [How to Run](#how-to-run)
- [Using the App](#using-the-app)
- [Report Queries](#report-queries)
- [Tech Stack](#tech-stack)

## Project Files

| File | What it is |
|------|------------|
| [hostel_management_system.sql](hostel_management_system.sql) | Complete MySQL script: tables, indexes, views, procedures, triggers, sample data and queries Q1 to Q9 |
| [ER_Diagram.png](ER_Diagram.png) | ER diagram of the final schema |
| [Project-Report/DBMS Project Report.pdf](Project-Report/DBMS%20Project%20Report.pdf) | Project report |
| [Presentation/DBMS_Presentation_Hostel_Accommodation_Student_Services.pptx](Presentation/DBMS_Presentation_Hostel_Accommodation_Student_Services.pptx) | Final presentation (PowerPoint) |
| [Presentation/Presentation.pdf](Presentation/Presentation.pdf) | Same presentation as PDF |
| [Presentation/Relational_Schema.pdf](Presentation/Relational_Schema.pdf) | Relational schema with all primary, foreign and unique keys |
| [Presentation/UI_Screenshots_Hostel_Accommodation_Student_Services.pdf](Presentation/UI_Screenshots_Hostel_Accommodation_Student_Services.pdf) | Every screen of the UI, insert, delete and view shown before and after, with the matching MySQL output |
| [Presentation/hostel_management_system.sql](Presentation/hostel_management_system.sql) | Copy of the SQL script kept with the presentation material |
| [Presentation/ui/](Presentation/ui/) | Source code of the web interface (Node.js, Express, mysql2, HTML/CSS/JS) |
| [Presentation/screenshots/](Presentation/screenshots/) | Screenshots used in the report and the screenshots PDF |

## Database at a Glance

| Item | Count | Names |
|------|:-----:|-------|
| Tables | 10 | department, staff, hostel, room, student, allocation, service_type, service_request, request_update, fee_payment |
| Views | 3 | v_room_occupancy, v_open_requests, v_fee_summary |
| Stored procedures | 2 | sp_allocate_room, sp_raise_request |
| Triggers | 4 | trg_allocation_before_insert, trg_update_before_insert, trg_update_after_insert, trg_fee_before_insert |
| Indexes | 4 | on allocation, service_request and fee_payment |
| Report queries | 9 | Q1 to Q9, see below |

Relational schema (primary key first, `*` marks a foreign key):

```
DEPARTMENT(dept_id, dept_code, dept_name)
STAFF(staff_id, full_name, designation, phone)
HOSTEL(hostel_id, hostel_name, hostel_type, warden_id*)
ROOM(room_id, hostel_id*, room_no, room_type, capacity, monthly_rent)
STUDENT(student_id, roll_no, full_name, gender, dept_id*, year_of_study, phone, email)
ALLOCATION(allocation_id, student_id*, room_id*, check_in, check_out, status)
SERVICE_TYPE(service_type_id, type_name, target_days)
SERVICE_REQUEST(request_id, student_id*, service_type_id*, description, request_date, status, resolved_on)
REQUEST_UPDATE(update_id, request_id*, staff_id*, new_status, remarks, updated_on)
FEE_PAYMENT(payment_id, student_id*, fee_month, amount, payment_date, payment_mode)
```

## Rules Enforced by the Database

| Rule | Enforced by |
|------|-------------|
| A room cannot hold more students than its capacity | `trg_allocation_before_insert` |
| A student can only be allotted a room in a hostel of their gender | `trg_allocation_before_insert` |
| A student can have only one active room | `trg_allocation_before_insert` |
| Only a current resident can raise a service request, one open request per type | `sp_raise_request` |
| A request moves Open, Assigned, In Progress, Resolved, one step at a time | `trg_update_before_insert` |
| The request status and resolved date follow every step | `trg_update_after_insert` |
| Rent must equal the rent of the student's current room | `trg_fee_before_insert` |
| One payment per student per month | `UNIQUE (student_id, fee_month)` |
| Capacity 1 to 3, year of study 1 to 4, check-out not before check-in | `CHECK` constraints |
| A hostel with rooms, or a room with allotments, cannot be deleted | Foreign keys |

## How to Run

**Requirements:** MySQL 8.0 and Node.js 18 or later.

**1. Create the database**

```bash
mysql -u root -p < hostel_management_system.sql
```

This creates `hostel_db` with all tables, sample data, views, procedures and triggers, and prints the results of Q1 to Q9.

**2. Start the web interface**

```bash
cd Presentation/ui
npm install
```

Set your MySQL password and start the server.

Windows (PowerShell):

```powershell
$env:DB_PASSWORD="your_mysql_password"
npm start
```

macOS / Linux:

```bash
DB_PASSWORD=your_mysql_password npm start
```

**3. Open** http://localhost:3000

Optional settings: `DB_HOST` (default `localhost`), `DB_PORT` (default `3306`), `DB_USER` (default `root`), `DB_NAME` (default `hostel_db`), `PORT` (default `3000`). If MySQL is not reachable, the page says so at the top instead of failing silently.

## Using the App

Pick a user from **Login as** in the top right. Each role sees its own screens.

| Role | Screens |
|------|---------|
| Student | **My Room** (room, roommates, stay history), **Service Requests** (raise, follow, cancel), **Fees** (pay rent, payment history) |
| Warden | **Allocate Room** (allot and vacate), **Occupancy** (free beds per room), **Fee Dues** (paid or due for any month), **All Requests** |
| Service staff | **Service Queue** for their trade, with a button to move each request to the next step |
| Everyone | **Records** (insert and delete rows in any table), **Database** (row counts, schema, views and queries, activity log) |

After every action the page shows the exact SQL statement that was sent to MySQL. When MySQL refuses something, the message from the trigger or constraint is shown on the page.

## Report Queries

| Query | Question it answers |
|-------|---------------------|
| Q1 | Occupancy and free beds in every room |
| Q2 | Rooms with a free bed in girls' hostels, cheapest first |
| Q3 | Who stays where (join across four tables) |
| Q4 | Open service requests with the student's room |
| Q5 | Full history of every request: who changed the status and when |
| Q6 | Residents who have not paid rent for October 2026 |
| Q7 | Rent collected per hostel per month |
| Q8 | Resolved requests per service type against the target days |
| Q9 | Hostel residents per department (departments with at least two) |

## Tech Stack

| Layer | Tool |
|-------|------|
| Database | MySQL 8.0 |
| Back end | Node.js, Express 4, mysql2 |
| Front end | HTML, CSS, JavaScript |
| Diagrams and documents | ER diagram, relational schema, report and slides in this repository |
