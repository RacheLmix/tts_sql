-- XÓA CSDL nếu đã tồn tại
DROP DATABASE IF EXISTS DigitalBanking;
CREATE DATABASE DigitalBanking;
USE DigitalBanking;

-- 🔧 Tạo bảng Accounts (InnoDB)
CREATE TABLE Accounts (
    account_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    balance DECIMAL(15,2),
    status VARCHAR(20) CHECK (status IN ('Active', 'Frozen', 'Closed'))
) ENGINE = InnoDB;

-- 📋 Tạo bảng Transactions (InnoDB)
CREATE TABLE Transactions (
    txn_id INT AUTO_INCREMENT PRIMARY KEY,
    from_account INT,
    to_account INT,
    amount DECIMAL(15,2),
    txn_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20),
    FOREIGN KEY (from_account) REFERENCES Accounts(account_id),
    FOREIGN KEY (to_account) REFERENCES Accounts(account_id)
) ENGINE = InnoDB;

-- 📝 Tạo bảng AuditLogs (MyISAM)
CREATE TABLE TxnAuditLogs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    log_message TEXT,
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE = MyISAM;

-- 👥 Dữ liệu mẫu cho Accounts
INSERT INTO Accounts VALUES
(101, 'Nguyễn Văn A', 1000.00, 'Active'),
(102, 'Trần Thị B', 1500.00, 'Active'),
(103, 'Lê Văn C', 300.00, 'Frozen');

-- 👨‍👨‍👧‍👦 Tạo bảng Referrals (cho CTE đệ quy)
CREATE TABLE Referrals (
    referrer_id INT,
    referee_id INT
);

-- Dữ liệu mẫu cho Referrals
INSERT INTO Referrals VALUES
(1, 2),
(2, 3),
(2, 4),
(3, 5),
(4, 6),
(5, 7);

-- 🧠 Stored Procedure TransferMoney
DELIMITER $$

CREATE PROCEDURE TransferMoney (
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE from_balance DECIMAL(15,2);
    DECLARE from_status VARCHAR(20);
    DECLARE to_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO TxnAuditLogs(log_message) VALUES ('Transaction rolled back due to error');
    END;

    START TRANSACTION;

    -- Chống deadlock bằng cách khóa theo thứ tự ID
    IF p_from_account < p_to_account THEN
        SELECT balance, status INTO from_balance, from_status 
        FROM Accounts WHERE account_id = p_from_account FOR UPDATE;

        SELECT status INTO to_status 
        FROM Accounts WHERE account_id = p_to_account FOR UPDATE;
    ELSE
        SELECT status INTO to_status 
        FROM Accounts WHERE account_id = p_to_account FOR UPDATE;

        SELECT balance, status INTO from_balance, from_status 
        FROM Accounts WHERE account_id = p_from_account FOR UPDATE;
    END IF;

    IF from_status != 'Active' OR to_status != 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'One or both accounts not active';
    END IF;

    IF from_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
    END IF;

    UPDATE Accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
    UPDATE Accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

    INSERT INTO Transactions(from_account, to_account, amount, status)
    VALUES (p_from_account, p_to_account, p_amount, 'Success');

    INSERT INTO TxnAuditLogs(log_message)
    VALUES (CONCAT('Transferred ', p_amount, ' from ', p_from_account, ' to ', p_to_account));

    COMMIT;
END$$

DELIMITER ;

-- ✅ TEST Stored Procedure
-- CALL TransferMoney(101, 102, 200.00);

-- 🔍 MVCC TEST
-- Session 1:
-- SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- START TRANSACTION;
-- SELECT balance FROM Accounts WHERE account_id = 101;

-- Session 2:
-- CALL TransferMoney(101, 102, 100.00);

-- Session 1 tiếp:
-- SELECT balance FROM Accounts WHERE account_id = 101;
-- COMMIT;

-- 🧬 CTE đệ quy - xem toàn bộ cấp dưới của người dùng 1
WITH RECURSIVE ReferralTree AS (
    SELECT referrer_id, referee_id, 1 AS level
    FROM Referrals WHERE referrer_id = 1
    UNION ALL
    SELECT r.referrer_id, r.referee_id, rt.level + 1
    FROM Referrals r
    JOIN ReferralTree rt ON r.referrer_id = rt.referee_id
)
SELECT * FROM ReferralTree;

-- 📊 CTE phân tích giao dịch lớn hơn trung bình
WITH AvgTxn AS (
    SELECT AVG(amount) AS avg_amt FROM Transactions
),
LabeledTxns AS (
    SELECT txn_id, from_account, to_account, amount,
        CASE 
            WHEN amount > (SELECT avg_amt FROM AvgTxn) THEN 'High'
            WHEN amount = (SELECT avg_amt FROM AvgTxn) THEN 'Normal'
            ELSE 'Low'
        END AS txn_label
    FROM Transactions
)
SELECT * FROM LabeledTxns;
