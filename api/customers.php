<?php
require 'db.php';

function clean($d) {
  $name  = trim($d['full_name'] ?? '');
  $phone = preg_replace('/\s+/', '', $d['contact_no'] ?? '');
  $addr  = trim($d['address'] ?? '');
  if ($name === '' || $phone === '' || $addr === '') fail('Please fill in all fields.');
  if (!preg_match('/^(09|\+639)\d{9}$/', $phone)) fail('Enter a valid mobile number, e.g. 09171234567.');
  return [$name, $phone, $addr];
}

$a = $_GET['action'] ?? 'list';
$d = input();

run(function ($pdo) use ($a, $d) {
  switch ($a) {
    case 'list':
      return $pdo->query("SELECT * FROM customer ORDER BY customer_id DESC")->fetchAll();
    case 'add':
      [$n, $c, $ad] = clean($d);
      $pdo->prepare("INSERT INTO customer (full_name, contact_no, address) VALUES (?,?,?)")->execute([$n, $c, $ad]);
      return ['ok' => true];
    case 'update':
      [$n, $c, $ad] = clean($d);
      $pdo->prepare("UPDATE customer SET full_name=?, contact_no=?, address=? WHERE customer_id=?")
          ->execute([$n, $c, $ad, $d['customer_id']]);
      return ['ok' => true];
    case 'delete':
      $pdo->prepare("DELETE FROM customer WHERE customer_id=?")->execute([$d['customer_id']]);
      return ['ok' => true];
  }
  fail('Unknown action.');
});