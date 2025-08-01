
-- ===========================
-- TẠO BẢNG VÀ DỮ LIỆU MẪU
-- ===========================

-- Bảng Users
CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    city VARCHAR(100),
    referrer_id INT,
    created_at DATE
);

INSERT INTO Users (user_id, full_name, city, referrer_id, created_at) VALUES
(1, 'Nguyen Van A', 'Hanoi', NULL, '2023-01-01'),
(2, 'Tran Thi B', 'HCM', 1, '2023-01-10'),
(3, 'Le Van C', 'Hanoi', 1, '2023-01-12'),
(4, 'Do Thi D', 'Da Nang', 2, '2023-02-05'),
(5, 'Hoang E', 'Can Tho', NULL, '2023-02-10');

-- Bảng Products
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(100),
    price INT,
    is_active BOOLEAN
);

INSERT INTO Products (product_id, product_name, category, price, is_active) VALUES
(1, 'iPhone 13', 'Electronics', 20000000, 1),
(2, 'MacBook Air', 'Electronics', 28000000, 1),
(3, 'Coffee Beans', 'Grocery', 250000, 1),
(4, 'Book: SQL Basics', 'Books', 150000, 1),
(5, 'Xbox Controller', 'Gaming', 1200000, 0);

-- Bảng Orders
CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    user_id INT,
    order_date DATE,
    status VARCHAR(20)
);

INSERT INTO Orders (order_id, user_id, order_date, status) VALUES
(1001, 1, '2023-02-01', 'completed'),
(1002, 2, '2023-02-10', 'cancelled'),
(1003, 3, '2023-02-12', 'completed'),
(1004, 4, '2023-02-15', 'completed'),
(1005, 1, '2023-03-01', 'pending');

-- Bảng OrderItems
CREATE TABLE OrderItems (
    order_id INT,
    product_id INT,
    quantity INT
);

INSERT INTO OrderItems (order_id, product_id, quantity) VALUES
(1001, 1, 1),
(1001, 3, 3),
(1003, 2, 1),
(1003, 4, 2),
(1004, 3, 5),
(1005, 2, 1);

-- 1. Phân tích doanh thu theo danh mục sản phẩm (chỉ đơn hàng completed)
-- Yêu cầu: Tính tổng doanh thu từ các đơn hàng completed, nhóm theo danh mục sản phẩm
SELECT
    p.category,
    SUM(oi.quantity * p.price) AS total_revenue
FROM OrderItems oi
JOIN Orders o ON oi.order_id = o.order_id
JOIN Products p ON oi.product_id = p.product_id
WHERE o.status = 'completed'
GROUP BY p.category;

-- 2. Danh sách người dùng kèm tên người giới thiệu
-- Yêu cầu: Tạo danh sách các người dùng kèm theo tên người giới thiệu (self join)
SELECT 
    u.user_id,
    u.full_name,
    r.full_name AS referrer_name
FROM Users u
LEFT JOIN Users r ON u.referrer_id = r.user_id;

-- 3. Sản phẩm từng được mua nhưng hiện không còn bán
-- Yêu cầu: Tìm các sản phẩm đã từng được đặt mua nhưng hiện tại không còn active
SELECT DISTINCT p.product_id, p.product_name
FROM Products p
JOIN OrderItems oi ON p.product_id = oi.product_id
WHERE p.is_active = 0;

-- 4. Người dùng chưa từng đặt đơn hàng nào
-- Yêu cầu: Tìm các người dùng chưa từng đặt bất kỳ đơn hàng nào
SELECT u.user_id, u.full_name
FROM Users u
LEFT JOIN Orders o ON u.user_id = o.user_id
WHERE o.order_id IS NULL;

-- 5. Đơn hàng đầu tiên của mỗi người dùng
-- Yêu cầu: Với mỗi user, tìm order_id tương ứng với đơn hàng đầu tiên của họ
SELECT user_id, MIN(order_id) AS first_order_id
FROM Orders
GROUP BY user_id;

-- 6. Tổng chi tiêu của mỗi người dùng
-- Yêu cầu: Viết truy vấn lấy tổng tiền mà từng người dùng đã chi tiêu (chỉ tính đơn hàng completed)
SELECT 
    o.user_id,
    u.full_name,
    SUM(oi.quantity * p.price) AS total_spent
FROM Orders o
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
JOIN Users u ON o.user_id = u.user_id
WHERE o.status = 'completed'
GROUP BY o.user_id, u.full_name;

-- 7. Người dùng chi tiêu > 25 triệu
-- Yêu cầu: Từ kết quả trên, chỉ lấy các user có tổng chi tiêu > 25 triệu
SELECT *
FROM (
    SELECT 
        o.user_id,
        u.full_name,
        SUM(oi.quantity * p.price) AS total_spent
    FROM Orders o
    JOIN OrderItems oi ON o.order_id = oi.order_id
    JOIN Products p ON oi.product_id = p.product_id
    JOIN Users u ON o.user_id = u.user_id
    WHERE o.status = 'completed'
    GROUP BY o.user_id, u.full_name
) AS user_spending
WHERE total_spent > 25000000;

-- 8. So sánh các thành phố
-- Yêu cầu: Tính tổng số đơn hàng và tổng doanh thu của từng thành phố
SELECT 
    u.city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity * p.price) AS total_revenue
FROM Orders o
JOIN Users u ON o.user_id = u.user_id
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
WHERE o.status = 'completed'
GROUP BY u.city;

-- 9. Người dùng có ít nhất 2 đơn hàng completed
-- Yêu cầu: Truy xuất danh sách người dùng thỏa điều kiện
SELECT u.user_id, u.full_name, COUNT(*) AS completed_orders
FROM Users u
JOIN Orders o ON u.user_id = o.user_id
WHERE o.status = 'completed'
GROUP BY u.user_id, u.full_name
HAVING COUNT(*) >= 2;

-- 10. Đơn hàng chứa sản phẩm thuộc nhiều hơn 1 danh mục
-- Yêu cầu: Tìm đơn hàng có sản phẩm thuộc nhiều hơn 1 danh mục
SELECT oi.order_id
FROM OrderItems oi
JOIN Products p ON oi.product_id = p.product_id
GROUP BY oi.order_id
HAVING COUNT(DISTINCT p.category) > 1;

-- 11. Kết hợp danh sách người dùng đã từng đặt hàng và được giới thiệu
-- Yêu cầu: Dùng UNION để kết hợp 2 danh sách không trùng lặp
-- A: người dùng đã từng đặt hàng
-- B: người dùng được người khác giới thiệu
SELECT DISTINCT u.user_id, u.full_name, 'placed_order' AS source
FROM Users u
JOIN Orders o ON u.user_id = o.user_id

UNION

SELECT DISTINCT u.user_id, u.full_name, 'referred' AS source
FROM Users u
WHERE u.referrer_id IS NOT NULL;
