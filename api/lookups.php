<?php
require 'db.php';
run(function ($pdo) {
  return [
    'customers'  => $pdo->query("SELECT customer_id, full_name, address FROM customer ORDER BY full_name")->fetchAll(),
    'staff'      => $pdo->query("SELECT staff_id, full_name, role FROM staff ORDER BY full_name")->fetchAll(),
    'products'   => $pdo->query("SELECT product_id, product_name, unit_price FROM product ORDER BY product_name")->fetchAll(),
    'containers' => $pdo->query("SELECT ct.container_id, ct.label_mark, c.full_name AS owner
                                 FROM container ct JOIN customer c ON c.customer_id = ct.customer_id
                                 ORDER BY ct.container_id")->fetchAll(),
    'orders'     => $pdo->query("SELECT o.order_id, o.status, c.full_name, c.address
                                 FROM orders o JOIN customer c ON c.customer_id = o.customer_id
                                 WHERE o.status <> 'Cancelled' ORDER BY o.order_id DESC")->fetchAll(),
  ];
});