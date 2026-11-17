DROP DATABASE IF EXISTS water_station;
CREATE DATABASE water_station;
USE water_station;

-- ===================== TABLES =====================
CREATE TABLE customer (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name   VARCHAR(100) NOT NULL,
  contact_no  VARCHAR(20)  NOT NULL,
  address     TEXT         NOT NULL
);

CREATE TABLE staff (
  staff_id   INT AUTO_INCREMENT PRIMARY KEY,
  full_name  VARCHAR(100) NOT NULL,
  role       VARCHAR(50)  NOT NULL,
  contact_no VARCHAR(20)  NOT NULL
);

CREATE TABLE product (
  product_id   INT AUTO_INCREMENT PRIMARY KEY,
  product_name VARCHAR(100) NOT NULL,
  category     VARCHAR(50)  NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE orders (
  order_id          INT AUTO_INCREMENT PRIMARY KEY,
  customer_id       INT NOT NULL,
  staff_id          INT NOT NULL,
  order_date        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status            VARCHAR(30) NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending','Refilling','Ready for Pickup','Out for Delivery','Completed','Cancelled')),
  delivery_fee      DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0),
  container_deposit DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (container_deposit >= 0),
  total_amount      DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  FOREIGN KEY (staff_id)    REFERENCES staff(staff_id)
);

CREATE TABLE order_item (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  product_id    INT NOT NULL,
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(product_id)
);

