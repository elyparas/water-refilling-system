<?php
// Temporary diagnostic page - delete after use.
header('Content-Type: text/plain; charset=utf-8');
error_reporting(E_ALL); ini_set('display_errors', 1);
echo "PHP version: " . PHP_VERSION . "\n";
echo "pdo_mysql loaded: " . (extension_loaded('pdo_mysql') ? 'YES' : 'NO  <-- enable it in php.ini') . "\n\n";
try {
  $pdo = new PDO('mysql:host=localhost;charset=utf8mb4', 'root', '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
  echo "MySQL connection (root, no password): OK\n";
} catch (Exception $e) {
  echo "MySQL connection: FAILED\n" . $e->getMessage() . "\n";
  echo "\nFix: start MySQL in XAMPP. If your MySQL has a password or another port, edit api/db.php.\n";
  exit;
}
echo "Databases: " . implode(', ', $pdo->query("SHOW DATABASES")->fetchAll(PDO::FETCH_COLUMN)) . "\n\n";
try {
  $pdo->exec("USE water_station");
} catch (Exception $e) {
  echo "Database 'water_station' NOT FOUND. Import database/water_station.sql in phpMyAdmin.\n";
  exit;
}
echo "Database 'water_station': found\n";
foreach (['customer','staff','product','orders','order_item','payment','delivery','container','container_transaction','container_check'] as $t) {
  try { echo str_pad($t, 24) . $pdo->query("SELECT COUNT(*) FROM `$t`")->fetchColumn() . " rows\n"; }
  catch (Exception $e) { echo str_pad($t, 24) . "MISSING\n"; }
}
try { $pdo->query("SELECT 1 FROM v_order_balance LIMIT 1"); echo "\nview v_order_balance: OK\n"; }
catch (Exception $e) { echo "\nview v_order_balance: MISSING (import did not finish)\n"; }