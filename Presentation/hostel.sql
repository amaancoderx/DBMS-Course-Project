-- Hostel Accommodation and Student Services Management System
-- Run: mysql -u root -p < hostel.sql

DROP DATABASE IF EXISTS hostel_db;
CREATE DATABASE hostel_db;
USE hostel_db;

-- ---------- DDL ----------
CREATE TABLE hostel (
  hostel_id    INT AUTO_INCREMENT PRIMARY KEY,
  hostel_name  VARCHAR(50) NOT NULL UNIQUE,
  hostel_type  ENUM('Boys','Girls') NOT NULL,
  warden_name  VARCHAR(50) NOT NULL,
  warden_phone CHAR(10) NOT NULL
);

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

CREATE TABLE student (
  student_id    INT AUTO_INCREMENT PRIMARY KEY,
  roll_no       VARCHAR(15) NOT NULL UNIQUE,
  full_name     VARCHAR(60) NOT NULL,
  gender        ENUM('Male','Female') NOT NULL,
  department    VARCHAR(30) NOT NULL,
  year_of_study INT NOT NULL CHECK (year_of_study BETWEEN 1 AND 4),
  phone         CHAR(10) NOT NULL,
  email         VARCHAR(60) UNIQUE
);

CREATE TABLE allocation (
  allocation_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id    INT NOT NULL,
  room_id       INT NOT NULL,
  check_in      DATE NOT NULL,
  check_out     DATE,
  status        ENUM('Active','Vacated') NOT NULL DEFAULT 'Active',
  CHECK (check_out IS NULL OR check_out >= check_in),
  FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
  FOREIGN KEY (room_id) REFERENCES room(room_id)
);

CREATE TABLE service_request (
  request_id   INT AUTO_INCREMENT PRIMARY KEY,
  student_id   INT NOT NULL,
  service_type ENUM('Maintenance','Laundry','Mess','Housekeeping','Internet') NOT NULL,
  description  VARCHAR(200) NOT NULL,
  request_date DATE NOT NULL,
  status       ENUM('Open','In Progress','Resolved') NOT NULL DEFAULT 'Open',
  FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);

CREATE TABLE fee_payment (
  payment_id   INT AUTO_INCREMENT PRIMARY KEY,
  student_id   INT NOT NULL,
  amount       DECIMAL(8,2) NOT NULL CHECK (amount > 0),
  payment_date DATE NOT NULL,
  payment_mode ENUM('Cash','UPI','Card','NetBanking') NOT NULL,
  fee_month    VARCHAR(15) NOT NULL,
  FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);

-- ---------- DML ----------
INSERT INTO hostel (hostel_name, hostel_type, warden_name, warden_phone) VALUES
('Aryabhata Block','Boys','Mr. Ramesh Kumar','9876500001'),
('Bhaskara Block','Boys','Mr. Suresh Nair','9876500002'),
('Gargi Block','Girls','Mrs. Lakshmi Iyer','9876500003'),
('Maitreyi Block','Girls','Mrs. Anita Rao','9876500004'),
('Raman Block','Boys','Mr. Vijay Singh','9876500005');

INSERT INTO room (hostel_id, room_no, room_type, capacity, monthly_rent) VALUES
(1,'A101','Double',2,4500.00),
(1,'A102','Triple',3,3500.00),
(2,'B201','Single',1,6500.00),
(3,'G101','Double',2,4500.00),
(3,'G102','Single',1,6500.00),
(4,'M301','Triple',3,3500.00),
(5,'R105','Double',2,4800.00);

INSERT INTO student (roll_no, full_name, gender, department, year_of_study, phone, email) VALUES
('CS2401','Arjun Mehta','Male','CSE',2,'9000000001','arjun@college.edu'),
('CS2402','Rohan Das','Male','CSE',2,'9000000002','rohan@college.edu'),
('AI2403','Priya Sharma','Female','AIML',2,'9000000003','priya@college.edu'),
('AI2404','Sneha Reddy','Female','AIML',3,'9000000004','sneha@college.edu'),
('EC2405','Karan Patel','Male','ECE',1,'9000000005','karan@college.edu'),
('ME2406','Divya Menon','Female','MECH',4,'9000000006','divya@college.edu');

