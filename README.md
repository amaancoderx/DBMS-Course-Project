# Design and Implementation of a Database Management System for Hostel Accommodation and Student Services Management System

A MySQL database with a web UI to manage hostels, rooms, student room allocation, service requests and fee payments.

## Group Members

| Name | Roll Number |
|------|-------------|
| MEMBER 1 NAME | ROLL NO |
| MEMBER 2 NAME | ROLL NO |
| MEMBER 3 NAME | ROLL NO |

## Folders

- `Presentation/` : slides, ER diagram, `hostel.sql` (all commands), UI source code (`ui/`), screenshots
- `Project-Report/` : project report

## How to run

1. Create the database: `mysql -u root -p < Presentation/hostel.sql`
2. Start the UI:
   ```
   cd Presentation/ui
   npm install
   set DB_PASSWORD=your_mysql_password
   npm start
   ```
   (PowerShell: `$env:DB_PASSWORD="your_mysql_password"`)
3. Open http://localhost:3000

Tech stack: MySQL 8, Node.js, Express, mysql2, HTML/CSS/JavaScript.
