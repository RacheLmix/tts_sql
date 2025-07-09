-- ================================================
-- 🧠 TOÀN BỘ SQL GỒM 9 YÊU CẦU TỐI ƯU CHUYÊN SÂU
-- ================================================

-- ✅ Yêu cầu 0: Schema Cơ Bản
-- ✅ Bảng Users: Lưu thông tin người dùng
CREATE TABLE IF NOT EXISTS Users (
  user_id INT PRIMARY KEY AUTO_INCREMENT,          -- ID tự tăng
  username VARCHAR(50) NOT NULL UNIQUE,            -- Tên đăng nhập duy nhất
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- Ngày tạo
);

-- ✅ Bảng Posts: Lưu bài đăng của người dùng
CREATE TABLE IF NOT EXISTS Posts (
  post_id INT PRIMARY KEY AUTO_INCREMENT,          -- ID bài viết
  user_id INT NOT NULL,                            -- ID người đăng
  content TEXT,                                    -- Nội dung bài viết
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Thời gian đăng
  likes INT DEFAULT 0,                             -- Số lượt thích
  hashtags VARCHAR(100),                           -- Danh sách hashtag thô
  FOREIGN KEY (user_id) REFERENCES Users(user_id), -- Ràng buộc tới Users
  INDEX (created_at),                              -- Tăng tốc truy vấn theo thời gian
  FULLTEXT (hashtags)                              -- ✅ Cho phép tìm kiếm fulltext hashtag
);

-- ✅ Bảng Follows: Quan hệ người theo dõi
CREATE TABLE IF NOT EXISTS Follows (
  follower_id INT NOT NULL,                        -- Người theo dõi
  followee_id INT NOT NULL,                        -- Người được theo dõi
  PRIMARY KEY (follower_id, followee_id),          -- Khóa chính kép
  FOREIGN KEY (follower_id) REFERENCES Users(user_id),
  FOREIGN KEY (followee_id) REFERENCES Users(user_id)
);

-- ✅ Bảng PostViews: Phân vùng theo tháng (phải chỉnh lại theo yêu cầu MySQL)
-- ❗ Không dùng hàm trong PARTITION BY, thay bằng cột partition_key INT (YYYYMM)
CREATE TABLE IF NOT EXISTS PostViews (
  view_id INT UNSIGNED AUTO_INCREMENT,             -- ID lượt xem
  post_id INT,                                     -- ID bài viết (không dùng FK vì bị partition hạn chế)
  viewer_id INT,                                   -- ID người xem
  view_time TIMESTAMP,                             -- Thời điểm xem
  partition_key INT NOT NULL,                      -- YYYYMM để dùng làm phân vùng
  PRIMARY KEY(view_id, partition_key)              -- MySQL yêu cầu key phải chứa cột partition
)
PARTITION BY RANGE (partition_key) (
  PARTITION p202407 VALUES LESS THAN (202408),     -- Partition cho tháng 07/2025
  PARTITION p202408 VALUES LESS THAN (202409),     -- Partition cho tháng 08/2025
  PARTITION pmax     VALUES LESS THAN MAXVALUE     -- Default partition
);

-- ✅ Bảng PostHashtags: chuẩn hóa hashtag
CREATE TABLE IF NOT EXISTS PostHashtags (
  post_id INT,                                     -- ID bài viết
  hashtag VARCHAR(50),                             -- Hashtag riêng biệt
  PRIMARY KEY (post_id, hashtag),                  -- Khóa chính kép
  INDEX (hashtag),                                 -- Tăng tốc tìm kiếm hashtag
  FOREIGN KEY (post_id) REFERENCES Posts(post_id)
);

-- ✅ Bảng PopularPostsDaily: tổng hợp lượt thích & view mỗi ngày
CREATE TABLE IF NOT EXISTS PopularPostsDaily (
  post_id INT,
  report_date DATE,                                -- Ngày tổng hợp
  total_likes INT,                                 -- Tổng like hôm đó
  total_views INT,                                 -- Tổng view hôm đó
  PRIMARY KEY(post_id, report_date)
);

-- ✅ Bảng Likes: lưu thông tin người like bài
CREATE TABLE IF NOT EXISTS Likes (
  user_id INT,                                     -- Người like
  post_id INT,                                     -- Bài được like
  liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,    -- Thời điểm like
  PRIMARY KEY(user_id, post_id),                   -- Like duy nhất theo user + bài
  FOREIGN KEY (user_id) REFERENCES Users(user_id),
  FOREIGN KEY (post_id) REFERENCES Posts(post_id)
);


