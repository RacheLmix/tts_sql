-- 🎯 C1: Tạo cơ sở dữ liệu tên là OnlineLearning
CREATE DATABASE OnlineLearning;

-- 🎯 C2: Xóa cơ sở dữ liệu OnlineLearning nếu không còn dùng nữa
DROP DATABASE IF EXISTS OnlineLearning;

-- Sau khi xóa, tạo lại và sử dụng CSDL
CREATE DATABASE OnlineLearning;
USE OnlineLearning;


CREATE TABLE Students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    join_date DATE
);

CREATE TABLE Courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    price INT
);

CREATE TABLE Enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    course_id INT,
    enroll_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES Students(student_id),
    FOREIGN KEY (course_id) REFERENCES Courses(course_id)
);

INSERT INTO Students (full_name, email, join_date) VALUES
('Nguyen Van A', 'a.nguyen@example.com', '2024-09-01'),
('Tran Thi B', 'b.tran@example.com', '2024-09-05'),
('Le Van C', 'c.le@example.com', '2024-09-10');

INSERT INTO Courses (title, description, price) VALUES
('SQL for Beginners', 'Introduction to SQL and relational databases.', 500000),
('Advanced Python', 'Deep dive into advanced Python topics.', 750000),
('Web Development', 'Learn to build websites with HTML, CSS, JS.', 650000);

INSERT INTO Enrollments (student_id, course_id) VALUES
(1, 1),
(1, 2),
(2, 1),
(3, 3);


-- 🎯 C4: Thêm cột status vào bảng Enrollments với giá trị mặc định là 'active'
ALTER TABLE Enrollments
ADD COLUMN status VARCHAR(20) DEFAULT 'active';

-- 🎯 C5: Xóa bảng Enrollments nếu không còn cần nữa
-- (chỉ chạy khi cần xóa bảng)
-- DROP TABLE IF EXISTS Enrollments;

-- 🎯 C6: Tạo VIEW StudentCourseView hiển thị danh sách sinh viên và tên khóa học họ đã đăng ký
CREATE VIEW StudentCourseView AS
SELECT 
    s.student_id,
    s.full_name,
    c.course_id,
    c.title AS course_title,
    e.enroll_date,
    e.status
FROM 
    Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Courses c ON e.course_id = c.course_id;

-- 🎯 C7: Tạo INDEX trên cột title của bảng Courses để tối ưu tìm kiếm
CREATE INDEX idx_course_title ON Courses(title);
