<?php
require 'db.php';
$a = $_GET['action'] ?? 'list';
$d = input();

run(function ($pdo) use ($a, $d) {
  switch ($a) {
    case 'list':
      return $pdo->query("SELECT ct.container_id, ct.label_mark, ct.size, ct.current_condition,
                                 c.full_name AS owner,
                                 (SELECT t.return_status FROM container_transaction t
                                  WHERE t.container_id = ct.container_id
                                  ORDER BY t.txn_date DESC, t.txn_id DESC LIMIT 1) AS return_status
                          FROM container ct JOIN customer c ON c.customer_id = ct.customer_id
                          ORDER BY ct.container_id DESC")->fetchAll();

    case 'add':
      $label = trim($d['label_mark'] ?? '');
      if (empty($d['customer_id']) || empty($d['size'])) fail('Please fill in all required fields.');
      if ($label !== '') {
        $q = $pdo->prepare("SELECT COUNT(*) FROM container WHERE label_mark = ?");
        $q->execute([$label]);
        if ($q->fetchColumn() > 0) fail("The label \"$label\" is already used by another container.");
      }
      $pdo->prepare("INSERT INTO container (customer_id, label_mark, size, current_condition) VALUES (?,?,?,?)")
          ->execute([$d['customer_id'], $label === '' ? null : $label, $d['size'], $d['current_condition'] ?? 'Good']);
      return ['ok' => true];

    case 'update':
      $pdo->prepare("UPDATE container SET current_condition = ? WHERE container_id = ?")
          ->execute([$d['current_condition'], $d['container_id']]);
      return ['ok' => true];

    case 'delete':
      $pdo->prepare("DELETE FROM container WHERE container_id = ?")->execute([$d['container_id']]);
      return ['ok' => true];

    case 'check':
      $map = ['Clean/Approved' => 'Good', 'Needs Sanitization' => 'Dirty', 'Damaged/Rejected' => 'Cracked'];
      if (!isset($map[$d['condition_result'] ?? ''])) fail('Invalid check result.');
      $action = trim($d['action_taken'] ?? '');
      $pdo->beginTransaction();
      $pdo->prepare("INSERT INTO container_check (container_id, order_id, condition_result, action_taken) VALUES (?,?,?,?)")
          ->execute([$d['container_id'], $d['order_id'], $d['condition_result'], $action === '' ? null : $action]);
      $pdo->prepare("UPDATE container SET current_condition = ? WHERE container_id = ?")
          ->execute([$map[$d['condition_result']], $d['container_id']]);
      $pdo->commit();
      return ['ok' => true];

    case 'txn':
      $map = ['Borrow' => 'Pending Return', 'Return' => 'Returned', 'Exchange' => 'Returned'];
      if (!isset($map[$d['txn_type'] ?? ''])) fail('Invalid transaction type.');
      $q = $pdo->prepare("SELECT customer_id FROM container WHERE container_id = ?");
      $q->execute([$d['container_id']]);
      $owner = $q->fetchColumn();
      if (!$owner) fail('Container not found.');
      $pdo->prepare("INSERT INTO container_transaction (container_id, customer_id, txn_type, quantity, return_status)
                     VALUES (?,?,?,?,?)")
          ->execute([$d['container_id'], $owner, $d['txn_type'], max(1, (int)($d['quantity'] ?? 1)), $map[$d['txn_type']]]);
      return ['ok' => true];     // trigger blocks a Return with no prior Borrow
  }
  fail('Unknown action.');
});