<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$betId = $_GET['id'] ?? null;
if (!$betId) Response::error("Bet ID required");

$db = DB::getInstance();
$userId = Auth::userId();

$bet = $db->fetchOne(
    "SELECT b.*, u.display_name as creator_name 
     FROM bets b 
     JOIN users u ON b.creator_user_id = u.id 
     WHERE b.id = ?",
    [$betId]
);

if (!$bet) Response::notFound("Bet not found");

// Cast numeric types for Swift
$bet['id'] = (int)$bet['id'];
$bet['creator_user_id'] = (int)$bet['creator_user_id'];
$bet['is_boosted'] = (int)$bet['is_boosted'];
$bet['proof_required'] = (int)$bet['proof_required'];
if (isset($bet['result_outcome_id'])) $bet['result_outcome_id'] = (int)$bet['result_outcome_id'];

$bet['outcomes'] = $db->fetchAll(
    "SELECT id, label, initial_coefficient, total_wagered FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order",
    [$betId]
);

$bet['outcomes'] = Odds::calculate($betId, $bet['outcomes']);
foreach ($bet['outcomes'] as &$outcome) {
    $outcome['id'] = (int)$outcome['id'];
}

$wager = $db->fetchOne(
    "SELECT * FROM wagers WHERE bet_id = ? AND user_id = ?",
    [$betId, $userId]
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

// If result proposed, fetch proposal and votes
if ($bet['status'] === 'result_proposed') {
    $bet['proposal'] = $db->fetchOne(
        "SELECT rp.*, bo.label as winning_label 
         FROM result_proposals rp 
         JOIN bet_outcomes bo ON rp.winning_outcome_id = bo.id 
         WHERE rp.bet_id = ?",
        [$betId]
    );
    
    $bet['votes'] = $db->fetchAll(
        "SELECT vote, COUNT(*) as count FROM validation_votes WHERE bet_id = ? GROUP BY vote",
        [$betId]
    );
    
    $bet['my_vote'] = $db->fetchOne(
        "SELECT vote FROM validation_votes WHERE bet_id = ? AND user_id = ?",
        [$betId, $userId]
    );
}

Response::success($bet);
