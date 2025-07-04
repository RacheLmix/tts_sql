
-- Tạo cơ sở dữ liệu
DROP DATABASE IF EXISTS HotelBooking;
CREATE DATABASE HotelBooking;
USE HotelBooking;

-- Tạo bảng Rooms
CREATE TABLE Rooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    room_number VARCHAR(10) UNIQUE NOT NULL,
    type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'Available',
    price INT CHECK (price >= 0)
);

-- Tạo bảng Guests
CREATE TABLE Guests (
    guest_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100),
    phone VARCHAR(20)
);

-- Tạo bảng Bookings
CREATE TABLE Bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    guest_id INT,
    room_id INT,
    check_in DATE,
    check_out DATE,
    status VARCHAR(20) DEFAULT 'Pending',
    FOREIGN KEY (guest_id) REFERENCES Guests(guest_id),
    FOREIGN KEY (room_id) REFERENCES Rooms(room_id)
);

-- Tạo bảng Invoices
CREATE TABLE Invoices (
    invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT,
    total_amount INT,
    generated_date DATE,
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id)
);

-- Tạo Stored Procedure: MakeBooking
DELIMITER $$

CREATE PROCEDURE MakeBooking (
    IN p_guest_id INT,
    IN p_room_id INT,
    IN p_check_in DATE,
    IN p_check_out DATE
)
BEGIN
    DECLARE room_status VARCHAR(20);
    DECLARE count_overlap INT;

    SELECT status INTO room_status
    FROM Rooms
    WHERE room_id = p_room_id;

    IF room_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room is not available.';
    END IF;

    SELECT COUNT(*) INTO count_overlap
    FROM Bookings
    WHERE room_id = p_room_id
      AND status = 'Confirmed'
      AND (
          (p_check_in BETWEEN check_in AND check_out - INTERVAL 1 DAY) OR
          (p_check_out BETWEEN check_in + INTERVAL 1 DAY AND check_out) OR
          (p_check_in <= check_in AND p_check_out >= check_out)
      );

    IF count_overlap > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room already booked for selected dates.';
    END IF;

    INSERT INTO Bookings (guest_id, room_id, check_in, check_out, status)
    VALUES (p_guest_id, p_room_id, p_check_in, p_check_out, 'Confirmed');

    UPDATE Rooms
    SET status = 'Occupied'
    WHERE room_id = p_room_id;
END$$

DELIMITER ;

-- Tạo Trigger: after_booking_cancel
DELIMITER $$

CREATE TRIGGER after_booking_cancel
AFTER UPDATE ON Bookings
FOR EACH ROW
BEGIN
    IF NEW.status = 'Cancelled' THEN
        DECLARE future_confirmed_count INT;

        SELECT COUNT(*) INTO future_confirmed_count
        FROM Bookings
        WHERE room_id = NEW.room_id
          AND status = 'Confirmed'
          AND check_in > CURDATE();

        IF future_confirmed_count = 0 THEN
            UPDATE Rooms
            SET status = 'Available'
            WHERE room_id = NEW.room_id;
        END IF;
    END IF;
END$$

DELIMITER ;

-- Tạo Stored Procedure: GenerateInvoice
DELIMITER $$

CREATE PROCEDURE GenerateInvoice (
    IN p_booking_id INT
)
BEGIN
    DECLARE num_nights INT;
    DECLARE nightly_price INT;
    DECLARE total_amount INT;
    DECLARE room_id_val INT;
    DECLARE check_in_val DATE;
    DECLARE check_out_val DATE;

    SELECT room_id, check_in, check_out
    INTO room_id_val, check_in_val, check_out_val
    FROM Bookings
    WHERE booking_id = p_booking_id;

    SET num_nights = DATEDIFF(check_out_val, check_in_val);

    SELECT price INTO nightly_price
    FROM Rooms
    WHERE room_id = room_id_val;

    SET total_amount = num_nights * nightly_price;

    INSERT INTO Invoices (booking_id, total_amount, generated_date)
    VALUES (p_booking_id, total_amount, CURDATE());
END$$

DELIMITER ;

-- Dữ liệu mẫu
-- Thêm khách hàng mẫu
INSERT INTO Guests (full_name, phone) VALUES 
('Nguyễn Văn A', '0901234567'),
('Trần Thị B', '0902345678'),
('Lê Văn C', '0903456789');

-- Thêm phòng mẫu
INSERT INTO Rooms (room_number, type, price) VALUES 
('101', 'Standard', 500000),
('102', 'Standard', 500000),
('201', 'VIP', 800000),
('202', 'Suite', 1200000);

-- Đặt phòng hợp lệ (Confirmed)
-- Sẽ cập nhật trạng thái phòng thành 'Occupied'
CALL MakeBooking(1, 1, '2025-07-10', '2025-07-12');
CALL MakeBooking(2, 2, '2025-07-11', '2025-07-13');
CALL MakeBooking(3, 3, '2025-07-12', '2025-07-15');

-- Hủy 1 đặt phòng để test trigger
UPDATE Bookings SET status = 'Cancelled' WHERE booking_id = 2;

-- Tạo hóa đơn cho booking_id = 1
CALL GenerateInvoice(1);

-- Xem dữ liệu kết quả
SELECT * FROM Guests;
SELECT * FROM Rooms;
SELECT * FROM Bookings;
SELECT * FROM Invoices;

