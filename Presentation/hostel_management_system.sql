-- =====================================================================
-- Hostel Accommodation and Student Services Management System
-- DBMS Course Project
-- Mohammed Amaan Khan (25WU0101075), Arslan Alam (25WU0101016),
-- Jaswant Reddy (25WU0101056)
--
-- Run:  mysql -u root -p < hostel_management_system.sql
-- Creates the database, tables, indexes, views, procedures, triggers,
-- sample data and the report queries Q1 to Q9.
-- =====================================================================

DROP DATABASE IF EXISTS hostel_db;
CREATE DATABASE hostel_db;
USE hostel_db;


-- ---------------------------------------------------------------------
-- 1. TABLES (DDL)
-- ---------------------------------------------------------------------

CREATE TABLE department (
    dept_id     INT AUTO_INCREMENT PRIMARY KEY,
    dept_code   VARCHAR(10) NOT NULL UNIQUE,
    dept_name   VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE staff (
    staff_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(60) NOT NULL,
    designation ENUM('Warden','Electrician','Plumber','Housekeeping',
                     'Network Technician','Mess Supervisor') NOT NULL,
    phone       CHAR(10) NOT NULL UNIQUE,
    CONSTRAINT chk_staff_phone CHECK (phone REGEXP '^[6-9][0-9]{9}$')
);

CREATE TABLE hostel (
    hostel_id   INT AUTO_INCREMENT PRIMARY KEY,
    hostel_name VARCHAR(50) NOT NULL UNIQUE,
    hostel_type ENUM('Boys','Girls') NOT NULL,
    warden_id   INT NOT NULL UNIQUE,
    FOREIGN KEY (warden_id) REFERENCES staff(staff_id)
);

CREATE TABLE room (
    room_id      INT AUTO_INCREMENT PRIMARY KEY,
    hostel_id    INT NOT NULL,
    room_no      VARCHAR(10) NOT NULL,
    room_type    ENUM('Single','Double','Triple') NOT NULL,
    capacity     TINYINT NOT NULL,
    monthly_rent DECIMAL(8,2) NOT NULL,
    UNIQUE (hostel_id, room_no),
    CONSTRAINT chk_room_capacity CHECK (capacity BETWEEN 1 AND 3),
    CONSTRAINT chk_room_rent     CHECK (monthly_rent > 0),
    FOREIGN KEY (hostel_id) REFERENCES hostel(hostel_id)
);

CREATE TABLE student (
    student_id    INT AUTO_INCREMENT PRIMARY KEY,
    roll_no       VARCHAR(15) NOT NULL UNIQUE,
    full_name     VARCHAR(60) NOT NULL,
    gender        ENUM('Male','Female') NOT NULL,
    dept_id       INT NOT NULL,
    year_of_study TINYINT NOT NULL,
    phone         CHAR(10) NOT NULL,
    email         VARCHAR(60) NOT NULL UNIQUE,
    CONSTRAINT chk_student_year CHECK (year_of_study BETWEEN 1 AND 4),
    FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

CREATE TABLE allocation (
    allocation_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id    INT NOT NULL,
    room_id       INT NOT NULL,
    check_in      DATE NOT NULL,
    check_out     DATE NULL,
    status        ENUM('Active','Vacated') NOT NULL DEFAULT 'Active',
    CONSTRAINT chk_alloc_dates CHECK (check_out IS NULL OR check_out >= check_in),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id)    REFERENCES room(room_id)
);

CREATE TABLE service_type (
    service_type_id INT AUTO_INCREMENT PRIMARY KEY,
    type_name       VARCHAR(30) NOT NULL UNIQUE,
    target_days     TINYINT NOT NULL,
    CONSTRAINT chk_target_days CHECK (target_days > 0)
);

CREATE TABLE service_request (
    request_id      INT AUTO_INCREMENT PRIMARY KEY,
    student_id      INT NOT NULL,
    service_type_id INT NOT NULL,
    description     VARCHAR(200) NOT NULL,
    request_date    DATE NOT NULL,
    status          ENUM('Open','Assigned','In Progress','Resolved','Cancelled')
                    NOT NULL DEFAULT 'Open',
    resolved_on     DATE NULL,
    CONSTRAINT chk_resolved_date CHECK (resolved_on IS NULL OR resolved_on >= request_date),
    FOREIGN KEY (student_id)      REFERENCES student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (service_type_id) REFERENCES service_type(service_type_id)
);

CREATE TABLE request_update (
    update_id   INT AUTO_INCREMENT PRIMARY KEY,
    request_id  INT NOT NULL,
    staff_id    INT NOT NULL,
    new_status  ENUM('Assigned','In Progress','Resolved') NOT NULL,
    remarks     VARCHAR(200),
    updated_on  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (request_id, new_status),
    FOREIGN KEY (request_id) REFERENCES service_request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (staff_id)   REFERENCES staff(staff_id)
);

CREATE TABLE fee_payment (
    payment_id   INT AUTO_INCREMENT PRIMARY KEY,
    student_id   INT NOT NULL,
    fee_month    CHAR(7) NOT NULL,
    amount       DECIMAL(8,2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_mode ENUM('Cash','UPI','Card','NetBanking') NOT NULL,
    UNIQUE (student_id, fee_month),
    CONSTRAINT chk_fee_amount CHECK (amount > 0),
    CONSTRAINT chk_fee_month  CHECK (fee_month REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);


-- ---------------------------------------------------------------------
-- 2. INDEXES
-- ---------------------------------------------------------------------

CREATE INDEX idx_alloc_room_status    ON allocation(room_id, status);
CREATE INDEX idx_alloc_student_status ON allocation(student_id, status);
CREATE INDEX idx_request_status       ON service_request(status);
CREATE INDEX idx_fee_month            ON fee_payment(fee_month);


-- ---------------------------------------------------------------------
-- 3. VIEWS
-- ---------------------------------------------------------------------

-- Beds taken and free in every room. Only Active allocations use a bed.
CREATE VIEW v_room_occupancy AS
SELECT r.room_id, h.hostel_name, h.hostel_type, r.room_no, r.room_type,
       r.capacity,
       COUNT(a.allocation_id)              AS occupied,
       r.capacity - COUNT(a.allocation_id) AS free_beds,
       r.monthly_rent
FROM room r
JOIN hostel h          ON h.hostel_id = r.hostel_id
LEFT JOIN allocation a ON a.room_id = r.room_id AND a.status = 'Active'
GROUP BY r.room_id, h.hostel_name, h.hostel_type, r.room_no, r.room_type,
         r.capacity, r.monthly_rent;

-- Requests that are not closed yet, with the student's room and age in days.
CREATE VIEW v_open_requests AS
SELECT sr.request_id, s.roll_no, s.full_name, h.hostel_name, r.room_no,
       st.type_name, sr.description, sr.request_date, sr.status,
       st.target_days
FROM service_request sr
JOIN student s       ON s.student_id = sr.student_id
JOIN service_type st ON st.service_type_id = sr.service_type_id
LEFT JOIN allocation a ON a.student_id = s.student_id AND a.status = 'Active'
LEFT JOIN room r       ON r.room_id = a.room_id
LEFT JOIN hostel h     ON h.hostel_id = r.hostel_id
WHERE sr.status IN ('Open','Assigned','In Progress');

-- Rent paid by every current resident.
CREATE VIEW v_fee_summary AS
SELECT s.student_id, s.roll_no, s.full_name, h.hostel_name, r.room_no,
       r.monthly_rent,
       COUNT(f.payment_id)          AS months_paid,
       COALESCE(SUM(f.amount), 0)   AS total_paid,
       MAX(f.fee_month)             AS last_paid_month
FROM allocation a
JOIN student s ON s.student_id = a.student_id
JOIN room r    ON r.room_id = a.room_id
JOIN hostel h  ON h.hostel_id = r.hostel_id
LEFT JOIN fee_payment f ON f.student_id = s.student_id
WHERE a.status = 'Active'
GROUP BY s.student_id, s.roll_no, s.full_name, h.hostel_name, r.room_no, r.monthly_rent;


-- ---------------------------------------------------------------------
-- 4. STORED PROCEDURES AND TRIGGERS
-- ---------------------------------------------------------------------

DELIMITER $$

-- Allot a bed. Checks are repeated by trg_allocation_before_insert, so a
-- direct INSERT into allocation is held to the same rules.
CREATE PROCEDURE sp_allocate_room(
    IN p_student_id INT, IN p_room_id INT, IN p_check_in DATE)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM student WHERE student_id = p_student_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not exist';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM room WHERE room_id = p_room_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room does not exist';
    END IF;
    INSERT INTO allocation(student_id, room_id, check_in)
    VALUES (p_student_id, p_room_id, p_check_in);
END$$

-- Raise a service request. Only a current resident can raise one, and the
-- same student cannot have two open requests of the same type.
CREATE PROCEDURE sp_raise_request(
    IN p_student_id INT, IN p_service_type_id INT,
    IN p_description VARCHAR(200), IN p_request_date DATE)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM allocation
                   WHERE student_id = p_student_id AND status = 'Active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only a current hostel resident can raise a request';
    END IF;
    IF EXISTS (SELECT 1 FROM service_request
               WHERE student_id = p_student_id
                 AND service_type_id = p_service_type_id
                 AND status IN ('Open','Assigned','In Progress')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An open request of this type already exists';
    END IF;
    INSERT INTO service_request(student_id, service_type_id, description, request_date)
    VALUES (p_student_id, p_service_type_id, p_description, p_request_date);
END$$

-- No allotment into a full room, into a hostel of the other gender, or to a
-- student who already has an active room.
CREATE TRIGGER trg_allocation_before_insert BEFORE INSERT ON allocation
FOR EACH ROW
BEGIN
    DECLARE v_capacity TINYINT;
    DECLARE v_occupied INT;
    DECLARE v_hostel_type VARCHAR(5);
    DECLARE v_gender VARCHAR(6);

    IF NEW.status = 'Active' THEN
        IF EXISTS (SELECT 1 FROM allocation
                   WHERE student_id = NEW.student_id AND status = 'Active') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student already has an active room';
        END IF;

        SELECT r.capacity, h.hostel_type INTO v_capacity, v_hostel_type
        FROM room r JOIN hostel h ON h.hostel_id = r.hostel_id
        WHERE r.room_id = NEW.room_id;

        SELECT gender INTO v_gender FROM student WHERE student_id = NEW.student_id;
        IF (v_hostel_type = 'Boys' AND v_gender <> 'Male')
           OR (v_hostel_type = 'Girls' AND v_gender <> 'Female') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hostel type does not match student gender';
        END IF;

        SELECT COUNT(*) INTO v_occupied FROM allocation
        WHERE room_id = NEW.room_id AND status = 'Active';
        IF v_occupied >= v_capacity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is full';
        END IF;
    END IF;
END$$

-- Status moves one step at a time: Open > Assigned > In Progress > Resolved.
CREATE TRIGGER trg_update_before_insert BEFORE INSERT ON request_update
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(15);
    SELECT status INTO v_status FROM service_request WHERE request_id = NEW.request_id;

    IF v_status IN ('Resolved','Cancelled') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service request is already closed';
    END IF;
    IF NEW.new_status = 'Assigned' AND v_status <> 'Open' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is already assigned';
    END IF;
    IF NEW.new_status = 'In Progress' AND v_status <> 'Assigned' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request must be assigned before work starts';
    END IF;
    IF NEW.new_status = 'Resolved' AND v_status <> 'In Progress' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request must be In Progress before it is resolved';
    END IF;
END$$

-- Copy the new status to the request and stamp the resolved date.
CREATE TRIGGER trg_update_after_insert AFTER INSERT ON request_update
FOR EACH ROW
BEGIN
    IF NEW.new_status = 'Resolved' THEN
        UPDATE service_request
        SET status = 'Resolved', resolved_on = DATE(NEW.updated_on)
        WHERE request_id = NEW.request_id;
    ELSE
        UPDATE service_request SET status = NEW.new_status
        WHERE request_id = NEW.request_id;
    END IF;
END$$

-- Rent can be paid only by a current resident, and only the rent of the
-- room they live in.
CREATE TRIGGER trg_fee_before_insert BEFORE INSERT ON fee_payment
FOR EACH ROW
BEGIN
    DECLARE v_rent DECIMAL(8,2);
    SELECT r.monthly_rent INTO v_rent
    FROM allocation a JOIN room r ON r.room_id = a.room_id
    WHERE a.student_id = NEW.student_id AND a.status = 'Active';

    IF v_rent IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student has no active room';
    END IF;
    IF NEW.amount <> v_rent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must equal the monthly rent of the room';
    END IF;
END$$

DELIMITER ;


-- ---------------------------------------------------------------------
-- 5. SAMPLE DATA (DML)
-- ---------------------------------------------------------------------

INSERT INTO department (dept_code, dept_name) VALUES
('CSE',  'Computer Science and Engineering'),
('AIML', 'Artificial Intelligence and Machine Learning'),
('ECE',  'Electronics and Communication Engineering'),
('MECH', 'Mechanical Engineering'),
('BBA',  'Business Administration');

INSERT INTO staff (full_name, designation, phone) VALUES
('Mr. Ramesh Kumar',  'Warden',             '9876500001'),
('Mr. Suresh Nair',   'Warden',             '9876500002'),
('Mrs. Lakshmi Iyer', 'Warden',             '9876500003'),
('Mrs. Kavitha Pillai','Warden',            '9876500004'),
('Mr. Vijay Singh',   'Warden',             '9876500005'),
('Mr. Prakash Yadav', 'Electrician',        '9876500006'),
('Mr. Imran Shaikh',  'Plumber',            '9876500007'),
('Ms. Rekha Bai',     'Housekeeping',       '9876500008'),
('Mr. Naveen Reddy',  'Network Technician', '9876500009'),
('Mr. Gopal Rao',     'Mess Supervisor',    '9876500010');

INSERT INTO hostel (hostel_name, hostel_type, warden_id) VALUES
('Aryabhata Block', 'Boys',  1),
('Bhaskara Block',  'Boys',  2),
('Gargi Block',     'Girls', 3),
('Maitreyi Block',  'Girls', 4),
('Raman Block',     'Boys',  5);

INSERT INTO room (hostel_id, room_no, room_type, capacity, monthly_rent) VALUES
(1, 'A101', 'Double', 2, 4500.00),
(1, 'A102', 'Triple', 3, 3500.00),
(2, 'B201', 'Single', 1, 6500.00),
(3, 'G101', 'Double', 2, 4500.00),
(3, 'G102', 'Single', 1, 6500.00),
(4, 'M301', 'Triple', 3, 3500.00),
(5, 'R105', 'Double', 2, 4800.00),
(5, 'R106', 'Single', 1, 6000.00);

INSERT INTO student (roll_no, full_name, gender, dept_id, year_of_study, phone, email) VALUES
('CS2401', 'Arjun Mehta',    'Male',   1, 2, '9000000001', 'arjun.mehta@college.edu'),
('CS2402', 'Rohan Das',      'Male',   1, 2, '9000000002', 'rohan.das@college.edu'),
('AI2403', 'Priya Sharma',   'Female', 2, 2, '9000000003', 'priya.sharma@college.edu'),
('AI2404', 'Sneha Reddy',    'Female', 2, 3, '9000000004', 'sneha.reddy@college.edu'),
('EC2405', 'Karan Patel',    'Male',   3, 1, '9000000005', 'karan.patel@college.edu'),
('ME2406', 'Divya Menon',    'Female', 4, 4, '9000000006', 'divya.menon@college.edu'),
('BB2407', 'Farhan Qureshi', 'Male',   5, 1, '9000000007', 'farhan.qureshi@college.edu'),
('CS2408', 'Ananya Gupta',   'Female', 1, 1, '9000000008', 'ananya.gupta@college.edu');

-- Divya's 2025-26 stay is closed, so it goes in as Vacated.
INSERT INTO allocation (student_id, room_id, check_in, check_out, status) VALUES
(6, 6, '2025-07-10', '2026-05-30', 'Vacated');

CALL sp_allocate_room(1, 1, '2026-07-15');
CALL sp_allocate_room(2, 1, '2026-07-15');
CALL sp_allocate_room(3, 4, '2026-07-16');
CALL sp_allocate_room(4, 5, '2026-07-16');
CALL sp_allocate_room(5, 3, '2026-07-20');
CALL sp_allocate_room(7, 7, '2026-07-22');
CALL sp_allocate_room(8, 4, '2026-08-01');

INSERT INTO service_type (type_name, target_days) VALUES
('Electrical',   2),
('Plumbing',     2),
('Housekeeping', 1),
('Internet',     1),
('Mess',         3),
('Laundry',      2);

CALL sp_raise_request(1, 1, 'Ceiling fan not working',            '2026-09-01');
CALL sp_raise_request(2, 4, 'Wi-Fi keeps dropping in room A101',  '2026-09-05');
CALL sp_raise_request(3, 6, 'Weekly laundry pickup was missed',   '2026-09-08');
CALL sp_raise_request(4, 3, 'Room cleaning needed',               '2026-09-12');
CALL sp_raise_request(5, 5, 'Request for Jain meal option',       '2026-09-15');
CALL sp_raise_request(1, 2, 'Leaking tap in the bathroom',        '2026-09-20');
CALL sp_raise_request(7, 1, 'Tube light flickering near the desk','2026-10-03');

-- The triggers move each request forward as these rows go in.
INSERT INTO request_update (request_id, staff_id, new_status, remarks, updated_on) VALUES
(1, 6, 'Assigned',    'Electrician assigned',          '2026-09-01 10:30:00'),
(1, 6, 'In Progress', 'Checking fan capacitor',        '2026-09-01 16:00:00'),
(1, 6, 'Resolved',    'Capacitor replaced, fan works', '2026-09-02 11:15:00'),
(2, 9, 'Assigned',    'Network team informed',         '2026-09-05 12:00:00'),
(2, 9, 'In Progress', 'Access point being replaced',   '2026-09-06 09:45:00'),
(3, 8, 'Assigned',    'Laundry vendor contacted',      '2026-09-08 14:00:00'),
(3, 8, 'In Progress', 'Pickup rescheduled',            '2026-09-09 08:30:00'),
(3, 8, 'Resolved',    'Clothes collected and returned','2026-09-10 18:00:00'),
(4, 8, 'Assigned',    'Housekeeping slot booked',      '2026-09-12 15:20:00');

INSERT INTO fee_payment (student_id, fee_month, amount, payment_date, payment_mode) VALUES
(1, '2026-08', 4500.00, '2026-08-05', 'UPI'),
(2, '2026-08', 4500.00, '2026-08-06', 'Card'),
(3, '2026-08', 4500.00, '2026-08-05', 'NetBanking'),
(4, '2026-08', 6500.00, '2026-08-07', 'UPI'),
(5, '2026-08', 6500.00, '2026-08-10', 'Cash'),
(7, '2026-08', 4800.00, '2026-08-08', 'UPI'),
(8, '2026-08', 4500.00, '2026-08-03', 'UPI'),
(1, '2026-09', 4500.00, '2026-09-04', 'UPI'),
(2, '2026-09', 4500.00, '2026-09-05', 'UPI'),
(3, '2026-09', 4500.00, '2026-09-06', 'Card'),
(4, '2026-09', 6500.00, '2026-09-06', 'UPI'),
(5, '2026-09', 6500.00, '2026-09-09', 'Cash'),
(7, '2026-09', 4800.00, '2026-09-07', 'NetBanking'),
(1, '2026-10', 4500.00, '2026-10-03', 'UPI'),
(3, '2026-10', 4500.00, '2026-10-04', 'UPI');


-- ---------------------------------------------------------------------
-- 6. REPORT QUERIES
-- ---------------------------------------------------------------------

-- Q1: occupancy and free beds in every room.
SELECT hostel_name, room_no, room_type, capacity, occupied, free_beds
FROM v_room_occupancy
ORDER BY hostel_name, room_no;

-- Q2: rooms with a free bed in girls' hostels, cheapest first.
SELECT hostel_name, room_no, room_type, free_beds, monthly_rent
FROM v_room_occupancy
WHERE hostel_type = 'Girls' AND free_beds > 0
ORDER BY monthly_rent;

-- Q3: who stays where.
SELECT s.roll_no, s.full_name, d.dept_code, h.hostel_name, r.room_no, a.check_in
FROM allocation a
JOIN student s    ON s.student_id = a.student_id
JOIN department d ON d.dept_id = s.dept_id
JOIN room r       ON r.room_id = a.room_id
JOIN hostel h     ON h.hostel_id = r.hostel_id
WHERE a.status = 'Active'
ORDER BY h.hostel_name, r.room_no;

-- Q4: open service requests with the student's room.
SELECT request_id, full_name, hostel_name, room_no, type_name, request_date, status
FROM v_open_requests
ORDER BY request_date;

-- Q5: history of every request (who changed the status and when).
SELECT sr.request_id, s.full_name, st.type_name, ru.new_status,
       f.full_name AS staff, ru.remarks, ru.updated_on
FROM service_request sr
JOIN student s       ON s.student_id = sr.student_id
JOIN service_type st ON st.service_type_id = sr.service_type_id
JOIN request_update ru ON ru.request_id = sr.request_id
JOIN staff f         ON f.staff_id = ru.staff_id
ORDER BY sr.request_id, ru.updated_on;

-- Q6: residents who have not paid rent for October 2026.
SELECT s.roll_no, s.full_name, h.hostel_name, r.room_no, r.monthly_rent AS due
FROM allocation a
JOIN student s ON s.student_id = a.student_id
JOIN room r    ON r.room_id = a.room_id
JOIN hostel h  ON h.hostel_id = r.hostel_id
WHERE a.status = 'Active'
  AND NOT EXISTS (SELECT 1 FROM fee_payment f
                  WHERE f.student_id = a.student_id AND f.fee_month = '2026-10');

-- Q7: rent collected per hostel per month.
SELECT h.hostel_name, f.fee_month, COUNT(*) AS payments, SUM(f.amount) AS collected
FROM fee_payment f
JOIN allocation a ON a.student_id = f.student_id AND a.status = 'Active'
JOIN room r       ON r.room_id = a.room_id
JOIN hostel h     ON h.hostel_id = r.hostel_id
GROUP BY h.hostel_name, f.fee_month
ORDER BY f.fee_month, h.hostel_name;

-- Q8: resolved requests per service type against the target time.
SELECT st.type_name, st.target_days, COUNT(*) AS resolved,
       AVG(DATEDIFF(sr.resolved_on, sr.request_date)) AS avg_days
FROM service_request sr
JOIN service_type st ON st.service_type_id = sr.service_type_id
WHERE sr.status = 'Resolved'
GROUP BY st.service_type_id, st.type_name, st.target_days;

-- Q9: hostel residents per department (departments with at least two).
SELECT d.dept_name, COUNT(*) AS residents
FROM allocation a
JOIN student s    ON s.student_id = a.student_id
JOIN department d ON d.dept_id = s.dept_id
WHERE a.status = 'Active'
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(*) >= 2;
