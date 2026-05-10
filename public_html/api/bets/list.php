<?php
require_once __DIR__ . '/../bootstrap.php';

// PRE-AUTH LOG: Did the request even arrive?
$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? 'MISSING';
file_put_contents(__DIR__ . '/../debug_log.txt', "[" . date('Y-m-d H:i:s') . "] list.php HIT. Status param: " . ($_GET['status'] ?? 'none') . ". Auth header: " . substr($authHeader, 0, 30) . "...\n", FILE_APPEND);

Auth::requireAuth();

$statusParam = $_GET['status'] ?? 'live';
$statuses = explode(',', $statusParam);
$placeholders = implode(',', array_fill(0, count($statuses), '?'));

$db = DB::getInstance();

$sql = "SELECT b.*, u.username as creator_name, b.creator_user_id as creator_id
     FROM bets b 
     JOIN users u ON b.creator_user_id = u.id 
     WHERE b.status IN ($placeholders)";

// Special logic for "To Settle" tab in Admin
// If statuses include 'live', we usually only want EXPIRED live bets for the settle tab
// But we want to maintain backward compatibility for normal feed.
// So let's check if 'locked' is also in the list (which indicates Admin "To Settle" tab)
if (in_array('locked', $statuses) && in_array('live', $statuses)) {
    $sql .= " AND (b.status != 'live' OR b.close_at < NOW())";
}

$sql .= " ORDER BY b.created_at DESC";

$bets = $db->fetchAll($sql, $statuses);

file_put_contents(__DIR__ . '/../debug_log.txt', "FOUND " . count($bets) . " bets for status $status\n", FILE_APPEND);

// Format numeric IDs
foreach ($bets as &$bet) {
    $bet['id'] = (int)$bet['id'];
    $bet['creator_user_id'] = (int)$bet['creator_user_id'];
    
    // Fetch outcomes
    $bet['outcomes'] = $db->fetchAll(
        "SELECT id, label, initial_coefficient as coefficient FROM bet_outcomes WHERE bet_id = ? ORDER BY sort_order ASC",
        [$bet['id']]
    );
    
    foreach ($bet['outcomes'] as &$outcome) {
        $outcome['id'] = (int)$outcome['id'];
        $outcome['coefficient'] = (float)$outcome['coefficient'];
    }
}

Response::success($bets);
