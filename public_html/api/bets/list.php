<?php
require_once __DIR__ . '/../bootstrap.php';

// PRE-AUTH LOG: Did the request even arrive?
$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? 'MISSING';
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] list.php HIT. Status param: " . ($_GET['status'] ?? 'none') . ". Auth header: " . substr($authHeader, 0, 30) . "...\n", FILE_APPEND);

Auth::requireAuth();

$status = $_GET['status'] ?? 'live';
$db = DB::getInstance();

$totalInDb = $db->fetchOne("SELECT COUNT(*) as count FROM bets");
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] Listing bets for status: $status. Total bets in DB: " . $totalInDb['count'] . "\n", FILE_APPEND);

// Simple listing for admin/moderation
$bets = $db->fetchAll(
    "SELECT b.*, u.username as creator_name, b.creator_user_id as creator_id
     FROM bets b 
     JOIN users u ON b.creator_user_id = u.id 
     WHERE b.status = ?
     ORDER BY b.created_at DESC",
    [$status]
);

file_put_contents(__DIR__ . '/../debug_log.txt', "FOUND " . count($bets) . " bets for status $status\n", FILE_APPEND);

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
