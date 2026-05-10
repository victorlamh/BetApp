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

$bet['outcomes'] = $db->fetchAll(
    "SELECT id, label, initial_coefficient, total_wagered FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order",
    [$betId]
);

$bet['outcomes'] = Odds::calculate($betId, $bet['outcomes']);

$bet['my_wager'] = $db->fetchOne(
    "SELECT * FROM wagers WHERE bet_id = ? AND user_id = ?",
    [$betId, $userId]
);

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