-- ✅ Yêu cầu 7: Stored Procedure tối ưu Like
DELIMITER $$

CREATE PROCEDURE LikePost(
  IN in_user_id INT,
  IN in_post_id INT
)
BEGIN
  DECLARE already_liked INT;

  SELECT COUNT(*) INTO already_liked
  FROM Likes
  WHERE user_id = in_user_id AND post_id = in_post_id;

  IF already_liked = 0 THEN
    START TRANSACTION;
      INSERT INTO Likes(user_id, post_id) VALUES (in_user_id, in_post_id);
      UPDATE Posts SET likes = likes + 1 WHERE post_id = in_post_id;
    COMMIT;
  END IF;
END$$

DELIMITER ;

-- ✅ Yêu cầu 1: Truy vấn lấy 10 post được thích nhất hôm nay (gợi ý cache)
SELECT post_id, content, likes
FROM Posts
WHERE DATE(created_at) = CURDATE()
ORDER BY likes DESC
LIMIT 10;

-- 👉 Có thể cache tại ứng dụng (Redis key: top_posts:YYYY-MM-DD) hoặc MEMORY TABLE nếu MySQL

-- ✅ Yêu cầu 2: EXPLAIN ANALYZE + cải thiện
-- Truy vấn gốc (có bottleneck):
-- EXPLAIN ANALYZE
SELECT * FROM Posts
WHERE hashtags LIKE '%fitness%'
ORDER BY created_at DESC
LIMIT 20;

-- ✅ Giải pháp: Dùng FULLTEXT index:
SELECT * FROM Posts
WHERE MATCH(hashtags) AGAINST('+fitness' IN BOOLEAN MODE)
ORDER BY created_at DESC
LIMIT 20;

-- ✅ Yêu cầu 3 (tiếp): Truy vấn thống kê số view theo tháng
SELECT 
  DATE_FORMAT(view_time, '%Y-%m') AS month,
  COUNT(*) AS views
FROM PostViews
WHERE view_time >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY month
ORDER BY month DESC;

-- ✅ Yêu cầu 6: Window Function – RANK top 3 bài viết mỗi ngày
WITH DailyViews AS (
  SELECT 
    post_id,
    DATE(view_time) AS view_date,
    COUNT(*) AS total_views
  FROM PostViews
  GROUP BY post_id, DATE(view_time)
),
Ranked AS (
  SELECT *,
    RANK() OVER (PARTITION BY view_date ORDER BY total_views DESC) AS view_rank
  FROM DailyViews
)
SELECT *
FROM Ranked
WHERE view_rank <= 3
ORDER BY view_date DESC, view_rank;

-- ✅ Yêu cầu 8: Bật Slow Query Log
-- Chạy 1 lần trong MySQL CLI:
-- SET GLOBAL slow_query_log = 1;
-- SET GLOBAL long_query_time = 1; -- log nếu > 1 giây
-- SHOW VARIABLES LIKE 'slow_query_log_file';

-- Truy vấn chậm ví dụ:
SELECT * FROM Posts WHERE hashtags LIKE '%fitness%';

-- ✅ Cải thiện: Thêm FULLTEXT index, tránh % đầu, thêm LIMIT

-- ✅ Yêu cầu 9: Sử dụng OPTIMIZER_TRACE
SET optimizer_trace="enabled=on";

-- Truy vấn để phân tích
SELECT u.username, p.content
FROM users u
JOIN posts p ON u.user_id = p.user_id
WHERE p.created_at >= CURDATE() - INTERVAL 7 DAY
ORDER BY p.created_at DESC
LIMIT 10;

-- Truy xuất JSON kế hoạch truy vấn:
SELECT trace FROM information_schema.OPTIMIZER_TRACE\G


INSERT INTO Users (username) VALUES
('alice'), ('bob'), ('charlie'), ('david'), ('emma'),
('fiona'), ('george'), ('harry'), ('ivy'), ('jack');