INSERT INTO allocation (student_id, room_id, check_in, check_out, status) VALUES
(1,1,'2026-07-15',NULL,'Active'),
(2,1,'2026-07-15',NULL,'Active'),
(3,4,'2026-07-16',NULL,'Active'),
(4,5,'2026-07-16',NULL,'Active'),
(5,3,'2026-07-20',NULL,'Active'),
(6,6,'2025-07-10','2026-05-30','Vacated');

INSERT INTO service_request (student_id, service_type, description, request_date, status) VALUES
(1,'Maintenance','Ceiling fan not working','2026-09-01','Resolved'),
(2,'Internet','Wi-Fi drops in room A101','2026-09-05','In Progress'),
(3,'Laundry','Weekly laundry pickup','2026-09-08','Resolved'),
(4,'Housekeeping','Room cleaning request','2026-09-12','Open'),
(5,'Mess','Request for Jain meal option','2026-09-15','Open'),
(1,'Maintenance','Leaking tap in bathroom','2026-09-20','Open');

INSERT INTO fee_payment (student_id, amount, payment_date, payment_mode, fee_month) VALUES
(1,4500.00,'2026-08-05','UPI','August'),
(2,4500.00,'2026-08-06','Card','August'),
(3,4500.00,'2026-08-05','NetBanking','August'),
(4,6500.00,'2026-08-07','UPI','August'),
(5,6500.00,'2026-08-10','Cash','August'),
(1,4500.00,'2026-09-04','UPI','September');

-- ---------- SELECT queries ----------
-- Q1: all students
SELECT * FROM student;

-- Q2 (JOIN): who stays where
SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, a.check_in, a.status
FROM allocation a
JOIN student s ON s.student_id = a.student_id
JOIN room r    ON r.room_id = a.room_id
JOIN hostel h  ON h.hostel_id = r.hostel_id;

-- Q3 (LEFT JOIN + aggregate): occupancy and free beds per room
SELECT h.hostel_name, r.room_no, r.capacity,
       COUNT(a.allocation_id) AS occupied,
       r.capacity - COUNT(a.allocation_id) AS free_beds
FROM room r
JOIN hostel h ON h.hostel_id = r.hostel_id
LEFT JOIN allocation a ON a.room_id = r.room_id AND a.status = 'Active'
GROUP BY r.room_id, h.hostel_name, r.room_no, r.capacity;

-- Q4 (aggregate): total fees paid per student
SELECT s.roll_no, s.full_name, COUNT(f.payment_id) AS payments, SUM(f.amount) AS total_paid
FROM student s
LEFT JOIN fee_payment f ON f.student_id = s.student_id
GROUP BY s.student_id, s.roll_no, s.full_name;

-- Q5 (aggregate + HAVING): service types with more than one request
SELECT service_type, COUNT(*) AS requests
FROM service_request
GROUP BY service_type
HAVING COUNT(*) > 1;

-- Q6 (JOIN): pending service requests with room
SELECT sr.request_id, s.full_name, r.room_no, sr.service_type, sr.description, sr.status
FROM service_request sr
JOIN student s ON s.student_id = sr.student_id
LEFT JOIN allocation a ON a.student_id = s.student_id AND a.status = 'Active'
LEFT JOIN room r ON r.room_id = a.room_id
WHERE sr.status <> 'Resolved';

-- Q7 (aggregate): fee collection by month and average rent by room type
SELECT fee_month, SUM(amount) AS collected FROM fee_payment GROUP BY fee_month;
SELECT room_type, AVG(monthly_rent) AS avg_rent, MAX(monthly_rent) AS max_rent FROM room GROUP BY room_type;