CREATE TABLE payment (
  payment_id   INT AUTO_INCREMENT PRIMARY KEY,
  order_id     INT NOT NULL,
  amount       DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  method       VARCHAR(30) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE delivery (
  delivery_id      INT AUTO_INCREMENT PRIMARY KEY,
  order_id         INT NOT NULL,
  staff_id         INT NOT NULL,
  delivery_address TEXT NOT NULL,
  delivery_date    DATETIME NOT NULL,
  delivery_status  VARCHAR(30) NOT NULL
    CHECK (delivery_status IN ('Out for Delivery','Delivered','Failed')),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

CREATE TABLE container (
  container_id      INT AUTO_INCREMENT PRIMARY KEY,
  customer_id       INT NOT NULL,
  label_mark        VARCHAR(50) UNIQUE NULL,
  size              VARCHAR(30) NOT NULL,
  current_condition VARCHAR(30) NOT NULL DEFAULT 'Good'
    CHECK (current_condition IN ('Good','Dirty','Cracked','Worn Out')),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
);

CREATE TABLE container_transaction (
  txn_id        INT AUTO_INCREMENT PRIMARY KEY,
  container_id  INT NOT NULL,
  customer_id   INT NOT NULL,
  txn_type      VARCHAR(30) NOT NULL CHECK (txn_type IN ('Borrow','Return','Exchange')),
  quantity      INT NOT NULL CHECK (quantity > 0),
  txn_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  return_status VARCHAR(30) NOT NULL CHECK (return_status IN ('Returned','Pending Return','Lost')),
  FOREIGN KEY (container_id) REFERENCES container(container_id),
  FOREIGN KEY (customer_id)  REFERENCES customer(customer_id)
);

CREATE TABLE container_check (
  check_id         INT AUTO_INCREMENT PRIMARY KEY,
  container_id     INT NOT NULL,
  order_id         INT NOT NULL,
  check_date       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  condition_result VARCHAR(50) NOT NULL,
  action_taken     VARCHAR(100) NULL,
  FOREIGN KEY (container_id) REFERENCES container(container_id),
  FOREIGN KEY (order_id)     REFERENCES orders(order_id)
);

-- ===================== TRIGGERS + PROCEDURES =====================
DELIMITER //

-- Trigger 1: keep orders.total_amount correct whenever an item is added
CREATE TRIGGER trg_orderitem_total
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
  UPDATE orders
  SET total_amount =
      (SELECT SUM(quantity * unit_price) FROM order_item WHERE order_id = NEW.order_id)
      + delivery_fee + container_deposit
  WHERE order_id = NEW.order_id;
END //

-- Trigger 2: a container cannot be returned without a prior Borrow record
CREATE TRIGGER trg_check_return
BEFORE INSERT ON container_transaction
FOR EACH ROW
BEGIN
  IF NEW.txn_type = 'Return' AND NOT EXISTS (
      SELECT 1 FROM container_transaction
      WHERE container_id = NEW.container_id
        AND customer_id  = NEW.customer_id
        AND txn_type     = 'Borrow') THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot return a container without a borrow record';
  END IF;
END //

-- Procedure 1: create an order (returns the new order_id)
CREATE PROCEDURE sp_create_order(
  IN p_customer_id INT, IN p_staff_id INT,
  IN p_delivery_fee DECIMAL(10,2), IN p_deposit DECIMAL(10,2))
BEGIN
  INSERT INTO orders (customer_id, staff_id, delivery_fee, container_deposit, total_amount)
  VALUES (p_customer_id, p_staff_id, p_delivery_fee, p_deposit, p_delivery_fee + p_deposit);
  SELECT LAST_INSERT_ID() AS new_order_id;
END //

-- Procedure 2: add an item at the current product price (trigger updates the total)
CREATE PROCEDURE sp_add_order_item(
  IN p_order_id INT, IN p_product_id INT, IN p_qty INT)
BEGIN
  INSERT INTO order_item (order_id, product_id, quantity, unit_price)
  SELECT p_order_id, product_id, p_qty, unit_price
  FROM product WHERE product_id = p_product_id;
END //

DELIMITER ;

-- ===================== SAMPLE DATA =====================
INSERT INTO customer (customer_id, full_name, contact_no, address) VALUES
(1, 'Maria Santos', '09661043321', 'Purok 6, Tagas'),
(2, 'Juan Dela Cruz', '09668196001', 'Purok 2, Tagas'),
(3, 'Ana Reyes', '09288908386', 'Purok 2, Tagas'),
(4, 'Jose Ramirez', '09459402654', 'Purok 2, Brgy. Kilicao'),
(5, 'Rosa Mendoza', '09285116155', 'Purok 5, Tagas'),
(6, 'Pedro Villanueva', '09390781618', 'Purok 3, Tagas'),
(7, 'Carmela Bautista', '09989593103', 'Purok 7, Tagas'),
(8, 'Ricardo Aquino', '09391316475', 'Purok 2, Brgy. Mabini'),
(9, 'Elena Navarro', '09395341928', 'Purok 6, Tagas'),
(10, 'Mario Castillo', '09282764835', 'Purok 7, Tagas'),
(11, 'Luzviminda Flores', '09980305641', 'Purok 2, Tagas'),
(12, 'Danilo Garcia', '09555376724', 'Purok 2, Brgy. Anislag'),
(13, 'Cristina Domingo', '09288849696', 'Purok 3, Tagas'),
(14, 'Eduardo Salazar', '09282871012', 'Purok 6, Tagas'),
(15, 'Marites Corpuz', '09286916697', 'Purok 5, Tagas'),
(16, 'Rodel Pascual', '09398018451', 'Purok 3, Brgy. Busay'),
(17, 'Lorna Soriano', '09452704828', 'Purok 1, Tagas'),
(18, 'Gerardo Mercado', '09984893252', 'Purok 5, Tagas'),
(19, 'Jessa Marie Dizon', '09988095701', 'Purok 3, Tagas'),
(20, 'Ronaldo Esteban', '09984303911', 'Purok 6, Brgy. Kilicao'),
(21, 'Teresita Alcantara', '09451822782', 'Purok 3, Tagas'),
(22, 'Arnel Francisco', '09559638346', 'Purok 6, Tagas'),
(23, 'Gloria Magsino', '09665787133', 'Purok 1, Tagas'),
(24, 'Nestor Valdez', '09390983930', 'Purok 1, Brgy. Mabini'),
(25, 'Imelda Tolentino', '09660310518', 'Purok 2, Tagas'),
(26, 'Benjie Cabrera', '09397382997', 'Purok 2, Tagas'),
(27, 'Shiela Mae Ocampo', '09987631165', 'Purok 4, Tagas'),
(28, 'Alfredo Manalo', '09457010651', 'Purok 2, Brgy. Anislag'),
(29, 'Divina Gracia Peralta', '09283872624', 'Purok 4, Tagas'),
(30, 'Randy Buenaventura', '09281781080', 'Purok 1, Tagas'),
(31, 'Norma De Leon', '09983267736', 'Purok 1, Tagas'),
(32, 'Felix Macaraeg', '09286064746', 'Purok 6, Brgy. Busay'),
(33, 'Josefina Ramos', '09668723430', 'Purok 5, Tagas'),
(34, 'Jun-Jun Abella', '09668050097', 'Purok 5, Tagas'),
(35, 'Analyn Cruz', '09988208121', 'Purok 5, Tagas'),
(36, 'Bernardo Sison', '09173619399', 'Purok 1, Brgy. Kilicao'),
(37, 'Liza Marasigan', '09551699854', 'Purok 2, Tagas'),
(38, 'Noel Quiambao', '09665346247', 'Purok 3, Tagas'),
(39, 'Rhea Anne Guevarra', '09981079911', 'Purok 5, Tagas'),
(40, 'Tomas Dimaano', '09288425135', 'Purok 3, Brgy. Mabini'),
(41, 'Vilma Hernandez', '09287849808', 'Purok 3, Tagas'),
(42, 'Dennis Alonzo', '09661241182', 'Purok 3, Tagas'),
(43, 'Cherry Ann Tabuena', '09399353487', 'Purok 3, Tagas'),
(44, 'Rey Orbiso', '09980164005', 'Purok 7, Brgy. Anislag'),
(45, 'Fe Almonte', '09284278680', 'Purok 1, Tagas'),
(46, 'Jonel Bernales', '09172805982', 'Purok 4, Tagas'),
(47, 'Marilou Gonzales', '09280450533', 'Purok 6, Tagas'),
(48, 'Allan Parreno', '09175869232', 'Purok 7, Brgy. Busay'),
(49, 'Edna Lopez', '09982602563', 'Purok 3, Tagas'),
(50, 'Gilbert Santiago', '09281607337', 'Purok 3, Tagas');

-- Staff (7)
INSERT INTO staff (staff_id, full_name, role, contact_no) VALUES
(1, 'Pedro Ramos', 'Cashier', '09451110001'),
(2, 'Luis Garcia', 'Delivery Rider', '09451110002'),
(3, 'Carla Mendoza', 'Cashier', '09451110003'),
(4, 'Rico Dela Pena', 'Delivery Rider', '09451110004'),
(5, 'Joel Navarro', 'Refill Attendant', '09451110005'),
(6, 'Anita Villareal', 'Manager', '09451110006'),
(7, 'Mark Anthony Sison', 'Delivery Rider', '09451110007');

-- Products (8)
INSERT INTO product (product_id, product_name, category, unit_price) VALUES
(1, 'Purified Refill (5-Gal)', 'Refill', 25.00),
(2, 'Alkaline Refill (5-Gal)', 'Refill', 35.00),
(3, 'Mineral Refill (5-Gal)', 'Refill', 30.00),
(4, 'New 5-Gal Round Container', 'Container', 180.00),
(5, 'New 5-Gal Slim Container', 'Container', 200.00),
(6, 'Container Cap', 'Accessory', 15.00),
(7, 'Faucet Pump Dispenser', 'Accessory', 120.00),
(8, 'Gallon Carrier Handle', 'Accessory', 25.00);

-- Orders (50)
INSERT INTO orders (order_id, customer_id, staff_id, order_date, status, delivery_fee, container_deposit, total_amount) VALUES
(1, 20, 1, NOW() - INTERVAL 687 HOUR, 'Completed', 20.00, 100.00, 220.00),
(2, 5, 3, NOW() - INTERVAL 674 HOUR, 'Completed', 30.00, 0.00, 240.00),
(3, 35, 3, NOW() - INTERVAL 658 HOUR, 'Completed', 20.00, 0.00, 145.00),
(4, 17, 1, NOW() - INTERVAL 644 HOUR, 'Completed', 30.00, 0.00, 240.00),
(5, 28, 6, NOW() - INTERVAL 634 HOUR, 'Completed', 20.00, 0.00, 115.00),
(6, 34, 6, NOW() - INTERVAL 621 HOUR, 'Completed', 30.00, 100.00, 345.00),
(7, 43, 3, NOW() - INTERVAL 606 HOUR, 'Completed', 20.00, 100.00, 270.00),
(8, 33, 3, NOW() - INTERVAL 593 HOUR, 'Completed', 20.00, 0.00, 245.00),
(9, 13, 3, NOW() - INTERVAL 579 HOUR, 'Completed', 20.00, 100.00, 180.00),
(10, 20, 3, NOW() - INTERVAL 564 HOUR, 'Completed', 20.00, 0.00, 90.00),
(11, 38, 6, NOW() - INTERVAL 551 HOUR, 'Completed', 20.00, 0.00, 160.00),
(12, 33, 3, NOW() - INTERVAL 537 HOUR, 'Completed', 20.00, 100.00, 195.00),
(13, 41, 6, NOW() - INTERVAL 520 HOUR, 'Completed', 20.00, 0.00, 230.00),
(14, 10, 1, NOW() - INTERVAL 504 HOUR, 'Completed', 20.00, 0.00, 50.00),
(15, 41, 6, NOW() - INTERVAL 491 HOUR, 'Completed', 30.00, 100.00, 270.00),
(16, 10, 6, NOW() - INTERVAL 481 HOUR, 'Completed', 20.00, 0.00, 120.00),
(17, 36, 1, NOW() - INTERVAL 462 HOUR, 'Completed', 20.00, 0.00, 230.00),
(18, 36, 6, NOW() - INTERVAL 450 HOUR, 'Completed', 20.00, 0.00, 170.00),
(19, 36, 3, NOW() - INTERVAL 435 HOUR, 'Completed', 30.00, 0.00, 135.00),
(20, 41, 3, NOW() - INTERVAL 424 HOUR, 'Ready for Pickup', 20.00, 100.00, 195.00),
(21, 46, 3, NOW() - INTERVAL 407 HOUR, 'Completed', 20.00, 0.00, 210.00),
(22, 15, 3, NOW() - INTERVAL 397 HOUR, 'Completed', 20.00, 100.00, 145.00),
(23, 22, 6, NOW() - INTERVAL 381 HOUR, 'Completed', 20.00, 0.00, 120.00),
(24, 50, 6, NOW() - INTERVAL 369 HOUR, 'Completed', 20.00, 0.00, 235.00),
(25, 49, 3, NOW() - INTERVAL 353 HOUR, 'Completed', 30.00, 100.00, 280.00),
(26, 15, 3, NOW() - INTERVAL 337 HOUR, 'Completed', 20.00, 0.00, 55.00),
(27, 43, 6, NOW() - INTERVAL 325 HOUR, 'Completed', 30.00, 0.00, 100.00),
(28, 35, 1, NOW() - INTERVAL 311 HOUR, 'Completed', 30.00, 0.00, 130.00),
(29, 30, 1, NOW() - INTERVAL 294 HOUR, 'Completed', 20.00, 0.00, 90.00),
(30, 22, 3, NOW() - INTERVAL 282 HOUR, 'Completed', 20.00, 0.00, 300.00),
(31, 23, 1, NOW() - INTERVAL 271 HOUR, 'Ready for Pickup', 20.00, 100.00, 145.00),
(32, 13, 1, NOW() - INTERVAL 256 HOUR, 'Completed', 20.00, 0.00, 120.00),
(33, 37, 1, NOW() - INTERVAL 241 HOUR, 'Completed', 30.00, 0.00, 100.00),
(34, 48, 6, NOW() - INTERVAL 224 HOUR, 'Completed', 20.00, 0.00, 170.00),
(35, 37, 6, NOW() - INTERVAL 213 HOUR, 'Completed', 20.00, 100.00, 145.00),
(36, 41, 1, NOW() - INTERVAL 196 HOUR, 'Completed', 30.00, 0.00, 180.00),
(37, 37, 1, NOW() - INTERVAL 184 HOUR, 'Completed', 30.00, 0.00, 145.00),
(38, 27, 3, NOW() - INTERVAL 168 HOUR, 'Ready for Pickup', 20.00, 0.00, 140.00),
(39, 28, 1, NOW() - INTERVAL 159 HOUR, 'Completed', 30.00, 100.00, 305.00),
(40, 35, 3, NOW() - INTERVAL 143 HOUR, 'Completed', 20.00, 100.00, 210.00),
(41, 16, 1, NOW() - INTERVAL 128 HOUR, 'Completed', 20.00, 0.00, 195.00),
(42, 25, 3, NOW() - INTERVAL 112 HOUR, 'Completed', 20.00, 0.00, 145.00),
(43, 22, 3, NOW() - INTERVAL 102 HOUR, 'Completed', 30.00, 0.00, 60.00),
(44, 13, 1, NOW() - INTERVAL 85 HOUR, 'Out for Delivery', 30.00, 0.00, 205.00),
(45, 45, 3, NOW() - INTERVAL 75 HOUR, 'Out for Delivery', 30.00, 0.00, 185.00),
(46, 26, 6, NOW() - INTERVAL 57 HOUR, 'Out for Delivery', 20.00, 100.00, 210.00),
(47, 34, 3, NOW() - INTERVAL 45 HOUR, 'Out for Delivery', 30.00, 0.00, 135.00),
(48, 18, 3, NOW() - INTERVAL 30 HOUR, 'Out for Delivery', 20.00, 0.00, 80.00),
(49, 48, 6, NOW() - INTERVAL 19 HOUR, 'Out for Delivery', 20.00, 0.00, 170.00),
(50, 47, 6, NOW() - INTERVAL 4 HOUR, 'Out for Delivery', 30.00, 0.00, 80.00);

-- Order items (63); trigger trg_orderitem_total recalculates each order total
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 4, 25.00),
(2, 2, 2, 6, 35.00),
(3, 3, 1, 5, 25.00),
(4, 4, 2, 6, 35.00),
(5, 5, 3, 2, 30.00),
(6, 5, 2, 1, 35.00),
(7, 6, 3, 6, 30.00),
(8, 6, 2, 1, 35.00),
(9, 7, 1, 6, 25.00),
(10, 8, 2, 6, 35.00),
(11, 8, 6, 1, 15.00),
(12, 9, 3, 2, 30.00),
(13, 10, 2, 2, 35.00),
(14, 11, 2, 4, 35.00),
(15, 12, 1, 3, 25.00),
(16, 13, 3, 3, 30.00),
(17, 13, 7, 1, 120.00),
(18, 14, 3, 1, 30.00),
(19, 15, 2, 4, 35.00),
(20, 16, 2, 2, 35.00),
(21, 16, 3, 1, 30.00),
(22, 17, 2, 6, 35.00),
(23, 18, 3, 5, 30.00),
(24, 19, 2, 3, 35.00),
(25, 20, 1, 3, 25.00),
(26, 21, 2, 5, 35.00),
(27, 21, 6, 1, 15.00),
(28, 22, 1, 1, 25.00),
(29, 23, 1, 4, 25.00),
(30, 24, 2, 4, 35.00),
(31, 24, 1, 3, 25.00),
(32, 25, 3, 5, 30.00),
(33, 26, 2, 1, 35.00),
(34, 27, 2, 2, 35.00),
(35, 28, 3, 1, 30.00),
(36, 28, 2, 2, 35.00),
(37, 29, 2, 2, 35.00),
(38, 30, 1, 4, 25.00),
(39, 30, 4, 1, 180.00),
(40, 31, 1, 1, 25.00),
(41, 32, 1, 4, 25.00),
(42, 33, 2, 2, 35.00),
(43, 34, 1, 5, 25.00),
(44, 34, 8, 1, 25.00),
(45, 35, 1, 1, 25.00),
(46, 36, 3, 5, 30.00),
(47, 37, 3, 3, 30.00),
(48, 37, 1, 1, 25.00),
(49, 38, 3, 4, 30.00),
(50, 39, 2, 5, 35.00),
(51, 40, 3, 3, 30.00),
(52, 41, 2, 5, 35.00),
(53, 42, 1, 4, 25.00),
(54, 42, 8, 1, 25.00),
(55, 43, 3, 1, 30.00),
(56, 44, 2, 5, 35.00),
(57, 45, 2, 1, 35.00),
(58, 45, 7, 1, 120.00),
(59, 46, 3, 3, 30.00),
(60, 47, 2, 3, 35.00),
(61, 48, 3, 2, 30.00),
(62, 49, 1, 6, 25.00),
(63, 50, 1, 2, 25.00);

-- Payments (50)
INSERT INTO payment (order_id, amount, payment_date, method) VALUES
(1, 220.00, NOW() - INTERVAL 687 HOUR, 'Cash'),
(2, 240.00, NOW() - INTERVAL 674 HOUR, 'Cash'),
(3, 145.00, NOW() - INTERVAL 658 HOUR, 'Cash'),
(4, 240.00, NOW() - INTERVAL 644 HOUR, 'Cash'),
(5, 69.00, NOW() - INTERVAL 634 HOUR, 'Bank Transfer'),
(5, 46.00, NOW() - INTERVAL 628 HOUR, 'GCash'),
(6, 345.00, NOW() - INTERVAL 621 HOUR, 'GCash'),
(7, 270.00, NOW() - INTERVAL 606 HOUR, 'Cash'),
(8, 245.00, NOW() - INTERVAL 593 HOUR, 'GCash'),
(9, 180.00, NOW() - INTERVAL 579 HOUR, 'Cash'),
(10, 90.00, NOW() - INTERVAL 564 HOUR, 'GCash'),
(11, 160.00, NOW() - INTERVAL 551 HOUR, 'GCash'),
(12, 117.00, NOW() - INTERVAL 537 HOUR, 'Cash'),
(12, 78.00, NOW() - INTERVAL 531 HOUR, 'Cash'),
(13, 230.00, NOW() - INTERVAL 520 HOUR, 'Cash'),
(14, 50.00, NOW() - INTERVAL 504 HOUR, 'Cash'),
(15, 270.00, NOW() - INTERVAL 491 HOUR, 'Bank Transfer'),
(16, 120.00, NOW() - INTERVAL 481 HOUR, 'Cash'),
(17, 230.00, NOW() - INTERVAL 462 HOUR, 'GCash'),
(18, 170.00, NOW() - INTERVAL 450 HOUR, 'Cash'),
(19, 135.00, NOW() - INTERVAL 435 HOUR, 'Cash'),
(20, 78.00, NOW() - INTERVAL 424 HOUR, 'GCash'),
(21, 210.00, NOW() - INTERVAL 407 HOUR, 'Cash'),
(22, 145.00, NOW() - INTERVAL 397 HOUR, 'Cash'),
(23, 120.00, NOW() - INTERVAL 381 HOUR, 'GCash'),
(24, 235.00, NOW() - INTERVAL 369 HOUR, 'Cash'),
(25, 280.00, NOW() - INTERVAL 353 HOUR, 'Bank Transfer'),
(26, 55.00, NOW() - INTERVAL 337 HOUR, 'Cash'),
(27, 100.00, NOW() - INTERVAL 325 HOUR, 'GCash'),
(28, 130.00, NOW() - INTERVAL 311 HOUR, 'GCash'),
(29, 90.00, NOW() - INTERVAL 294 HOUR, 'GCash'),
(30, 300.00, NOW() - INTERVAL 282 HOUR, 'Cash'),
(32, 120.00, NOW() - INTERVAL 256 HOUR, 'Cash'),
(33, 100.00, NOW() - INTERVAL 241 HOUR, 'Cash'),
(34, 170.00, NOW() - INTERVAL 224 HOUR, 'Cash'),
(35, 145.00, NOW() - INTERVAL 213 HOUR, 'GCash'),
(36, 180.00, NOW() - INTERVAL 196 HOUR, 'Bank Transfer'),
(37, 145.00, NOW() - INTERVAL 184 HOUR, 'Cash'),
(39, 305.00, NOW() - INTERVAL 159 HOUR, 'GCash'),
(40, 210.00, NOW() - INTERVAL 143 HOUR, 'GCash'),
(41, 195.00, NOW() - INTERVAL 128 HOUR, 'GCash'),
(42, 145.00, NOW() - INTERVAL 112 HOUR, 'Bank Transfer'),
(43, 60.00, NOW() - INTERVAL 102 HOUR, 'Cash'),
(44, 102.50, NOW() - INTERVAL 85 HOUR, 'Cash'),
(45, 92.50, NOW() - INTERVAL 75 HOUR, 'GCash'),
(46, 105.00, NOW() - INTERVAL 57 HOUR, 'Cash'),
(47, 67.50, NOW() - INTERVAL 45 HOUR, 'Cash'),
(48, 40.00, NOW() - INTERVAL 30 HOUR, 'Cash'),
(49, 85.00, NOW() - INTERVAL 19 HOUR, 'Cash'),
(50, 40.00, NOW() - INTERVAL 4 HOUR, 'Cash');

-- Deliveries (50)
INSERT INTO delivery (order_id, staff_id, delivery_address, delivery_date, delivery_status) VALUES
(1, 2, 'Purok 6, Brgy. Kilicao', NOW() - INTERVAL 685 HOUR, 'Delivered'),
(2, 2, 'Purok 5, Tagas', NOW() - INTERVAL 672 HOUR, 'Delivered'),
(3, 2, 'Purok 5, Tagas', NOW() - INTERVAL 656 HOUR, 'Delivered'),
(4, 2, 'Purok 1, Tagas', NOW() - INTERVAL 642 HOUR, 'Delivered'),
(5, 4, 'Purok 2, Brgy. Anislag', NOW() - INTERVAL 632 HOUR, 'Delivered'),
(6, 4, 'Purok 5, Tagas', NOW() - INTERVAL 619 HOUR, 'Delivered'),
(7, 2, 'Purok 3, Tagas', NOW() - INTERVAL 604 HOUR, 'Delivered'),
(8, 2, 'Purok 5, Tagas', NOW() - INTERVAL 591 HOUR, 'Delivered'),
(9, 2, 'Purok 3, Tagas', NOW() - INTERVAL 577 HOUR, 'Delivered'),
(10, 7, 'Purok 6, Brgy. Kilicao', NOW() - INTERVAL 562 HOUR, 'Delivered'),
(11, 2, 'Purok 3, Tagas', NOW() - INTERVAL 549 HOUR, 'Delivered'),
(12, 4, 'Purok 5, Tagas', NOW() - INTERVAL 535 HOUR, 'Delivered'),
(13, 4, 'Purok 3, Tagas', NOW() - INTERVAL 518 HOUR, 'Delivered'),
(14, 4, 'Purok 7, Tagas', NOW() - INTERVAL 502 HOUR, 'Delivered'),
(15, 7, 'Purok 3, Tagas', NOW() - INTERVAL 489 HOUR, 'Delivered'),
(16, 7, 'Purok 7, Tagas', NOW() - INTERVAL 479 HOUR, 'Delivered'),
(17, 7, 'Purok 1, Brgy. Kilicao', NOW() - INTERVAL 460 HOUR, 'Delivered'),
(18, 7, 'Purok 1, Brgy. Kilicao', NOW() - INTERVAL 448 HOUR, 'Delivered'),
(19, 4, 'Purok 1, Brgy. Kilicao', NOW() - INTERVAL 433 HOUR, 'Delivered'),
(20, 7, 'Purok 3, Tagas', NOW() - INTERVAL 422 HOUR, 'Failed'),
(21, 7, 'Purok 4, Tagas', NOW() - INTERVAL 405 HOUR, 'Delivered'),
(22, 7, 'Purok 5, Tagas', NOW() - INTERVAL 395 HOUR, 'Delivered'),
(23, 2, 'Purok 6, Tagas', NOW() - INTERVAL 379 HOUR, 'Delivered'),
(24, 4, 'Purok 3, Tagas', NOW() - INTERVAL 367 HOUR, 'Delivered'),
(25, 7, 'Purok 3, Tagas', NOW() - INTERVAL 351 HOUR, 'Delivered'),
(26, 2, 'Purok 5, Tagas', NOW() - INTERVAL 335 HOUR, 'Delivered'),
(27, 4, 'Purok 3, Tagas', NOW() - INTERVAL 323 HOUR, 'Delivered'),
(28, 7, 'Purok 5, Tagas', NOW() - INTERVAL 309 HOUR, 'Delivered'),
(29, 4, 'Purok 1, Tagas', NOW() - INTERVAL 292 HOUR, 'Delivered'),
(30, 4, 'Purok 6, Tagas', NOW() - INTERVAL 280 HOUR, 'Delivered'),
(31, 2, 'Purok 1, Tagas', NOW() - INTERVAL 269 HOUR, 'Failed'),
(32, 7, 'Purok 3, Tagas', NOW() - INTERVAL 254 HOUR, 'Delivered'),
(33, 4, 'Purok 2, Tagas', NOW() - INTERVAL 239 HOUR, 'Delivered'),
(34, 2, 'Purok 7, Brgy. Busay', NOW() - INTERVAL 222 HOUR, 'Delivered'),
(35, 4, 'Purok 2, Tagas', NOW() - INTERVAL 211 HOUR, 'Delivered'),
(36, 4, 'Purok 3, Tagas', NOW() - INTERVAL 194 HOUR, 'Delivered'),
(37, 2, 'Purok 2, Tagas', NOW() - INTERVAL 182 HOUR, 'Delivered'),
(38, 4, 'Purok 4, Tagas', NOW() - INTERVAL 166 HOUR, 'Failed'),
(39, 2, 'Purok 2, Brgy. Anislag', NOW() - INTERVAL 157 HOUR, 'Delivered'),
(40, 7, 'Purok 5, Tagas', NOW() - INTERVAL 141 HOUR, 'Delivered'),
(41, 4, 'Purok 3, Brgy. Busay', NOW() - INTERVAL 126 HOUR, 'Delivered'),
(42, 7, 'Purok 2, Tagas', NOW() - INTERVAL 110 HOUR, 'Delivered'),
(43, 7, 'Purok 6, Tagas', NOW() - INTERVAL 100 HOUR, 'Delivered'),
(44, 4, 'Purok 3, Tagas', NOW() - INTERVAL 83 HOUR, 'Out for Delivery'),
(45, 2, 'Purok 1, Tagas', NOW() - INTERVAL 73 HOUR, 'Out for Delivery'),
(46, 4, 'Purok 2, Tagas', NOW() - INTERVAL 55 HOUR, 'Out for Delivery'),
(47, 4, 'Purok 5, Tagas', NOW() - INTERVAL 43 HOUR, 'Out for Delivery'),
(48, 2, 'Purok 5, Tagas', NOW() - INTERVAL 28 HOUR, 'Out for Delivery'),
(49, 2, 'Purok 7, Brgy. Busay', NOW() - INTERVAL 17 HOUR, 'Out for Delivery'),
(50, 4, 'Purok 6, Tagas', NOW() - INTERVAL 2 HOUR, 'Out for Delivery');

-- Containers (50)
INSERT INTO container (container_id, customer_id, label_mark, size, current_condition) VALUES
(1, 1, 'MS-001', '5-Gallon Slim', 'Good'),
(2, 2, 'JC-002', '5-Gallon Slim', 'Good'),
(3, 3, 'AR-003', '5-Gallon Round', 'Good'),
(4, 4, 'JR-004', '5-Gallon Round', 'Good'),
(5, 5, 'RM-005', '5-Gallon Slim', 'Good'),
(6, 6, 'PV-006', '5-Gallon Round', 'Good'),
(7, 7, 'CB-007', '5-Gallon Round', 'Good'),
(8, 8, 'RA-008', '5-Gallon Round', 'Good'),
(9, 9, 'EN-009', '5-Gallon Slim', 'Good'),
(10, 10, 'MC-010', '5-Gallon Round', 'Cracked'),
(11, 11, 'LF-011', '5-Gallon Round', 'Good'),
(12, 12, 'DG-012', '5-Gallon Slim', 'Good'),
(13, 13, 'CD-013', '5-Gallon Round', 'Good'),
(14, 14, 'ES-014', '5-Gallon Round', 'Good'),
(15, 15, 'MC-015', '5-Gallon Round', 'Good'),
(16, 16, 'RP-016', '5-Gallon Slim', 'Cracked'),
(17, 17, 'LS-017', '5-Gallon Round', 'Good'),
(18, 18, 'GM-018', '5-Gallon Round', 'Good'),
(19, 19, 'JD-019', '5-Gallon Slim', 'Good'),
(20, 20, 'RE-020', '5-Gallon Round', 'Good'),
(21, 21, 'TA-021', '5-Gallon Slim', 'Good'),
(22, 22, 'AF-022', '5-Gallon Round', 'Good'),
(23, 23, 'GM-023', '5-Gallon Slim', 'Cracked'),
(24, 24, 'NV-024', '5-Gallon Slim', 'Good'),
(25, 25, 'IT-025', '5-Gallon Slim', 'Good'),
(26, 26, 'BC-026', '5-Gallon Slim', 'Dirty'),
(27, 27, 'SO-027', '5-Gallon Round', 'Good'),
(28, 28, 'AM-028', '5-Gallon Slim', 'Dirty'),
(29, 29, 'DP-029', '5-Gallon Slim', 'Worn Out'),
(30, 30, 'RB-030', '5-Gallon Slim', 'Good'),
(31, 31, 'NL-031', '5-Gallon Slim', 'Good'),
(32, 32, 'FM-032', '5-Gallon Slim', 'Worn Out'),
(33, 33, 'JR-033', '5-Gallon Round', 'Good'),
(34, 34, 'JA-034', '5-Gallon Slim', 'Good'),
(35, 35, 'AC-035', '5-Gallon Slim', 'Good'),
(36, 36, 'BS-036', '5-Gallon Round', 'Good'),
(37, 37, 'LM-037', '5-Gallon Slim', 'Cracked'),
(38, 38, 'NQ-038', '5-Gallon Round', 'Good'),
(39, 39, 'RG-039', '5-Gallon Round', 'Good'),
(40, 40, 'TD-040', '5-Gallon Round', 'Good'),
(41, 41, 'VH-041', '5-Gallon Slim', 'Good'),
(42, 42, 'DA-042', '5-Gallon Slim', 'Worn Out'),
(43, 43, 'CT-043', '5-Gallon Round', 'Good'),
(44, 44, 'RO-044', '5-Gallon Slim', 'Good'),
(45, 45, 'FA-045', '5-Gallon Round', 'Cracked'),
(46, 46, 'JB-046', '5-Gallon Slim', 'Good'),
(47, 47, 'MG-047', '5-Gallon Slim', 'Good'),
(48, 48, 'AP-048', '5-Gallon Slim', 'Good'),
(49, 49, 'EL-049', '5-Gallon Slim', 'Good'),
(50, 50, 'GS-050', '5-Gallon Slim', 'Good');

-- Container transactions (50); trigger blocks any Return without a prior Borrow
INSERT INTO container_transaction (container_id, customer_id, txn_type, quantity, txn_date, return_status) VALUES
(1, 1, 'Borrow', 1, NOW() - INTERVAL 682 HOUR, 'Pending Return'),
(2, 2, 'Borrow', 1, NOW() - INTERVAL 473 HOUR, 'Pending Return'),
(3, 3, 'Borrow', 1, NOW() - INTERVAL 711 HOUR, 'Pending Return'),
(4, 4, 'Borrow', 1, NOW() - INTERVAL 358 HOUR, 'Pending Return'),
(5, 5, 'Borrow', 1, NOW() - INTERVAL 539 HOUR, 'Pending Return'),
(6, 6, 'Borrow', 1, NOW() - INTERVAL 338 HOUR, 'Pending Return'),
(7, 7, 'Borrow', 1, NOW() - INTERVAL 372 HOUR, 'Lost'),
(8, 8, 'Borrow', 1, NOW() - INTERVAL 686 HOUR, 'Pending Return'),
(9, 9, 'Borrow', 1, NOW() - INTERVAL 415 HOUR, 'Pending Return'),
(10, 10, 'Borrow', 1, NOW() - INTERVAL 646 HOUR, 'Pending Return'),
(11, 11, 'Borrow', 1, NOW() - INTERVAL 670 HOUR, 'Pending Return'),
(12, 12, 'Borrow', 1, NOW() - INTERVAL 645 HOUR, 'Pending Return'),
(13, 13, 'Borrow', 1, NOW() - INTERVAL 503 HOUR, 'Pending Return'),
(14, 14, 'Borrow', 1, NOW() - INTERVAL 711 HOUR, 'Pending Return'),
(15, 15, 'Borrow', 1, NOW() - INTERVAL 585 HOUR, 'Pending Return'),
(16, 16, 'Borrow', 1, NOW() - INTERVAL 487 HOUR, 'Pending Return'),
(17, 17, 'Borrow', 1, NOW() - INTERVAL 346 HOUR, 'Pending Return'),
(18, 18, 'Borrow', 1, NOW() - INTERVAL 704 HOUR, 'Pending Return'),
(19, 19, 'Borrow', 1, NOW() - INTERVAL 502 HOUR, 'Pending Return'),
(20, 20, 'Borrow', 1, NOW() - INTERVAL 307 HOUR, 'Pending Return'),
(21, 21, 'Borrow', 1, NOW() - INTERVAL 435 HOUR, 'Lost'),
(22, 22, 'Borrow', 1, NOW() - INTERVAL 574 HOUR, 'Pending Return'),
(23, 23, 'Borrow', 1, NOW() - INTERVAL 363 HOUR, 'Pending Return'),
(24, 24, 'Borrow', 1, NOW() - INTERVAL 532 HOUR, 'Pending Return'),
(25, 25, 'Borrow', 1, NOW() - INTERVAL 488 HOUR, 'Pending Return'),
(26, 26, 'Borrow', 1, NOW() - INTERVAL 644 HOUR, 'Pending Return'),
(27, 27, 'Borrow', 1, NOW() - INTERVAL 683 HOUR, 'Pending Return'),
(28, 28, 'Borrow', 1, NOW() - INTERVAL 644 HOUR, 'Pending Return'),
(29, 29, 'Borrow', 1, NOW() - INTERVAL 434 HOUR, 'Pending Return'),
(30, 30, 'Borrow', 1, NOW() - INTERVAL 599 HOUR, 'Pending Return'),
(31, 31, 'Borrow', 1, NOW() - INTERVAL 495 HOUR, 'Pending Return'),
(32, 32, 'Borrow', 1, NOW() - INTERVAL 626 HOUR, 'Pending Return'),
(33, 33, 'Borrow', 1, NOW() - INTERVAL 490 HOUR, 'Lost'),
(34, 34, 'Borrow', 1, NOW() - INTERVAL 355 HOUR, 'Pending Return'),
(35, 35, 'Borrow', 1, NOW() - INTERVAL 645 HOUR, 'Pending Return'),
(1, 1, 'Return', 1, NOW() - INTERVAL 599 HOUR, 'Returned'),
(2, 2, 'Return', 1, NOW() - INTERVAL 329 HOUR, 'Returned'),
(3, 3, 'Return', 1, NOW() - INTERVAL 681 HOUR, 'Returned'),
(4, 4, 'Return', 1, NOW() - INTERVAL 176 HOUR, 'Returned'),
(5, 5, 'Return', 1, NOW() - INTERVAL 372 HOUR, 'Returned'),
(6, 6, 'Return', 1, NOW() - INTERVAL 231 HOUR, 'Returned'),
(8, 8, 'Return', 1, NOW() - INTERVAL 506 HOUR, 'Returned'),
(9, 9, 'Return', 1, NOW() - INTERVAL 335 HOUR, 'Returned'),
(10, 10, 'Return', 1, NOW() - INTERVAL 457 HOUR, 'Returned'),
(11, 11, 'Return', 1, NOW() - INTERVAL 630 HOUR, 'Returned'),
(12, 12, 'Return', 1, NOW() - INTERVAL 459 HOUR, 'Returned'),
(13, 13, 'Return', 1, NOW() - INTERVAL 361 HOUR, 'Returned'),
(14, 14, 'Return', 1, NOW() - INTERVAL 610 HOUR, 'Returned'),
(15, 15, 'Return', 1, NOW() - INTERVAL 395 HOUR, 'Returned'),
(16, 16, 'Return', 1, NOW() - INTERVAL 359 HOUR, 'Returned');

-- Container checks (50)
INSERT INTO container_check (container_id, order_id, check_date, condition_result, action_taken) VALUES
(20, 1, NOW() - INTERVAL 687 HOUR, 'Clean/Approved', 'Accepted'),
(5, 2, NOW() - INTERVAL 674 HOUR, 'Clean/Approved', 'Accepted'),
(35, 3, NOW() - INTERVAL 658 HOUR, 'Clean/Approved', 'Accepted'),
(17, 4, NOW() - INTERVAL 644 HOUR, 'Clean/Approved', 'Accepted'),
(28, 5, NOW() - INTERVAL 634 HOUR, 'Clean/Approved', 'Accepted'),
(34, 6, NOW() - INTERVAL 621 HOUR, 'Needs Sanitization', 'Sanitized'),
(43, 7, NOW() - INTERVAL 606 HOUR, 'Clean/Approved', 'Accepted'),
(33, 8, NOW() - INTERVAL 593 HOUR, 'Clean/Approved', 'Accepted'),
(13, 9, NOW() - INTERVAL 579 HOUR, 'Clean/Approved', 'Accepted'),
(20, 10, NOW() - INTERVAL 564 HOUR, 'Clean/Approved', 'Accepted'),
(38, 11, NOW() - INTERVAL 551 HOUR, 'Clean/Approved', 'Accepted'),
(33, 12, NOW() - INTERVAL 537 HOUR, 'Clean/Approved', 'Accepted'),
(41, 13, NOW() - INTERVAL 520 HOUR, 'Clean/Approved', 'Accepted'),
(10, 14, NOW() - INTERVAL 504 HOUR, 'Clean/Approved', 'Accepted'),
(41, 15, NOW() - INTERVAL 491 HOUR, 'Clean/Approved', 'Accepted'),
(10, 16, NOW() - INTERVAL 481 HOUR, 'Damaged/Rejected', 'Rejected - customer notified'),
(36, 17, NOW() - INTERVAL 462 HOUR, 'Clean/Approved', 'Accepted'),
(36, 18, NOW() - INTERVAL 450 HOUR, 'Needs Sanitization', 'Sent for sanitizing'),
(36, 19, NOW() - INTERVAL 435 HOUR, 'Clean/Approved', 'Accepted'),
(41, 20, NOW() - INTERVAL 424 HOUR, 'Needs Sanitization', 'Sanitized'),
(46, 21, NOW() - INTERVAL 407 HOUR, 'Clean/Approved', 'Accepted'),
(15, 22, NOW() - INTERVAL 397 HOUR, 'Clean/Approved', 'Accepted'),
(22, 23, NOW() - INTERVAL 381 HOUR, 'Clean/Approved', 'Accepted'),
(50, 24, NOW() - INTERVAL 369 HOUR, 'Clean/Approved', 'Accepted'),
(49, 25, NOW() - INTERVAL 353 HOUR, 'Clean/Approved', 'Accepted'),
(15, 26, NOW() - INTERVAL 337 HOUR, 'Clean/Approved', 'Accepted'),
(43, 27, NOW() - INTERVAL 325 HOUR, 'Clean/Approved', 'Accepted'),
(35, 28, NOW() - INTERVAL 311 HOUR, 'Clean/Approved', 'Accepted'),
(30, 29, NOW() - INTERVAL 294 HOUR, 'Clean/Approved', 'Accepted'),
(22, 30, NOW() - INTERVAL 282 HOUR, 'Clean/Approved', 'Accepted'),
(23, 31, NOW() - INTERVAL 271 HOUR, 'Damaged/Rejected', 'Rejected - customer notified'),
(13, 32, NOW() - INTERVAL 256 HOUR, 'Damaged/Rejected', 'Rejected - customer notified'),
(37, 33, NOW() - INTERVAL 241 HOUR, 'Clean/Approved', 'Accepted'),
(48, 34, NOW() - INTERVAL 224 HOUR, 'Clean/Approved', 'Accepted'),
(37, 35, NOW() - INTERVAL 213 HOUR, 'Clean/Approved', 'Accepted'),
(41, 36, NOW() - INTERVAL 196 HOUR, 'Clean/Approved', 'Accepted'),
(37, 37, NOW() - INTERVAL 184 HOUR, 'Damaged/Rejected', 'Replaced'),
(27, 38, NOW() - INTERVAL 168 HOUR, 'Clean/Approved', 'Accepted'),
(28, 39, NOW() - INTERVAL 159 HOUR, 'Needs Sanitization', 'Sent for sanitizing'),
(35, 40, NOW() - INTERVAL 143 HOUR, 'Clean/Approved', 'Accepted'),
(16, 41, NOW() - INTERVAL 128 HOUR, 'Damaged/Rejected', 'Replaced'),
(25, 42, NOW() - INTERVAL 112 HOUR, 'Clean/Approved', 'Accepted'),
(22, 43, NOW() - INTERVAL 102 HOUR, 'Clean/Approved', 'Accepted'),
(13, 44, NOW() - INTERVAL 85 HOUR, 'Clean/Approved', 'Accepted'),
(45, 45, NOW() - INTERVAL 75 HOUR, 'Damaged/Rejected', 'Rejected - customer notified'),
(26, 46, NOW() - INTERVAL 57 HOUR, 'Needs Sanitization', 'Sent for sanitizing'),
(34, 47, NOW() - INTERVAL 45 HOUR, 'Clean/Approved', 'Accepted'),
(18, 48, NOW() - INTERVAL 30 HOUR, 'Clean/Approved', 'Accepted'),
(48, 49, NOW() - INTERVAL 19 HOUR, 'Clean/Approved', 'Accepted'),
(47, 50, NOW() - INTERVAL 4 HOUR, 'Clean/Approved', 'Accepted');

-- ===================== VIEW =====================
-- Order balance = total amount - payments received
CREATE VIEW v_order_balance AS
SELECT o.order_id, c.full_name AS customer, o.total_amount,
       IFNULL(SUM(p.amount), 0) AS total_paid,
       o.total_amount - IFNULL(SUM(p.amount), 0) AS balance,
       CASE WHEN o.total_amount - IFNULL(SUM(p.amount), 0) <= 0
            THEN 'Fully Paid' ELSE 'Unpaid' END AS payment_status
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
LEFT JOIN payment p ON p.order_id = o.order_id
GROUP BY o.order_id, c.full_name, o.total_amount;

-- ===================== REPORTS =====================
-- 1. Daily sales
SELECT DATE(payment_date) AS sales_date, SUM(amount) AS total_sales
FROM payment
GROUP BY DATE(payment_date)
ORDER BY sales_date DESC;

-- 2. Pending delivery requests
SELECT d.delivery_id, d.order_id, c.full_name AS customer,
       d.delivery_address, d.delivery_date, d.delivery_status
FROM delivery d
JOIN orders o   ON o.order_id = d.order_id
JOIN customer c ON c.customer_id = o.customer_id
WHERE d.delivery_status = 'Out for Delivery';

-- 3. Customer order history
SELECT c.full_name, o.order_id, o.order_date, o.status, o.total_amount
FROM customer c
JOIN orders o ON o.customer_id = c.customer_id
ORDER BY c.full_name, o.order_date DESC;

-- 4. Container conditions
SELECT ct.label_mark, c.full_name AS owner, ct.size, ct.current_condition,
       (SELECT cc.condition_result FROM container_check cc
        WHERE cc.container_id = ct.container_id
        ORDER BY cc.check_date DESC LIMIT 1) AS last_check_result
FROM container ct
JOIN customer c ON c.customer_id = ct.customer_id;

-- 5. Unpaid balances
SELECT * FROM v_order_balance WHERE balance > 0;

-- ===================== TEST QUERIES =====================
-- Row counts (should show 50 for each main table)
SELECT 'customer' AS table_name, COUNT(*) AS total_rows FROM customer
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'delivery', COUNT(*) FROM delivery
UNION ALL SELECT 'container', COUNT(*) FROM container
UNION ALL SELECT 'container_transaction', COUNT(*) FROM container_transaction
UNION ALL SELECT 'container_check', COUNT(*) FROM container_check;