INSERT INTO Posts (user_id, content, hashtags, created_at, likes) VALUES
(1, 'Loving the gym vibes 💪', 'fitness,health', NOW(), 5),
(2, 'Morning run success! 🏃‍♀️', 'fitness,motivation', NOW(), 8),
(3, 'Cooking something special 🍝', 'food,homemade', NOW(), 2),
(4, 'Tech trends 2025 🔮', 'tech,ai', NOW() - INTERVAL 1 DAY, 4),
(5, 'Best sunset view ever 🌅', 'travel,nature', NOW() - INTERVAL 2 DAY, 7),
(6, 'My pet is the cutest 🐶', 'pets,cute', NOW(), 3),
(7, 'Another day, another grind ☕', 'life,motivation', NOW(), 6),
(8, 'New recipe alert 🔥', 'food,recipe', NOW(), 1),
(9, 'Trying yoga today 🧘‍♂️', 'fitness,yoga', NOW(), 4),
(10, 'React vs Vue – let''s go! ⚔️', 'tech,frontend', NOW(), 9),
(1, 'Nature walk 🌳', 'nature,relax', NOW() - INTERVAL 1 DAY, 0),
(2, 'Friday night chill 🎶', 'life,chill', NOW(), 5),
(3, 'Just finished reading Dune 📚', 'books,scifi', NOW(), 3),
(4, 'Beach vibes only 🏖️', 'travel,fun', NOW(), 6),
(5, 'AI just wrote my code 😱', 'tech,ai', NOW(), 8),
(6, 'Weekend plans?', 'life,weekend', NOW(), 2),
(7, 'My fitness journey begins', 'fitness', NOW(), 10),
(8, 'Caffeine saves lives ☕', 'coffee,life', NOW(), 1),
(9, 'Beautiful Hanoi nights 🌃', 'travel,vietnam', NOW(), 4),
(10, 'New blog post up!', 'tech,writing', NOW(), 7);

INSERT INTO Likes (user_id, post_id) VALUES
(1, 1), (2, 2), (3, 2), (4, 4), (5, 5), (6, 6), (7, 7),
(8, 8), (9, 9), (10, 10), (1, 11), (2, 12), (3, 13),
(4, 14), (5, 15), (6, 16), (7, 17), (8, 18), (9, 19), (10, 20);

-- Mỗi post được xem vài lần trong các tháng khác nhau
INSERT INTO PostViews (post_id, viewer_id, view_time, partition_key) VALUES
(1, 2, '2025-07-08 12:00:00', 202407),
(1, 3, '2025-07-08 13:00:00', 202407),
(2, 4, '2025-07-07 10:00:00', 202407),
(3, 5, '2025-06-15 09:00:00', 202406),
(4, 6, '2025-05-20 14:00:00', 202405),
(5, 7, '2025-04-10 18:00:00', 202404),
(6, 8, '2025-03-22 16:00:00', 202403),
(7, 9, '2025-02-28 08:00:00', 202402),
(8, 1, '2025-07-01 19:00:00', 202407),
(9, 2, '2025-07-03 20:00:00', 202407),
(10, 3, '2025-07-04 21:00:00', 202407),
(11, 4, '2025-07-05 10:00:00', 202407),
(12, 5, '2025-07-06 11:00:00', 202407),
(13, 6, '2025-07-07 12:00:00', 202407),
(14, 7, '2025-07-08 13:00:00', 202407),
(15, 8, '2025-07-08 14:00:00', 202407),
(16, 9, '2025-07-08 15:00:00', 202407),
(17, 10, '2025-07-08 16:00:00', 202407),
(18, 1, '2025-07-08 17:00:00', 202407),
(19, 2, '2025-07-08 18:00:00', 202407),
(20, 3, '2025-07-08 19:00:00', 202407);

-- bạn có thể copy và thêm nhiều rows nếu cần test nhiều

INSERT INTO Follows (follower_id, followee_id) VALUES
(1, 2), (2, 3), (3, 4), (4, 5),
(5, 6), (6, 7), (7, 8), (8, 9),
(9, 10), (10, 1);

INSERT INTO PostHashtags (post_id, hashtag) VALUES
(1, 'fitness'), (1, 'health'),
(2, 'fitness'), (2, 'motivation'),
(3, 'food'), (3, 'homemade'),
(4, 'tech'), (4, 'ai'),
(5, 'travel'), (5, 'nature'),
(6, 'pets'), (6, 'cute'),
(7, 'life'), (7, 'motivation');
-- bạn có thể fill tiếp tương tự
INSERT INTO PopularPostsDaily (post_id, report_date, total_likes, total_views) VALUES
(1, '2025-07-08', 5, 10),
(2, '2025-07-08', 8, 8),
(3, '2025-07-08', 2, 5),
(4, '2025-07-07', 4, 6),
(5, '2025-07-06', 7, 9);
