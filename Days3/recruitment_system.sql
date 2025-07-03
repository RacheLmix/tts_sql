
-- ====================================
-- HỆ THỐNG QUẢN LÝ TUYỂN DỤNG - FULL SQL
-- ====================================

-- =====================
-- 1. TẠO CÁC BẢNG
-- =====================

CREATE TABLE Candidates (
    candidate_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    years_exp INT,
    expected_salary INT
);

CREATE TABLE Jobs (
    job_id INT PRIMARY KEY,
    title VARCHAR(100),
    department VARCHAR(50),
    min_salary INT,
    max_salary INT
);

CREATE TABLE Applications (
    app_id INT PRIMARY KEY,
    candidate_id INT,
    job_id INT,
    apply_date DATE,
    status VARCHAR(20),
    FOREIGN KEY (candidate_id) REFERENCES Candidates(candidate_id),
    FOREIGN KEY (job_id) REFERENCES Jobs(job_id)
);

CREATE TABLE ShortlistedCandidates (
    candidate_id INT,
    job_id INT,
    selection_date DATE
);

-- =====================
-- 2. THÊM DỮ LIỆU MẪU
-- =====================

INSERT INTO Candidates VALUES
(1, 'Nguyen Van A', 'a@gmail.com', '0911111111', 0, 800),
(2, 'Tran Thi B', 'b@gmail.com', NULL, 2, 1000),
(3, 'Le Van C', 'c@gmail.com', '0933333333', 5, 1200),
(4, 'Pham Thi D', 'd@gmail.com', NULL, 7, 1500);

INSERT INTO Jobs VALUES
(1, 'Backend Developer', 'IT', 900, 1300),
(2, 'HR Specialist', 'HR', 700, 1100),
(3, 'Frontend Developer', 'IT', 1000, 1400),
(4, 'Sales Executive', 'Sales', 600, 1000),
(5, 'DevOps Engineer', 'IT', 1500, 2000);

INSERT INTO Applications VALUES
(1, 1, 1, '2025-06-01', 'Pending'),
(2, 2, 2, '2025-06-02', 'Accepted'),
(3, 3, 3, '2025-06-03', 'Accepted'),
(4, 1, 4, '2025-06-04', 'Rejected'),
(5, 4, 5, '2025-06-05', 'Pending');

-- ===============================
-- 3. CÁC TRUY VẤN THEO YÊU CẦU
-- ===============================

-- 3.1 Tìm các ứng viên từng ứng tuyển công việc thuộc phòng ban IT
SELECT *
FROM Candidates c
WHERE EXISTS (
    -- Bước 1: Kiểm tra ứng viên có ứng tuyển vào job thuộc phòng IT
    SELECT 1
    FROM Applications a
    JOIN Jobs j ON a.job_id = j.job_id
    WHERE a.candidate_id = c.candidate_id AND j.department = 'IT'
);

-- 3.2 Liệt kê công việc có max_salary > expected_salary của bất kỳ ứng viên nào
SELECT *
FROM Jobs
WHERE max_salary > ANY (
    -- Bước 1: Lấy tất cả mức lương mong đợi
    SELECT expected_salary FROM Candidates
);

-- 3.3 Liệt kê công việc có min_salary > expected_salary của tất cả ứng viên
SELECT *
FROM Jobs
WHERE min_salary > ALL (
    -- Bước 1: Lấy tất cả mức lương mong đợi
    SELECT expected_salary FROM Candidates
);

-- 3.4 Chèn ứng viên có trạng thái 'Accepted' vào ShortlistedCandidates
INSERT INTO ShortlistedCandidates (candidate_id, job_id, selection_date)
SELECT candidate_id, job_id, CURRENT_DATE
FROM Applications
WHERE status = 'Accepted';

-- 3.5 Hiển thị ứng viên với đánh giá kinh nghiệm (Fresher, Junior, ...)
SELECT full_name, years_exp,
  CASE 
    WHEN years_exp < 1 THEN 'Fresher'
    WHEN years_exp BETWEEN 1 AND 3 THEN 'Junior'
    WHEN years_exp BETWEEN 4 AND 6 THEN 'Mid-level'
    ELSE 'Senior'
  END AS experience_level
FROM Candidates;

-- 3.6 Liệt kê ứng viên, thay NULL phone bằng 'Chưa cung cấp'
SELECT full_name, COALESCE(phone, 'Chưa cung cấp') AS phone
FROM Candidates;

-- 3.7 Công việc có max_salary != min_salary AND max_salary >= 1000
SELECT *
FROM Jobs
WHERE max_salary != min_salary AND max_salary >= 1000;
