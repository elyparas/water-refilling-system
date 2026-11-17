<?php
header('Content-Type: application/json');

try {
  $pdo = new PDO('mysql:host=localhost;dbname=water_station;charset=utf8mb4', 'root', '', [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
} catch (Exception $e) {
  http_response_code(500);
  echo json_encode(['error' => 'Cannot connect to the database. Is MySQL running?']);
  exit;
}

class ApiError extends Exception {}

function input() { return json_decode(file_get_contents('php://input'), true) ?? []; }
function fail($msg) { throw new ApiError($msg); }

function friendly($e) {
  $code = $e->errorInfo[1] ?? 0;
  $msg  = $e->errorInfo[2] ?? '';
  if ($code == 1644) return $msg;                       // our trigger messages
  if ($code == 1062) return 'That value already exists.';
  if ($code == 1451) return 'This record is linked to other records and cannot be deleted.';
  if ($code == 1452) return 'A linked record was not found.';
  if ($code == 4025 || $code == 3819) return 'A value is not allowed by the database rules.';
  return 'Database error. Please try again.';
}

function run($fn) {
  global $pdo;
  try {
    echo json_encode($fn($pdo));
  } catch (ApiError $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);
  } catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(400);
    echo json_encode(['error' => friendly($e)]);
  }
}