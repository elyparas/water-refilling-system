<?php
require 'db.php';
run(function ($pdo) {
  return [
    'sales'   => (float)$pdo->query("SELECT IFNULL(SUM(amount),0) FROM payment WHERE DATE(payment_date) = CURDATE()")->fetchColumn(),
    'orders'  => (int)$pdo->query("SELECT COUNT(*) FROM orders WHERE DATE(order_date) = CURDATE()")->fetchColumn(),
    'pending' => (int)$pdo->query("SELECT COUNT(*) FROM delivery WHERE delivery_status = 'Out for Delivery'")->fetchColumn(),
    'damaged' => (int)$pdo->query("SELECT COUNT(*) FROM container WHERE current_condition <> 'Good'")->fetchColumn(),
    'recent'  => $pdo->query("SELECT o.order_id, c.full_name AS customer, o.total_amount, o.status
                              FROM orders o JOIN customer c ON c.customer_id = o.customer_id
                              ORDER BY o.order_id DESC LIMIT 5")->fetchAll(),
    'alerts'  => $pdo->query("SELECT ct.label_mark, ct.container_id, c.full_name AS owner, ct.current_condition
                              FROM container ct JOIN customer c ON c.customer_id = ct.customer_id
                              WHERE ct.current_condition <> 'Good' LIMIT 5")->fetchAll(),
  ];
});