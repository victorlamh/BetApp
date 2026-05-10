<?php
require_once __DIR__ . '/bootstrap.php';

$db = DB::getInstance();
$tables = ['users', 'follows', 'notifications', 'wallets', 'bets'];
$info = [];

foreach ($tables as $table) {
    try {
        $info[$table . '_schema'] = $db->fetchAll("DESCRIBE $table");
        if ($table === 'follows' || $table === 'notifications') {
            $info[$table . '_data'] = $db->fetchAll("SELECT * FROM $table ORDER BY id DESC LIMIT 20");
        }
    } catch (Exception $e) {
        $info[$table] = "Error: " . $e->getMessage();
    }
}

Response::success($info);
