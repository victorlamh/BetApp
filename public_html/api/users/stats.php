<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();
$userId = Auth::userId();
$db = DB::getInstance();

// Get the last 30 ledger entries to draw the graph (excluding pending wagers)
$history = $db->fetchAll(
    "SELECT created_at, balance_after as value
     FROM wallet_ledger
     WHERE user_id = ? AND entry_type != 'wager_reserve'
     ORDER BY created_at ASC
     LIMIT 100",
    [$userId]
);

// Format for the app
$points = [];
foreach ($history as $row) {
    $points[] = [
        'date' => $row['created_at'],
        'value' => (float)$row['value']
    ];
}

Response::success($points);
