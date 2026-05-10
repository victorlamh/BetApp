<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$scope = $_GET['scope'] ?? 'global'; // global, friends, mine
$userId = Auth::userId();
$db = DB::getInstance();

$sql = "SELECT b.*, u.display_name as creator_name, b.creator_user_id as creator_id 
        FROM bets b 
        JOIN users u ON b.creator_user_id = u.id 
        WHERE b.status IN ('live', 'locked', 'result_proposed')";

$params = [];

if ($scope === 'mine') {
    $sql = "SELECT b.*, u.display_name as creator_name, b.creator_user_id as creator_id 
            FROM bets b 
            JOIN users u ON b.creator_user_id = u.id 
            WHERE b.creator_user_id = ?";
    $params = [$userId];
} elseif ($scope === 'friends') {
    $sql .= " AND (b.creator_user_id IN (SELECT addressee_id FROM friendships WHERE requester_id = ? AND status = 'accepted')
              OR b.creator_user_id IN (SELECT requester_id FROM friendships WHERE addressee_id = ? AND status = 'accepted'))";
    $params = [$userId, $userId];
} else {
    // Global scope - already handled by the base WHERE clause
}

$sql .= " ORDER BY b.created_at DESC LIMIT 50";

file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] feed.php HIT. Scope: $scope, User: $userId\n", FILE_APPEND);
$bets = $db->fetchAll($sql, $params);
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] feed.php FOUND: " . count($bets) . " bets\n", FILE_APPEND);

// For each bet, fetch outcomes and cast types
foreach ($bets as &$bet) {
    $bet['id'] = (int)$bet['id'];
    $bet['creator_id'] = (int)$bet['creator_id'];
    $bet['creator_user_id'] = (int)$bet['creator_user_id'];
    $bet['is_boosted'] = (int)$bet['is_boosted'];
    $bet['proof_required'] = (int)$bet['proof_required'];
    
    $bet['outcomes'] = $db->fetchAll(
        "SELECT id, label, initial_coefficient, total_wagered FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order",
        [$bet['id']]
    );
    
    // Apply dynamic odds
    $bet['outcomes'] = Odds::calculate($bet['id'], $bet['outcomes']);
    
    foreach ($bet['outcomes'] as &$outcome) {
        $outcome['id'] = (int)$outcome['id'];
        // coefficient is already set as float by Odds::calculate
    }
    
    // Check if user has a wager
    $wager = $db->fetchOne(
        "SELECT * FROM wagers WHERE bet_id = ? AND user_id = ?",
        [$bet['id'], $userId]
    );
    
    if ($wager) {
        $wager['id'] = (int)$wager['id'];
        $wager['bet_id'] = (int)$wager['bet_id'];
        $wager['outcome_id'] = (int)$wager['outcome_id'];
        $wager['stake'] = (float)$wager['stake'];
        $wager['locked_coefficient'] = (float)$wager['locked_coefficient'];
        $wager['potential_return'] = (float)$wager['potential_return'];
        $bet['my_wager'] = $wager;
    } else {
        $bet['my_wager'] = null;
    }
}

Response::success($bets);
