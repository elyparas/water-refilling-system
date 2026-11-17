<?php
require 'db.php';
$a = $_GET['action'] ?? 'list';
$d = input();

run(function ($pdo) use ($a, $d) {
  switch ($a) {
    case 'list':
      return [
        'stats' => [
          'collected' => (float)$pdo->query("SELECT IFNULL(SUM(amount),0) FROM payment")->fetchColumn(),
          'unpaid'    => (float)$pdo->query("SELECT IFNULL(SUM(b.balance),0) FROM v_order_balance b
                                             JOIN orders o ON o.order_id = b.order_id
                                             WHERE o.status <> 'Cancelled' AND b.balance > 0")->fetchColumn(),
        ],
        'rows' => $pdo->query("SELECT p.payment_id, p.order_id, b.customer, p.amount, p.method,
                                      p.payment_date, b.payment_status
                               FROM payment p JOIN v_order_balance b ON b.order_id = p.order_id
                               ORDER BY p.payment_id DESC")->fetchAll(),
      ];

    case 'open':
      return $pdo->query("SELECT b.order_id, b.customer, b.balance
                          FROM v_order_balance b JOIN orders o ON o.order_id = b.order_id
                          WHERE b.balance > 0 AND o.status <> 'Cancelled'
                          ORDER BY b.order_id DESC")->fetchAll();

    case 'add':
      if (!in_array($d['method'] ?? '', ['Cash', 'GCash', 'Bank Transfer'])) fail('Select a payment method.');
      $amt = round((float)($d['amount'] ?? 0), 2);
      if ($amt <= 0) fail('Amount must be greater than zero.');
      $q = $pdo->prepare("SELECT balance FROM v_order_balance WHERE order_id = ?");
      $q->execute([$d['order_id'] ?? 0]);
      $bal = $q->fetchColumn();
      if ($bal === false) fail('Order not found.');
      if ($amt > (float)$bal + 0.001) fail('Amount exceeds the remaining balance of ₱' . number_format($bal, 2) . '.');
      $pdo->prepare("INSERT INTO payment (order_id, amount, method) VALUES (?,?,?)")
          ->execute([$d['order_id'], $amt, $d['method']]);
      return ['balance' => round((float)$bal - $amt, 2)];
  }
  fail('Unknown action.');
});