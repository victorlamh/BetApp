<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$db = DB::getInstance();

// Simple implementation for now: Rank by wallet balance
$leaderboard = $db->fetchAll(
    "SELECT u.id, u.username, u.display_name, w.balance 
     FROM users u 
     JOIN wallets w ON u.id = w.user_id 
     ORDER BY w.balance DESC 
     LIMIT 100"
);

Response::success($leaderboard);
