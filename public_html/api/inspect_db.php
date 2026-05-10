<?php
require_once __DIR__ . '/bootstrap.php';

$db = DB::getInstance();
$tables = ['users', 'follows', 'notifications', 'wallets', 'bets'];
$info = [];

foreach ($tables as $table) {
    try {
        $info[$table] = $db->fetchAll("DESCRIBE $table");
    } catch (Exception $e) {
        $info[$table] = "Error: " . $e->getMessage();
    }
}

Response::success($info);
