-- Bảng Categories
CREATE TABLE Categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100)
);

-- Bảng Products
CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    category_id INT,
    price DECIMAL(10, 2),
    stock_quantity INT,
    created_at DATETIME,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- Bảng Orders
CREATE TABLE Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    order_date DATETIME,
    status VARCHAR(20)
);

-- Bảng OrderItems
CREATE TABLE OrderItems (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);


-- Thêm danh mục
INSERT INTO Categories (name) VALUES ('Electronics'), ('Clothing'), ('Books');

-- Thêm sản phẩm
INSERT INTO Products (name, category_id, price, stock_quantity, created_at) VALUES
('Smartphone', 1, 12000000, 10, NOW() - INTERVAL 2 DAY),
('Laptop', 1, 25000000, 5, NOW() - INTERVAL 5 DAY),
('T-shirt', 2, 250000, 50, NOW() - INTERVAL 10 DAY),
('Novel', 3, 100000, 100, NOW() - INTERVAL 1 DAY);

-- Thêm đơn hàng
INSERT INTO Orders (user_id, order_date, status) VALUES
(1, NOW() - INTERVAL 3 DAY, 'Shipped'),
(2, NOW() - INTERVAL 15 DAY, 'Pending'),
(3, NOW() - INTERVAL 20 DAY, 'Shipped');

-- Thêm OrderItems
INSERT INTO OrderItems (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 12000000),
(1, 2, 1, 25000000),
(2, 3, 2, 250000),
(3, 1, 1, 12000000),
(3, 4, 3, 100000);


-- 1. Tạo chỉ mục để tối ưu truy vấn JOIN Orders và OrderItems
CREATE INDEX idx_orders_status_date ON Orders(status, order_date);
CREATE INDEX idx_orderitems_order_product ON OrderItems(order_id, product_id);

-- 2. Truy vấn JOIN đã tối ưu
SELECT Orders.order_id, Orders.order_date, OrderItems.product_id, OrderItems.quantity
FROM Orders 
JOIN OrderItems ON Orders.order_id = OrderItems.order_id
WHERE Orders.status = 'Shipped'
ORDER BY Orders.order_date DESC;

-- 3. So sánh JOIN vs Subquery (khuyên dùng JOIN)
-- JOIN cách:
SELECT Products.name, Categories.name AS category_name
FROM Products
JOIN Categories ON Products.category_id = Categories.category_id;

-- Subquery cách (kém hiệu quả hơn):
SELECT name,
    (SELECT name FROM Categories WHERE Categories.category_id = Products.category_id) AS category_name
FROM Products;

-- 4. Lấy 10 sản phẩm mới nhất còn hàng thuộc danh mục 'Electronics'
SELECT p.product_id, p.name, p.price, p.created_at
FROM Products p
JOIN Categories c ON p.category_id = c.category_id
WHERE c.name = 'Electronics'
  AND p.stock_quantity > 0
ORDER BY p.created_at DESC
LIMIT 10;

-- Index hỗ trợ truy vấn trên
CREATE INDEX idx_products_category_stock_created 
ON Products(category_id, stock_quantity, created_at);

-- 5. Covering index và truy vấn lấy sản phẩm theo category_id
CREATE INDEX idx_products_covering 
ON Products(category_id, price, product_id, name);

SELECT product_id, name, price 
FROM Products 
WHERE category_id = 3 
ORDER BY price ASC 
LIMIT 20;

-- 6. Tính doanh thu theo tháng trong năm 2025
CREATE INDEX idx_orders_orderdate ON Orders(order_date);

SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM Orders o
JOIN OrderItems oi ON o.order_id = oi.order_id
WHERE o.order_date BETWEEN '2025-01-01' AND '2025-12-31'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- 7. Tách truy vấn: Đơn hàng có sản phẩm > 1 triệu và tổng bán
-- Bước 1
SELECT DISTINCT order_id
FROM OrderItems
WHERE unit_price > 1000000;

-- Bước 2
SELECT oi.product_id, SUM(oi.quantity) AS total_sold
FROM OrderItems oi
WHERE oi.order_id IN (
    SELECT order_id FROM OrderItems WHERE unit_price > 1000000
)
GROUP BY oi.product_id;

-- 8. Top 5 sản phẩm bán chạy nhất trong 30 ngày gần nhất
CREATE INDEX idx_orders_recent ON Orders(order_date);
CREATE INDEX idx_orderitems_join ON OrderItems(order_id, product_id);

SELECT p.product_id, p.name, SUM(oi.quantity) AS total_sold
FROM Orders o
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
WHERE o.order_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY p.product_id, p.name
ORDER BY total_sold DESC
LIMIT 5;
