<?php
require 'db.php';
$a = $_GET['action'] ?? 'list';
$d = input();

run(function ($pdo) use ($a, $d) {
  switch ($a) {
    case 'list':
      return $pdo->query("SELECT d.delivery_id, d.order_id, c.full_name AS customer, s.full_name AS rider,
                                 d.delivery_address, d.delivery_date, d.delivery_status
                          FROM delivery d
                          JOIN orders o   ON o.order_id = d.order_id
                          JOIN customer c ON c.customer_id = o.customer_id
                          JOIN staff s    ON s.staff_id = d.staff_id
                          ORDER BY d.delivery_id DESC")->fetchAll();

    case 'add':
      $addr = trim($d['delivery_address'] ?? '');
      $ts   = strtotime($d['delivery_date'] ?? '');
      if (empty($d['order_id']) || empty($d['staff_id']) || $addr === '' || !$ts) fail('Please fill in all fields.');
      $chk = $pdo->prepare("SELECT COUNT(*) FROM delivery WHERE order_id = ? AND delivery_status = 'Out for Delivery'");
      $chk->execute([$d['order_id']]);
      if ($chk->fetchColumn() > 0) fail('This order already has an active delivery.');
      $pdo->beginTransaction();
      $pdo->prepare("INSERT INTO delivery (order_id, staff_id, delivery_address, delivery_date, delivery_status)
                     VALUES (?,?,?,?, 'Out for Delivery')")
          ->execute([$d['order_id'], $d['staff_id'], $addr, date('Y-m-d H:i:s', $ts)]);
      $pdo->prepare("UPDATE orders SET status = 'Out for Delivery' WHERE order_id = ?")->execute([$d['order_id']]);
      $pdo->commit();
      return ['ok' => true];

    case 'status':
      if (!in_array($d['status'] ?? '', ['Delivered', 'Failed'])) fail('Invalid status.');
      $pdo->beginTransaction();
      $pdo->prepare("UPDATE delivery SET delivery_status = ? WHERE delivery_id = ?")
          ->execute([$d['status'], $d['delivery_id']]);
      if ($d['status'] === 'Delivered') {
        $pdo->prepare("UPDATE orders SET status = 'Completed'
                       WHERE order_id = (SELECT order_id FROM delivery WHERE delivery_id = ?)")
            ->execute([$d['delivery_id']]);
      }
      $pdo->commit();
      return ['ok' => true];

    case 'delete':
      $pdo->prepare("DELETE FROM delivery WHERE delivery_id = ?")->execute([$d['delivery_id']]);
      return ['ok' => true];
  }
  fail('Unknown action.');
});