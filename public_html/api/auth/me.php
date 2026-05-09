<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$db = DB::getInstance();
$user = $db->fetchOne(
    "SELECT u.id, u.username, u.display_name, u.role, w.balance 
     FROM users u 
     LEFT JOIN wallets w ON u.id = w.user_id 
     WHERE u.id = ?",
    [Auth::userId()]
);

Response::success([
    'user' => $user,
    'wallet_balance' => (float)$user['balance']
]);
