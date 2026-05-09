<?php
require_once __DIR__ . '/../bootstrap.php';

Auth::requireAuth();

$status = $_GET['status'] ?? 'live';
$db = DB::getInstance();

// Simple listing for admin/moderation
$bets = $db->fetchAll(
    "SELECT b.*, u.username as creator_name 
     FROM bets b 
     JOIN users u ON b.creator_user_id = u.id 
     WHERE b.status = ?
     ORDER BY b.created_at DESC",
    [$status]
);

// Format numeric IDs
foreach ($bets as &$bet) {
    $bet['id'] = (int)$bet['id'];
    $bet['creator_user_id'] = (int)$bet['creator_user_id'];
    
    // Fetch outcomes
    $bet['outcomes'] = $db->fetchAll(
        "SELECT id, label, coefficient FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order ASC",
        [$bet['id']]
    );
    
    foreach ($bet['outcomes'] as &$outcome) {
        $outcome['id'] = (int)$outcome['id'];
        $outcome['coefficient'] = (float)$outcome['coefficient'];
    }
}

Response::success($bets);
