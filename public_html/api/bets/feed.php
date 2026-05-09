<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$scope = $_GET['scope'] ?? 'global'; // global, friends, mine
$userId = Auth::userId();
$db = DB::getInstance();

$sql = "SELECT b.*, u.display_name as creator_name 
        FROM bets b 
        JOIN users u ON b.creator_user_id = u.id 
        WHERE b.status IN ('live', 'locked', 'result_proposed')";

$params = [];

if ($scope === 'mine') {
    $sql = "SELECT b.*, u.display_name as creator_name 
            FROM bets b 
            JOIN users u ON b.creator_user_id = u.id 
            WHERE b.creator_user_id = ?";
    $params = [$userId];
} elseif ($scope === 'friends') {
    $sql .= " AND (b.creator_user_id IN (SELECT addressee_id FROM friendships WHERE requester_id = ? AND status = 'accepted')
              OR b.creator_user_id IN (SELECT requester_id FROM friendships WHERE addressee_id = ? AND status = 'accepted'))";
    $params = [$userId, $userId];
}

$sql .= " ORDER BY b.created_at DESC LIMIT 50";

$bets = $db->fetchAll($sql, $params);

// For each bet, fetch outcomes
foreach ($bets as &$bet) {
    $bet['outcomes'] = $db->fetchAll(
        "SELECT id, label, coefficient FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order",
        [$bet['id']]
    );
    
    // Check if user has a wager
    $wager = $db->fetchOne(
        "SELECT * FROM wagers WHERE bet_id = ? AND user_id = ?",
        [$bet['id'], $userId]
    );
    $bet['my_wager'] = $wager;
}

Response::success($bets);
