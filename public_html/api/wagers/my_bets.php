<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();
$userId = Auth::userId();
$db = DB::getInstance();

$wagers = $db->fetchAll(
    "SELECT w.*, b.title, bo.label as outcome_label, b.status as bet_status
     FROM wagers w
     JOIN bets b ON w.bet_id = b.id
     JOIN bet_outcomes bo ON w.outcome_id = bo.id
     WHERE w.user_id = ?
     ORDER BY w.placed_at DESC",
    [$userId]
);

// Format numeric types
foreach ($wagers as &$w) {
    $w['id'] = (int)$w['id'];
    $w['bet_id'] = (int)$w['bet_id'];
    $w['outcome_id'] = (int)$w['outcome_id'];
    $w['stake'] = (float)$w['stake'];
    $w['locked_coefficient'] = (float)$w['locked_coefficient'];
    $w['potential_return'] = (float)$w['potential_return'];
}

Response::success($wagers);
