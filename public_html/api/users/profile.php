<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$targetUserId = $_GET['id'] ?? Auth::userId();
$db = DB::getInstance();

$user = $db->fetchOne(
    "SELECT id, username, display_name, role, created_at FROM users WHERE id = ?",
    [$targetUserId]
);

if (!$user) {
    Response::notFound("User not found");
}

// Get basic stats
$stats = $db->fetchOne(
    "SELECT 
        (SELECT COUNT(*) FROM bets WHERE creator_user_id = ?) as bets_created,
        (SELECT COUNT(*) FROM wagers WHERE user_id = ?) as wagers_placed,
        (SELECT COUNT(*) FROM wagers WHERE user_id = ? AND status = 'won') as wagers_won
     FROM DUAL",
    [$targetUserId, $targetUserId, $targetUserId]
);

Response::success([
    'profile' => $user,
    'stats' => $stats
]);
