<?php
require 'db.php';
$a = $_GET['action'] ?? 'list';
$d = input();

run(function ($pdo) use ($a, $d) {
  switch ($a) {
    case 'list':
      return $pdo->query("SELECT o.order_id, o.order_date, o.status, c.full_name AS customer,
                                 o.total_amount, b.balance
                          FROM orders o
                          JOIN customer c ON c.customer_id = o.customer_id
                          JOIN v_order_balance b ON b.order_id = o.order_id
                          ORDER BY o.order_id DESC")->fetchAll();

    case 'view':
      $id = (int)($_GET['id'] ?? 0);
      $st = $pdo->prepare("SELECT o.order_id, o.order_date, o.status, o.delivery_fee, o.container_deposit,
                                  o.total_amount, c.full_name AS customer, s.full_name AS staff
                           FROM orders o
                           JOIN customer c ON c.customer_id = o.customer_id
                           JOIN staff s ON s.staff_id = o.staff_id
                           WHERE o.order_id = ?");
      $st->execute([$id]);
      $order = $st->fetch();
      if (!$order) fail('Order not found.');
      $st = $pdo->prepare("SELECT p.product_name, i.quantity, i.unit_price
                           FROM order_item i JOIN product p ON p.product_id = i.product_id
                           WHERE i.order_id = ?");
      $st->execute([$id]);
      $items = $st->fetchAll();
      $st = $pdo->prepare("SELECT amount, method, payment_date FROM payment WHERE order_id = ?");
      $st->execute([$id]);
      return ['order' => $order, 'items' => $items, 'payments' => $st->fetchAll()];

    case 'add':
      if (empty($d['customer_id']) || empty($d['staff_id'])) fail('Please select a customer and staff.');
      $items = $d['items'] ?? [];
      if (!$items) fail('An order must have at least one item.');
      $fee = max(0, (float)($d['delivery_fee'] ?? 0));
      $dep = max(0, (float)($d['container_deposit'] ?? 0));
      $pdo->beginTransaction();
      $pdo->prepare("INSERT INTO orders (customer_id, staff_id, status, delivery_fee, container_deposit, total_amount)
                     VALUES (?,?,?,?,?,?)")
          ->execute([$d['customer_id'], $d['staff_id'], $d['status'] ?? 'Pending', $fee, $dep, $fee + $dep]);
      $id  = $pdo->lastInsertId();
      $ins = $pdo->prepare("INSERT INTO order_item (order_id, product_id, quantity, unit_price)
                            SELECT ?, product_id, ?, unit_price FROM product WHERE product_id = ?");
      foreach ($items as $it) {
        $q = (int)($it['quantity'] ?? 0);
        if ($q < 1) fail('Quantity must be at least 1.');
        $ins->execute([$id, $q, $it['product_id']]);
        if ($ins->rowCount() === 0) fail('Invalid product selected.');
      }
      $pdo->commit();            // trigger trg_orderitem_total computes the total
      return ['order_id' => $id];

    case 'status':
      $valid = ['Pending','Refilling','Ready for Pickup','Out for Delivery','Completed','Cancelled'];
      if (!in_array($d['status'] ?? '', $valid)) fail('Invalid status.');
      $pdo->prepare("UPDATE orders SET status = ? WHERE order_id = ?")->execute([$d['status'], $d['order_id']]);
      return ['ok' => true];
  }
  fail('Unknown action.');
});